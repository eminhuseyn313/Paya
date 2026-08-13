import Foundation
import SwiftData
import UserNotifications

// MARK: - Weekly Digest Engine
//
// The Weekly Insight card already synthesizes training + sleep/pain into
// one AI narrative, but only when the user manually taps "Get insight" —
// most people won't remember to. This is the same synthesis delivered
// proactively, once a week (Sunday evening), extended to also cover
// nutrition adherence (protein/calorie target hit-rate), which the manual
// card never included despite nutrition data being just as available.
// Uses requiresReasoning like TrainingCoachEngine/LifestylePlanEngine —
// synthesizing training+sleep+nutrition correctly into specific advice is
// exactly the multi-fact task Apple's on-device model handles worse than
// a frontier model.

enum WeeklyDigestEngine {

    private static func lastSentKey(_ pid: UUID?) -> String {
        "weekly_digest_last_sent_\(pid?.uuidString ?? "none")"
    }

    @MainActor
    static func evaluateAndDeliver(userProfile: UserProfile, context: ModelContext, apiKey: String) async {
        guard NotificationManager.shared.isCategoryEnabled(.weeklyDigest, profile: userProfile) else { return }

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: .now)   // 1 = Sunday
        let hour = calendar.component(.hour, from: .now)
        guard weekday == 1, hour >= 18 else { return }

        let pid = ActiveProfile.id
        let key = lastSentKey(pid)
        if let last = UserDefaults.standard.object(forKey: key) as? Date,
           (calendar.dateComponents([.day], from: last, to: .now).day ?? 99) < 6 {
            return
        }

        let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now

        let sDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid && $0.date >= weekAgo }
        )
        let weekSessions = (try? context.fetch(sDescriptor)) ?? []

        let hDescriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.profileId == pid && $0.date >= weekAgo }
        )
        let weekHealth = (try? context.fetch(hDescriptor)) ?? []

        let nDescriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == pid && $0.date >= weekAgo }
        )
        let weekNutrition = (try? context.fetch(nDescriptor)) ?? []

        guard !weekSessions.isEmpty || !weekHealth.isEmpty || !weekNutrition.isEmpty else { return }

        let flareDays = weekHealth.filter { $0.isFlareDay }.count
        let avgSleep = weekHealth.isEmpty ? nil : weekHealth.map { $0.sleepHours }.reduce(0, +) / Double(weekHealth.count)
        let proteinHitDays = weekNutrition.filter { $0.proteinTarget > 0 && $0.totalProtein >= $0.proteinTarget * 0.9 }.count

        let personProfile = ProfileStore.current(context: context)
        let sexWord = userProfile.sexRaw.lowercased() == "female" ? "woman" : "man"
        let plannedDays = personProfile?.preferredTrainingDaysPerWeek ?? 3

        let system = """
        You are a personal coach writing a short weekly review for a client — a \(userProfile.age)-year-old \(sexWord) \
        training for \(userProfile.goal.displayName.lowercased()), \(plannedDays)x/week planned. \
        React specifically to the numbers given — training consistency, sleep, and nutrition adherence together — \
        not generic encouragement. End with ONE specific focus for next week. Direct, warm tone. 4-5 sentences.
        """

        let userMessage = """
        This week:
        - \(weekSessions.filter { $0.isCompleted }.count) of \(plannedDays) planned sessions completed
        - \(flareDays) flare day(s)
        - Avg sleep: \(avgSleep.map { String(format: "%.1fh", $0) } ?? "not logged")
        - Hit ≥90% of protein target on \(proteinHitDays) of \(weekNutrition.count) logged days

        What's your take on this week, and what should I focus on next week?
        """

        guard let result = await AIService.shared.generate(
            system: system, userMessage: userMessage, apiKey: apiKey, requiresReasoning: true
        ) else { return }

        UserDefaults.standard.set(Date(), forKey: key)

        let dedupKey = "\(key)_\(calendar.component(.weekOfYear, from: .now))"
        NotificationManager.shared.recordInInbox(
            category: .weeklyDigest,
            title: "Your Week in Review",
            body: result,
            destination: .home,
            deduplicationKey: dedupKey,
            context: context
        )

        guard !NotificationManager.shared.isQuietHoursNow(profile: userProfile) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Your Week in Review 📋"
        content.body = result
        content.sound = .default
        content.threadIdentifier = "weekly_digest"
        content.userInfo = ["destination": NotificationDestination.home.rawValue]
        let request = UNNotificationRequest(
            identifier: dedupKey,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
