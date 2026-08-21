import SwiftUI

// MARK: - Auth Gate View
//
// Full-screen sign-in / sign-up screen shown before the user can access
// the app. This is the first thing a new user sees after install.

struct AuthGateView: View {

    private var client = SupabaseClient.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCheckEmail = false

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            if showCheckEmail {
                checkEmailView
            } else {
                formView
            }
        }
        .preferredColorScheme(.dark)
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
}
