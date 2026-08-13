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
                .onTapGesture {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .task {
                    UNUserNotificationCenter.current().delegate = PayaNotificationDelegate.shared
                    PayaNotificationDelegate.registerActionCategories()
                    // Re-schedule training reminders on every launch so they persist
                    // across app updates and settings changes.
                    if appState.profile.reminderEnabled {
                        await NotificationManager.shared.scheduleTrainingReminders(
                            at: appState.profile.reminderTime,
                            profile: appState.profile,
                            context: ModelContext(SharedModelContainer.shared)
                        )
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
