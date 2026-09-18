import Foundation

// MARK: - Mock Apple Auth Service
// Simulates Sign In with Apple while provisioning profile is not configured.
// Replace with real SignInWithAppleButton for App Store builds.

@MainActor
enum MockAppleAuthService {

    struct MockCredential {
        let userIdentifier: String
        let email: String
        let fullName: String
        let idToken: String
    }

    static func signIn() async -> MockCredential {
        try? await Task.sleep(for: .milliseconds(Int.random(in: 800...1200)))

        return MockCredential(
            userIdentifier: "001234.mock-apple-user.5678",
            email: "mock-user@privaterelay.appleid.com",
            fullName: "Mock User",
            idToken: "mock-apple-id-token-\(UUID().uuidString)"
        )
    }

    static func applyToClient() async {
        let credential = await signIn()
        let client = SupabaseClient.shared

        client.userId = UUID()
        client.userEmail = credential.email
        client.isSignedIn = true
        client.authState = .signedIn

        PurchaseManager.shared.checkDeveloperAccess(email: credential.email)
    }
}
