import Foundation
import HealthKit
import SwiftData
import UserNotifications

// MARK: - Step Milestone Observer
// Background counterpart to MilestoneEngine's step checks: an HKObserverQuery
// with background delivery so "10,000 steps!" arrives the moment you cross
// it, not the next time you happen to open the app. Shares the exact same
// once-per-day dedup key format as MilestoneEngine so the two never double-fire.

@MainActor
enum StepMilestoneObserver {

    private struct Threshold {
        let value: Int
        let id: String
        let title: String
        let body: String
    }

    private static let thresholds: [Threshold] = [
        Threshold(value: 15000, id: "steps_15k", title: "15,000 steps! 🏆", body: "Outstanding day of movement — that's elite territory."),
        Threshold(value: 10000, id: "steps_10k", title: "10,000 steps! 🎉", body: "You crushed the classic daily target. Great work."),
        Threshold(value: 5000, id: "steps_5k", title: "5,000 steps 👟", body: "Solid movement today — halfway to 10k.")
    ]

    private static let healthStore = HKHealthStore()
    private static var hasStarted = false

    static func start() {
        guard !hasStarted,
              HKHealthStore.isHealthDataAvailable(),
              let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return }
        hasStarted = true

        healthStore.enableBackgroundDelivery(for: stepsType, frequency: .immediate) { _, _ in }

        let observer = HKObserverQuery(sampleType: stepsType, predicate: nil) { _, completionHandler, _ in
            Task { @MainActor in
                await checkToday()
                completionHandler()
            }
        }
        healthStore.execute(observer)
    }

    private static func checkToday() async {
        guard let steps = await HealthMetricsProvider.shared.fetchStepsRobust(),
              let profileId = ActiveProfile.id else { return }

        // Highest newly-crossed threshold only — avoids stacking three
        // notifications if the app was backgrounded through all of them.
        guard let threshold = thresholds.first(where: { steps >= $0.value && !alreadySent($0.id) }) else { return }
        markSent(threshold.id)

        let context = ModelContext(SharedModelContainer.shared)
        let record = NotificationRecord(
            category: .milestone,
            title: threshold.title,
            message: threshold.body,
            profileId: profileId,
            destination: .progress,
            deduplicationKey: "milestone_\(threshold.id)_\(todayKey(threshold.id))"
        )
        _ = try? NotificationCenterStore.createIfNeeded(record, context: context)

        let profile = loadProfile()
        guard profile.map({ NotificationManager.shared.isCategoryEnabled(.milestone, profile: $0) }) ?? true else { return }
        if let profile {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: .now)
            if NotificationManager.shared.isQuietHours(hour: comps.hour ?? 0, minute: comps.minute ?? 0, profile: profile) {
                return
            }
        }

        let content = UNMutableNotificationContent()
        content.title = threshold.title
        content.body = threshold.body
        content.sound = .default
        content.userInfo = ["destination": NotificationDestination.progress.rawValue]
        let request = UNNotificationRequest(identifier: "bg_\(threshold.id)_\(todayKey(threshold.id))", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Shared dedup format (matches MilestoneEngine exactly)

    private static func todayKey(_ id: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: Date())
        let pid = ActiveProfile.id?.uuidString ?? "none"
        return "milestone_\(pid)_\(id)_\(day)"
    }

    private static func alreadySent(_ id: String) -> Bool {
        UserDefaults.standard.bool(forKey: todayKey(id))
    }

    private static func markSent(_ id: String) {
        UserDefaults.standard.set(true, forKey: todayKey(id))
    }

    private static func loadProfile() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: "userProfile") else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }
}
