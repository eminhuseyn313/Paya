import Foundation
#if canImport(FamilyControls)
import FamilyControls
import ManagedSettings
#endif
import Combine

// MARK: - Focus Mode Manager
//
// Blocks user-selected apps (Instagram, etc.) for the duration of an active
// training session — built on Apple's Screen Time APIs (FamilyControls +
// ManagedSettings), the only real mechanism a third-party app has for this;
// iOS gives no other way to prevent another app from launching.
//
// Wrapped in #if canImport(FamilyControls) so the app compiles and signs
// cleanly on teams without the com.apple.developer.family-controls
// entitlement. The stub fallback provides the same interface (no-ops)
// so call sites don't need any conditional compilation.
//
// FamilyActivitySelection never exposes which specific apps were chosen —
// Apple deliberately keeps that opaque to the app for privacy, using
// anonymous tokens instead. Paya can turn the shield on/off but can never
// see or report which apps are in it.
//
// Real caveat, not a code limitation: com.apple.developer.family-controls
// requires Apple's explicit approval (a capability request submitted at
// developer.apple.com), separate from and in addition to a normal paid
// developer account — this is gated even for personal/development use,
// not just App Store distribution, because of how easily this class of
// API could be misused for surveillance. Until that's approved for this
// account, requestAuthorization() will fail with an authorization error;
// the rest of the app works fine either way since every call site here
// degrades to a no-op when authorization isn't granted.

#if canImport(FamilyControls)

@MainActor
@Observable
final class FocusModeManager {

    static let shared = FocusModeManager()

    private let store = ManagedSettingsStore()
    private let selectionKey = "focus_mode_selection"

    var authorizationStatus: AuthorizationStatus = .notDetermined
    var lastAuthorizationError: String? = nil
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "focus_mode_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "focus_mode_enabled") }
    }

    var selection: FamilyActivitySelection {
        get {
            guard let data = UserDefaults.standard.data(forKey: selectionKey),
                  let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
            else { return FamilyActivitySelection() }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: selectionKey)
            }
        }
    }

    private init() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func requestAuthorization() async {
        lastAuthorizationError = nil
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        } catch {
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            lastAuthorizationError = error.localizedDescription
        }
    }

    /// Called when a training session starts — no-ops silently if the
    /// feature is off, unauthorized, or nothing's selected, so call sites
    /// in TrainViewModel don't need to check any of that themselves.
    func enableShieldForSession() {
        guard isEnabled, authorizationStatus == .approved else { return }
        let current = selection
        guard !current.applicationTokens.isEmpty || !current.categoryTokens.isEmpty else { return }
        store.shield.applications = current.applicationTokens.isEmpty ? nil : current.applicationTokens
        store.shield.applicationCategories = current.categoryTokens.isEmpty
            ? nil
            : .specific(current.categoryTokens)
    }

    func disableShield() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
    }
}

#else

// MARK: - Stub when FamilyControls is unavailable

@MainActor
@Observable
final class FocusModeManager {

    static let shared = FocusModeManager()

    var lastAuthorizationError: String? = "FamilyControls not available on this device or build."
    var isEnabled: Bool {
        get { false }
        set { }
    }

    private init() {}

    func requestAuthorization() async {
        lastAuthorizationError = "FamilyControls requires a paid developer account with the family-controls entitlement."
    }

    func enableShieldForSession() {}
    func disableShield() {}
}

#endif
