import SwiftUI
import SwiftData

// MARK: - Cloud Sync Settings Row
// Inline settings row: sign in/up → sync button → status.

struct CloudSyncSettingsRow: View {

    @Environment(\.modelContext) private var modelContext
    private var client = SupabaseClient.shared
    @State private var showAuthSheet = false

    var body: some View {
        if client.isSignedIn {
            signedInView
        } else {
            signedOutView
        }
    }

    // MARK: - Signed Out

    private var signedOutView: some View {
        Button {
            showAuthSheet = true
        } label: {
            HStack {
                SettingsIcon(icon: "person.badge.key.fill", color: Pulse.ai)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign In to Sync")
                        .foregroundColor(.primary)
                    Text("Back up your data to the cloud")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showAuthSheet) {
            CloudAuthView()
        }
    }

    // MARK: - Signed In

    private var signedInView: some View {
        Group {
            // Account row
            HStack {
                SettingsIcon(icon: "person.crop.circle.badge.checkmark", color: Pulse.positive)
                VStack(alignment: .leading, spacing: 2) {
                    Text(client.userEmail ?? "Signed In")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    if let last = client.lastSyncDate {
                        Text("Last sync: \(last, style: .relative) ago")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Not synced yet")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            // Sync button
            Button {
                Task { await performSync() }
            } label: {
                HStack {
                    SettingsIcon(
                        icon: client.isSyncing ? "arrow.triangle.2.circlepath" : "icloud.and.arrow.up.fill",
                        color: Color(hex: "3B82F6")
                    )
                    if client.isSyncing {
                        Text("Syncing...")
                            .foregroundColor(.primary)
                        Spacer()
                        ProgressView()
                            .tint(Pulse.ai)
                    } else {
                        Text("Sync Now")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .disabled(client.isSyncing)

            // Error display
            if let error = client.syncError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(Pulse.warning)
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(Pulse.warning)
                        .lineLimit(3)
                }
            }

            // Sign out
            Button(role: .destructive) {
                client.signOut()
            } label: {
                HStack {
                    SettingsIcon(icon: "rectangle.portrait.and.arrow.right", color: .red)
                    Text("Sign Out")
                        .foregroundColor(.red)
                }
            }
        }
    }

    private func performSync() async {
        do {
            try await SyncManager.shared.syncAll(context: modelContext)
        } catch {
            // Error is already set on client.syncError
        }
    }
}

// MARK: - Auth Sheet

struct CloudAuthView: View {

    @Environment(\.dismiss) private var dismiss
    private var client = SupabaseClient.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCheckEmail = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if showCheckEmail {
                    checkEmailView
                } else {
                    formView
                }
            }
            .navigationTitle(showCheckEmail ? "Check Your Email" : (isSignUp ? "Sign Up" : "Sign In"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(showCheckEmail ? "Done" : "Cancel") { dismiss() }
                }
            }
            .onChange(of: client.isSignedIn) { _, signedIn in
                // Auto-dismiss when the deep link callback completes sign-in
                if signedIn { dismiss() }
            }
        }
    }

    // MARK: - Check Email View

    private var checkEmailView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Pulse.positive.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "envelope.badge.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Pulse.positive)
                }

                Text("Confirmation Sent")
                    .font(.title2.weight(.bold))

                Text("We sent a confirmation link to **\(email)**. Tap it to finish signing up, then come back here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 40)

            VStack(spacing: 12) {
                Text("Didn't get it?")
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
                                .tint(Pulse.ai)
                        }
                        Text("Resend Email")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(Pulse.ai)
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
                .padding(.horizontal, 24)
            }

            // Manual sign-in fallback: if they confirmed but the deep
            // link didn't fire (e.g. opened the email on a different
            // device), let them sign in directly.
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
                        .foregroundColor(Pulse.ai)
                }
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Form View

    private var formView: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Pulse.ai.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Pulse.ai)
                }

                Text(isSignUp ? "Create Account" : "Sign In")
                    .font(.title2.weight(.bold))

                Text("Your data stays on-device and syncs encrypted to the cloud as a backup.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 20)

            // Form
            VStack(spacing: 14) {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(14)
                    .background(Pulse.surfaceElevatedFallback)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                SecureField("Password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .padding(14)
                    .background(Pulse.surfaceElevatedFallback)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                if isSignUp {
                    Text("Minimum 6 characters")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)

            // Error
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Pulse.warning)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(Pulse.warning)
                }
                .padding(.horizontal, 24)
            }

            // Submit
            Button {
                Task { await submit() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isSignUp ? "Create Account" : "Sign In")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(canSubmit ? Pulse.ai : Pulse.ai.opacity(0.3))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canSubmit || isLoading)
            .padding(.horizontal, 24)

            // Toggle
            Button {
                withAnimation { isSignUp.toggle() }
                errorMessage = nil
            } label: {
                Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                    .font(.subheadline)
                    .foregroundColor(Pulse.ai)
            }
        }
    }

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
                if immediateSignIn {
                    dismiss()
                } else {
                    withAnimation { showCheckEmail = true }
                }
            } else {
                try await client.signIn(email: email, password: password)
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
