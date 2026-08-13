import Foundation
import UserNotifications
import SwiftData

@MainActor
class NotificationManager {

    static let shared = NotificationManager()

    private nonisolated static let trainingReminderPrefix = "training_reminder_"
    private static let preFlareAlertPrefix = "preflare_alert_"

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Preferences gating

    func isCategoryEnabled(_ category: NotificationCategory, profile: UserProfile) -> Bool {
        profile.notificationCategoryEnabled[category.rawValue] ?? false
    }

    /// Whether the given clock time falls inside the profile's quiet hours window (wraps past midnight).
    func isQuietHours(hour: Int, minute: Int, profile: UserProfile) -> Bool {
        guard profile.notificationsQuietHoursEnabled else { return false }
        let calendar = Calendar.current
        let startComps = calendar.dateComponents([.hour, .minute], from: profile.quietHoursStart)
        let endComps = calendar.dateComponents([.hour, .minute], from: profile.quietHoursEnd)
        guard let startHour = startComps.hour, let startMinute = startComps.minute,
              let endHour = endComps.hour, let endMinute = endComps.minute else { return false }

        let target = hour * 60 + minute
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        guard start != end else { return false }

        if start < end {
            return target >= start && target < end
        } else {
            return target >= start || target < end
        }
    }

    func isQuietHoursNow(profile: UserProfile) -> Bool {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: .now)
        return isQuietHours(hour: comps.hour ?? 0, minute: comps.minute ?? 0, profile: profile)
    }

    // MARK: - In-app notification center

    func recordInInbox(
        category: NotificationCategory,
        title: String,
        body: String,
        destination: NotificationDestination?,
        deduplicationKey: String,
        context: ModelContext
    ) {
        guard let profileId = ActiveProfile.id else { return }
        let record = NotificationRecord(
            category: category,
            title: title,
            message: body,
            profileId: profileId,
            destination: destination,
            deduplicationKey: deduplicationKey
        )
        _ = try? NotificationCenterStore.createIfNeeded(record, context: context)
    }

    // MARK: - Training reminders

    /// Schedules one recurring reminder per day actually configured in the
    /// user's installed program (TrainingDayStore), on that day's real
    /// weekday, with that day's real name/focus — replacing a previous
    /// version that hardcoded "Tue/Thu/Sat, Push·Front Delt / Pull·Rear
    /// Delt / Volume·V-Taper" regardless of what program was installed, so
    /// anyone on a generated program (different day count, different split,
    /// different weekdays) got a notification describing someone else's
    /// training day.
    func scheduleTrainingReminders(at time: Date, profile: UserProfile, context: ModelContext) async {
        cancelAllTrainingReminders()

        guard isCategoryEnabled(.training, profile: profile) else { return }

        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute], from: time)
        guard let hour = comps.hour, let minute = comps.minute else { return }

        guard !isQuietHours(hour: hour, minute: minute, profile: profile) else { return }

        for day in TrainingDayStore.allSnapshots(context: context) where (1...7).contains(day.weekday) {
            let content = UNMutableNotificationContent()
            content.title = "\(day.name) · \(day.focus)"
            content.body = "Today's the day — \(day.focus.lowercased()) is on the plan."
            content.sound = .default
            content.threadIdentifier = "training"
            content.userInfo = ["destination": NotificationDestination.train.rawValue]

            var trigger = DateComponents()
            trigger.weekday = day.weekday
            trigger.hour = hour
            trigger.minute = minute

            let request = UNNotificationRequest(
                identifier: "\(Self.trainingReminderPrefix)\(day.code)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    func cancelAllTrainingReminders() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(Self.trainingReminderPrefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ids
            )
        }
    }

    // MARK: - Pre-flare alerts

    /// Schedules a same-day pre-flare notification if risk is elevated or high.
    /// De-duplicates by date so at most one alert fires per day.
    func schedulePreFlareAlert(
        riskLevel: FlareRiskLevel,
        recommendation: String,
        context: ModelContext,
        profile: UserProfile,
        atHour hour: Int = 9
    ) async {
        cancelPreFlareAlertForToday()

        guard riskLevel == .elevated || riskLevel == .high else { return }

        let id = "\(Self.preFlareAlertPrefix)\(Self.todayStamp())"

        let content = UNMutableNotificationContent()
        content.title = riskLevel == .high
            ? "⚠️ Flare risk: High"
            : "Flare risk: Elevated"
        content.body = recommendation
        content.sound = .default
        content.threadIdentifier = "preflare"
        content.userInfo = ["destination": NotificationDestination.health.rawValue]

        recordInInbox(
            category: .flareRisk,
            title: content.title,
            body: recommendation,
            destination: .health,
            deduplicationKey: "preflare_\(Self.todayStamp())",
            context: context
        )

        guard isCategoryEnabled(.flareRisk, profile: profile) else { return }

        let calendar = Calendar.current
        var target = calendar.dateComponents([.year, .month, .day], from: Date())
        target.hour = hour
        target.minute = 0

        if let targetDate = calendar.date(from: target), targetDate > Date() {
            guard !isQuietHours(hour: hour, minute: 0, profile: profile) else { return }
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: targetDate
                ),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: id, content: content, trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
        } else {
            guard !isQuietHoursNow(profile: profile) else { return }
            // Past 9 AM — deliver in 60 seconds
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: 60, repeats: false
            )
            let request = UNNotificationRequest(
                identifier: id, content: content, trigger: trigger
            )
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    func cancelPreFlareAlertForToday() {
        let id = "\(Self.preFlareAlertPrefix)\(Self.todayStamp())"
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [id]
        )
    }

    // MARK: - Recovery prompt
    // Unlike the pre-flare alert (scheduled ahead for a fixed morning hour),
    // the recovery score is only known once ReadinessEngine.compute() has
    // actually run on this dashboard load — so this fires close to
    // immediately rather than being scheduled in advance, deduped per day
    // via recordInInbox so a second dashboard load the same day doesn't
    // resend it.
    private static let recoveryPromptPrefix = "recovery_prompt_"

    func scheduleRecoveryPrompt(
        score: Int,
        bandLabel: String,
        context: ModelContext,
        profile: UserProfile
    ) {
        let dedupKey = "\(Self.recoveryPromptPrefix)\(Self.todayStamp())"
        let title = "Recovery: \(bandLabel)"
        let body = "Today's score is \(score)."

        recordInInbox(
            category: .recovery,
            title: title,
            body: body,
            destination: .home,
            deduplicationKey: dedupKey,
            context: context
        )
    }

    private static func todayStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }

    // MARK: - Post-workout nutrition

    /// Fires ~90 minutes after a completed session. Not the strict 30-minute
    /// "anabolic window" popular fitness culture overstates — the actual
    /// evidence (Schoenfeld BJ, Aragon AA. "How much protein can the body
    /// use in a single meal for muscle-building?" J Int Soc Sports Nutr.
    /// 2018; Aragon AA, Schoenfeld BJ. "Nutrient timing revisited." J Int
    /// Soc Sports Nutr. 2013) puts the practically meaningful window at
    /// several hours around training, not a race against a half-hour clock
    /// — 90 minutes lands inside that window while still reading as
    /// "shortly after," not an arbitrary daily ping.
    func schedulePostWorkoutNutritionReminder(context: ModelContext, profile: UserProfile) {
        guard isCategoryEnabled(.postWorkoutNutrition, profile: profile) else { return }

        let fireDate = Date().addingTimeInterval(90 * 60)
        guard !isQuietHours(hour: Calendar.current.component(.hour, from: fireDate), minute: Calendar.current.component(.minute, from: fireDate), profile: profile) else { return }

        let title = "Refuel 🍽️"
        let body = "Protein sometime in the next couple hours supports recovery from today's session — the meaningful window is hours wide, not a 30-minute sprint."
        let id = "postworkout_nutrition_\(UUID().uuidString)"

        recordInInbox(
            category: .postWorkoutNutrition,
            title: title,
            body: body,
            destination: .nutrition,
            deduplicationKey: id,
            context: context
        )

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "postworkout"
        content.userInfo = ["destination": NotificationDestination.nutrition.rawValue]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 90 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}//
//  NotificationManager.swift
//  Paya
//
//  Created by Emin Huseynzade on 05.07.26.
//
