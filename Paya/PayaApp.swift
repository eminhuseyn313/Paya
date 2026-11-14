import SwiftUI
import SwiftData
import UserNotifications

@main
struct PayaApp: App {

    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                // simultaneousGesture (not onTapGesture): a window-level tap
                // recognizer competed with UIKit-backed controls such as the
                // Sign in with Apple button and intermittently swallowed taps.
                .simultaneousGesture(
                    TapGesture().onEnded {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                )
                .onOpenURL { url in
                    // Supabase auth callback: paya://auth/callback#access_token=...
                    if url.scheme == "paya" && url.host == "auth" {
                        Task {
                            await SupabaseClient.shared.handleAuthCallback(url: url)
                        }
                    }
                }
                .task {
                    UNUserNotificationCenter.current().delegate = PayaNotificationDelegate.shared
                    PayaNotificationDelegate.registerActionCategories()
                    // Re-schedule training reminders on every launch so they persist
                    // across app updates and settings changes.
                    if appState.profile.reminderEnabled {
                        // Ask once (no-op after the first answer) so a user who
                        // never touched the Settings toggle still gets reminders.
                        _ = await NotificationManager.shared.requestAuthorization()
                        await NotificationManager.shared.scheduleTrainingReminders(
                            at: appState.profile.reminderTime,
                            profile: appState.profile,
                            context: ModelContext(SharedModelContainer.shared)
                        )
                        await NotificationManager.shared.scheduleWeeklyReview(profile: appState.profile)
                    }
                    StepMilestoneObserver.start()

                    // DEV ONLY — remove or gate behind #if DEBUG before App Store submission
                    #if DEBUG
                    SessionSeeder.seedAugust10Monday(context: ModelContext(SharedModelContainer.shared))
                    #endif

                    // Check momentum streak badges
                    MomentumEngine.grantBadges(context: ModelContext(SharedModelContainer.shared))

                    // StoreKit: load product, verify entitlements, listen for updates
                    await PurchaseManager.shared.configure()
                }
        }
        .modelContainer(SharedModelContainer.shared)
    }
}
