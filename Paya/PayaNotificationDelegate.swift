import Foundation
import SwiftData
import UserNotifications

// MARK: - Notification Tap Routing
//
// Every local notification this app schedules now stamps
// content.userInfo["destination"] with a NotificationDestination raw value
// (see NotificationManager, LifestyleReminderScheduler, MilestoneEngine,
// RestTimer, StepMilestoneObserver). Without a UNUserNotificationCenter
// delegate, none of that mattered — tapping ANY system notification just
// launched the app to whatever tab was already showing, with no routing at
// all. This delegate reads that tag on tap and reuses the exact same
// UserDefaults bridge PayaIntentNavigation already built for Siri Shortcuts
// (ContentView's applyPendingIntentNavigation reads the same key), so a
// notification tap now jumps to the right tab the same way "open today's
// workout" does.
//
// Also handles foreground presentation: without willPresent returning a
// non-empty option set, a notification that fires while the app is already
// open is delivered silently — no banner, no sound — which looks
// indistinguishable from the notification just not working.

final class PayaNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PayaNotificationDelegate()
    static let didNavigateNotification = Notification.Name("payaNotificationDidNavigate")

    static let hydrationCategoryId = "hydration_actions"
    static let addWater250Action = "add_water_250"
    static let addWater500Action = "add_water_500"
    static let addCoffeeAction = "add_coffee"
    static let addTeaAction = "add_tea"
    static let openDrinksAction = "open_drinks"

    static func registerActionCategories() {
        let add250 = UNNotificationAction(
            identifier: addWater250Action,
            title: "💧 250ml Water",
            options: []
        )
        let add500 = UNNotificationAction(
            identifier: addWater500Action,
            title: "💧 500ml Water",
            options: []
        )
        let addCoffee = UNNotificationAction(
            identifier: addCoffeeAction,
            title: "☕ Coffee",
            options: []
        )
        let openDrinks = UNNotificationAction(
            identifier: openDrinksAction,
            title: "More drinks...",
            options: [.foreground]
        )
        let hydrationCategory = UNNotificationCategory(
            identifier: hydrationCategoryId,
            actions: [add250, add500, addCoffee, openDrinks],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([hydrationCategory])
    }

    private static let destinationToTab: [NotificationDestination: Int] = [
        .home: 0, .train: 1, .nutrition: 2, .health: 3, .progress: 4,
        .settings: 0   // no dedicated tab — Settings is a sheet off Home
    ]

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Always show notifications even when app is foregrounded —
        // silencing threads made it look like notifications weren't working.
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case Self.addWater250Action:
            addWaterInBackground(ml: 250, drinkType: .water)
        case Self.addWater500Action:
            addWaterInBackground(ml: 500, drinkType: .water)
        case Self.addCoffeeAction:
            addWaterInBackground(ml: 250, drinkType: .coffee)
        case Self.openDrinksAction:
            UserDefaults.standard.set(2, forKey: PayaIntentNavigation.requestedTabKey)
        default:
            break
        }

        if let raw = response.notification.request.content.userInfo["destination"] as? String,
           let destination = NotificationDestination(rawValue: raw),
           let tab = Self.destinationToTab[destination] {
            UserDefaults.standard.set(tab, forKey: PayaIntentNavigation.requestedTabKey)
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.didNavigateNotification, object: nil)
        }
        completionHandler()
    }

    private func addWaterInBackground(ml: Int, drinkType: DrinkType) {
        Task { @MainActor in
            let context = ModelContext(SharedModelContainer.shared)
            WaterStore.addWater(ml, drinkType: drinkType, context: context)
        }
    }
}
