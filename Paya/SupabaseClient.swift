import Foundation

// MARK: - Supabase Client
// Lightweight Supabase REST client using URLSession.
// No external SDK dependency — talks directly to PostgREST + GoTrue.

@MainActor @Observable
final class SupabaseClient {

    static let shared = SupabaseClient()

    private let baseURL = "https://bpvvodmhgdrfjxvdjjqu.supabase.co"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwdnZvZG1oZ2RyZmp4dmRqanF1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY4NjM5NjEsImV4cCI6MjEwMjQzOTk2MX0.53vSIiui9hNLaUX34M_pOvYDH1L9cr8JFjE6qz7Y4Zk"

    var isSignedIn = false
    var userId: UUID?
    var userEmail: String?
    var isSyncing = false
    var lastSyncDate: Date?
    var syncError: String?
    /// Set after signUp when email confirmation is required.
    var pendingConfirmationEmail: String? = nil

    private var accessToken: String? {
        didSet { UserDefaults.standard.set(accessToken, forKey: "supabase_access_token") }
    }
    private var refreshToken: String? {
        didSet { UserDefaults.standard.set(refreshToken, forKey: "supabase_refresh_token") }
    }

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            // Try ISO8601 with fractional seconds first
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fmt.date(from: str) { return date }
            fmt.formatOptions = [.withInternetDateTime]
            if let date = fmt.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(str)")
        }
        return d
    }()

    private init() {
        accessToken = UserDefaults.standard.string(forKey: "supabase_access_token")
        refreshToken = UserDefaults.standard.string(forKey: "supabase_refresh_token")
        if let tokenData = accessToken, !tokenData.isEmpty {
            restoreSession()
        }
        lastSyncDate = UserDefaults.standard.object(forKey: "supabase_last_sync") as? Date
    }

    // MARK: - Auth

    struct AuthResponse: Codable {
        let accessToken: String
        let refreshToken: String
        let user: AuthUser
    }

    struct AuthUser: Codable {
        let id: UUID
        let email: String?
    }

    struct AuthError: Codable {
        let error: String?
        let errorDescription: String?
        let msg: String?

        var message: String { errorDescription ?? msg ?? error ?? "Unknown auth error" }
    }

    /// Sign up with email + password. When Supabase has email confirmation
    /// enabled (the default), the response contains a user object but NO
    /// access/refresh tokens — the user must click the email link first.
    /// Returns true if the user is immediately signed in (confirmation
    /// disabled), false if a confirmation email was sent.
    @discardableResult
    func signUp(email: String, password: String) async throws -> Bool {
        let url = URL(string: "\(baseURL)/auth/v1/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        // GoTrue REST API uses top-level "email_redirect_to" (not nested
        // inside "options" — that's the JS SDK wrapper format).
        // This URL must also be on the Supabase Auth → Redirect URLs allowlist.
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password,
            "email_redirect_to": "paya://auth/callback"
        ] as [String: Any])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncError.networkError }

        if http.statusCode >= 400 {
            let authErr = try? decoder.decode(AuthError.self, from: data)
            throw SyncError.auth(authErr?.message ?? "Sign up failed (\(http.statusCode))")
        }

        // When email confirmation is enabled, Supabase returns a user
        // object without tokens. Try to decode as AuthResponse first;
        // if that fails, the user needs to confirm their email.
        if let auth = try? decoder.decode(AuthResponse.self, from: data) {
            applySession(auth)
            return true  // immediately signed in
        }

        // Confirmation required — store the email so we can show it in
        // the "check your inbox" state.
        pendingConfirmationEmail = email
        return false  // confirmation email sent
    }

    func signIn(email: String, password: String) async throws {
        let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password
        ])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncError.networkError }

        if http.statusCode >= 400 {
            let authErr = try? decoder.decode(AuthError.self, from: data)
            throw SyncError.auth(authErr?.message ?? "Sign in failed (\(http.statusCode))")
        }

        let auth = try decoder.decode(AuthResponse.self, from: data)
        applySession(auth)
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
        isSignedIn = false
        userId = nil
        userEmail = nil
        pendingConfirmationEmail = nil
        UserDefaults.standard.removeObject(forKey: "supabase_access_token")
        UserDefaults.standard.removeObject(forKey: "supabase_refresh_token")
    }

    /// Handle the deep link callback from Supabase email confirmation.
    /// Supabase redirects to: paya://auth/callback#access_token=...&refresh_token=...
    /// The tokens are in the URL fragment (after #), not query parameters.
    func handleAuthCallback(url: URL) async {
        // Supabase puts tokens in the fragment: #access_token=...&refresh_token=...&...
        // URL.fragment gives us everything after #
        guard let fragment = url.fragment else {
            // No fragment — might be an error callback or a different format.
            // Try query params as fallback.
            if let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value {
                await exchangeCodeForSession(code: code)
            }
            return
        }

        // Parse fragment as query parameters
        let params = parseFragment(fragment)

        if let access = params["access_token"],
           let refresh = params["refresh_token"] {
            accessToken = access
            refreshToken = refresh
            pendingConfirmationEmail = nil

            // Decode user from JWT
            let parts = access.split(separator: ".")
            if parts.count == 3,
               let payload = base64Decode(String(parts[1])),
               let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] {
                if let sub = json["sub"] as? String, let uid = UUID(uuidString: sub) {
                    userId = uid
                }
                if let email = json["email"] as? String {
                    userEmail = email
                }
            }
            isSignedIn = true
        } else if let errorDesc = params["error_description"] {
            syncError = errorDesc.removingPercentEncoding ?? errorDesc
        }
    }

    /// Exchange an auth code (PKCE flow) for a session.
    private func exchangeCodeForSession(code: String) async {
        let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=authorization_code")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "auth_code": code
        ])

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode < 400,
              let auth = try? decoder.decode(AuthResponse.self, from: data) else {
            syncError = "Failed to verify email confirmation"
            return
        }
        applySession(auth)
        pendingConfirmationEmail = nil
    }

    private func parseFragment(_ fragment: String) -> [String: String] {
        var result: [String: String] = [:]
        let pairs = fragment.split(separator: "&")
        for pair in pairs {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            result[String(kv[0])] = String(kv[1])
        }
        return result
    }

    private func applySession(_ auth: AuthResponse) {
        accessToken = auth.accessToken
        refreshToken = auth.refreshToken
        userId = auth.user.id
        userEmail = auth.user.email
        isSignedIn = true
    }

    private func restoreSession() {
        guard let token = accessToken, !token.isEmpty else { return }
        // Decode JWT payload to check expiry and get user info
        let parts = token.split(separator: ".")
        guard parts.count == 3,
              let payload = base64Decode(String(parts[1])),
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
            signOut()
            return
        }

        if let exp = json["exp"] as? Double, Date(timeIntervalSince1970: exp) < .now {
            // Token expired — try refresh
            Task { await refreshAccessToken() }
            return
        }

        if let sub = json["sub"] as? String, let uid = UUID(uuidString: sub) {
            userId = uid
        }
        if let email = json["email"] as? String {
            userEmail = email
        }
        isSignedIn = true
    }

    private func refreshAccessToken() async {
        guard let refresh = refreshToken, !refresh.isEmpty else {
            signOut()
            return
        }

        let url = URL(string: "\(baseURL)/auth/v1/token?grant_type=refresh_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "refresh_token": refresh
        ])

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode < 400 else {
            signOut()
            return
        }

        if let auth = try? decoder.decode(AuthResponse.self, from: data) {
            applySession(auth)
        } else {
            signOut()
        }
    }

    private func base64Decode(_ str: String) -> Data? {
        var s = str
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        return Data(base64Encoded: s)
    }

    // MARK: - REST API

    func upsertRaw(table: String, jsonData: Data) async throws {
        let url = URL(string: "\(baseURL)/rest/v1/\(table)")!
        var request = authorizedRequest(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = jsonData

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncError.networkError }

        if http.statusCode == 401 {
            await refreshAccessToken()
            guard isSignedIn else { throw SyncError.auth("Session expired") }
            var retry = authorizedRequest(url: url, method: "POST")
            retry.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            retry.httpBody = jsonData
            let (_, r2) = try await session.data(for: retry)
            guard let h2 = r2 as? HTTPURLResponse, h2.statusCode < 400 else {
                throw SyncError.upload("Upsert \(table) failed after refresh")
            }
            return
        }

        if http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SyncError.upload("Upsert \(table) failed (\(http.statusCode)): \(body)")
        }
    }

    func upsert<T: Encodable>(table: String, rows: [T]) async throws {
        guard !rows.isEmpty else { return }
        let url = URL(string: "\(baseURL)/rest/v1/\(table)")!
        var request = authorizedRequest(url: url, method: "POST")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(rows)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncError.networkError }

        if http.statusCode == 401 {
            await refreshAccessToken()
            guard isSignedIn else { throw SyncError.auth("Session expired") }
            // Retry once
            var retry = authorizedRequest(url: url, method: "POST")
            retry.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
            retry.httpBody = try encoder.encode(rows)
            let (_, r2) = try await session.data(for: retry)
            guard let h2 = r2 as? HTTPURLResponse, h2.statusCode < 400 else {
                throw SyncError.upload("Upsert \(table) failed after refresh")
            }
            return
        }

        if http.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SyncError.upload("Upsert \(table) failed (\(http.statusCode)): \(body)")
        }
    }

    func fetch<T: Decodable>(table: String, type: T.Type, query: String = "") async throws -> [T] {
        let urlStr = "\(baseURL)/rest/v1/\(table)?\(query)&select=*"
        guard let url = URL(string: urlStr) else { throw SyncError.networkError }
        let request = authorizedRequest(url: url, method: "GET")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode < 400 else {
            throw SyncError.download("Fetch \(table) failed")
        }

        return try decoder.decode([T].self, from: data)
    }

    private func authorizedRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // MARK: - Sync State

    func markSynced() {
        let now = Date()
        lastSyncDate = now
        UserDefaults.standard.set(now, forKey: "supabase_last_sync")
    }

    // MARK: - Errors

    enum SyncError: LocalizedError {
        case auth(String)
        case networkError
        case upload(String)
        case download(String)

        var errorDescription: String? {
            switch self {
            case .auth(let msg): return msg
            case .networkError: return "Network error — check your connection"
            case .upload(let msg): return msg
            case .download(let msg): return msg
            }
        }
    }
}
