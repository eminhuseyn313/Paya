import SwiftUI
import AuthenticationServices
import CryptoKit

// MARK: - Auth Gate View
//
// Full-screen sign-in / sign-up screen shown before the user can access
// the app. This is the first thing a new user sees after install.
//
// Apple Review Guideline 4.8: Sign In with Apple is required whenever
// an app offers any form of account creation or third-party auth.

struct AuthGateView: View {

    private var client = SupabaseClient.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCheckEmail = false
    @State private var showResetSent = false
    @State private var currentNonce: String?

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            if showResetSent {
                resetSentView
            } else if showCheckEmail {
                checkEmailView
            } else {
                formView
            }
        }
        .onChange(of: client.isSignedIn) { _, signedIn in
            // Deep link callback completed — view will disappear
            // as ContentView re-evaluates its body.
        }
    }

    // MARK: - Form View

    private var formView: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer()
                    .frame(height: 60)

                // Logo + tagline
                VStack(spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(Pulse.hydration)

                    Text("Paya")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("Fitness, done right.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.secondary)
                }

                // MARK: Sign In with Apple (§ 4.8)
                SignInWithAppleButton(.continue) { request in
                    let nonce = randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.email, .fullName]
                    request.nonce = sha256(nonce)
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 32)

                // Divider
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                    Text("or")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                }
                .padding(.horizontal, 40)

                // Form fields
                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .foregroundColor(.white)

                    SecureField("Password", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .foregroundColor(.white)

                    if isSignUp {
                        Text("Minimum 6 characters")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 32)

                // Error
                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Pulse.warning)
                            .font(.caption)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Pulse.warning)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 32)
                }

                // Submit button
                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .font(.headline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(canSubmit ? Pulse.hydration : Pulse.hydration.opacity(0.3))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canSubmit || isLoading)
                .padding(.horizontal, 32)

                // Toggle sign in / sign up
                Button {
                    withAnimation { isSignUp.toggle() }
                    errorMessage = nil
                } label: {
                    Text(isSignUp
                         ? "Already have an account? **Sign In**"
                         : "Don't have an account? **Sign Up**")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Forgot password
                if !isSignUp {
                    Button {
                        Task { await sendPasswordReset() }
                    } label: {
                        Text("Forgot password?")
                            .font(.subheadline)
                            .foregroundColor(Pulse.hydration)
                    }
                    .disabled(email.isEmpty || isLoading)
                }

                // Guest mode — local-only, no cloud sync
                Button {
                    client.enterGuestMode()
                } label: {
                    Text("Continue without account")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.top, 4)

                Text("Your data stays on this device. You can create an account later.")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // Legal links
                HStack(spacing: 16) {
                    Link("Privacy Policy", destination: URL(string: "https://eminhuseyn313.github.io/Paya/privacy")!)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(.secondary.opacity(0.5))
                    Link("Terms of Service", destination: URL(string: "https://eminhuseyn313.github.io/Paya/terms")!)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Check Email View

    private var checkEmailView: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Pulse.positive.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 34))
                        .foregroundColor(Pulse.positive)
                }

                Text("Check Your Email")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)

                Text("We sent a confirmation link to\n**\(email)**\n\nTap the link to finish signing up,\nthen come back here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            // Resend
            VStack(spacing: 12) {
                Text("Didn't get it? Check your spam folder.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button {
                    Task {
                        isLoading = true
                        defer { isLoading = false }
                        do {
                            try await client.signUp(email: email, password: password)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isLoading {
                            ProgressView()
                                .tint(Pulse.hydration)
                        }
                        Text("Resend Email")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(Pulse.hydration)
                }
                .disabled(isLoading)
            }

            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Pulse.warning)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Pulse.warning)
                }
                .padding(.horizontal, 32)
            }

            // Sign in fallback
            VStack(spacing: 8) {
                Text("Already confirmed?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button {
                    showCheckEmail = false
                    isSignUp = false
                } label: {
                    Text("Sign in instead")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Pulse.hydration)
                }
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Password Reset Sent View

    private var resetSentView: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Pulse.hydration.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: "key.fill")
                        .font(.system(size: 34))
                        .foregroundColor(Pulse.hydration)
                }

                Text("Reset Link Sent")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)

                Text("We sent a password reset link to\n**\(email)**\n\nTap the link to set a new password,\nthen come back and sign in.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(spacing: 12) {
                Text("Didn't get it? Check your spam folder.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button {
                    Task { await sendPasswordReset() }
                } label: {
                    HStack(spacing: 6) {
                        if isLoading {
                            ProgressView()
                                .tint(Pulse.hydration)
                        }
                        Text("Resend Link")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(Pulse.hydration)
                }
                .disabled(isLoading)
            }

            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Pulse.warning)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Pulse.warning)
                }
                .padding(.horizontal, 32)
            }

            VStack(spacing: 8) {
                Text("Remember your password?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button {
                    showResetSent = false
                    errorMessage = nil
                } label: {
                    Text("Back to sign in")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Pulse.hydration)
                }
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Logic

    private var canSubmit: Bool {
        !email.isEmpty && password.count >= 6
    }

    private func submit() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if isSignUp {
                let immediateSignIn = try await client.signUp(email: email, password: password)
                if !immediateSignIn {
                    withAnimation { showCheckEmail = true }
                }
                // If immediateSignIn == true, client.isSignedIn flips and
                // ContentView will navigate away from this view automatically.
            } else {
                try await client.signIn(email: email, password: password)
                // client.isSignedIn flips → ContentView navigates away.
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendPasswordReset() async {
        guard !email.isEmpty else {
            errorMessage = "Enter your email address first"
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await client.resetPassword(email: email)
            withAnimation { showResetSent = true }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign In with Apple

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = appleIDCredential.identityToken,
                  let idToken = String(data: identityTokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Could not process Apple credentials"
                return
            }

            isLoading = true
            errorMessage = nil

            Task {
                do {
                    try await client.signInWithApple(
                        idToken: idToken,
                        nonce: nonce,
                        fullName: appleIDCredential.fullName
                    )
                } catch {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }

        case .failure(let error):
            // ASAuthorizationError.canceled means user dismissed the
            // sheet — don't show an error for that.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Generate a random nonce string for Apple Sign In security.
    /// The nonce binds the Apple identity token to this specific
    /// sign-in attempt, preventing replay attacks.
    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            _ = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            for random in randoms {
                guard remainingLength > 0 else { break }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    /// SHA256 hash of the nonce, sent to Apple in the sign-in request.
    /// Apple returns the original nonce inside the identity token's claims,
    /// allowing Supabase to verify the token wasn't replayed.
    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
