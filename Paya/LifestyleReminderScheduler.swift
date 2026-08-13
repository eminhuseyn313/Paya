import Foundation
import SwiftData
import UserNotifications

// MARK: - Lifestyle Reminder Scheduler
// Turns the four "coming soon" notification categories into real, data-aware
// reminders. Each one is conditional on today's actual logged state — no
// dumb clock alarms — and self-cancels the moment the user completes the
// thing it was going to nag about.
//
//   supplement — 20:00, only if today's stack isn't fully checked off
//   hydration  — 15:00, only if water is under 40% of the daily target
//   meal       — 18:30, only if protein is under 60% of target
//   weighIn    — 09:00, only if there's been no weigh-in for 7+ days
//
// Re-evaluated on every dashboard load, so completing a task cancels its
// pending reminder (and removes the matching inbox record).

@MainActor
enum LifestyleReminderScheduler {

    private struct Reminder {
        let category: NotificationCategory
        let idPrefix: String
        let hour: Int
        let minute: Int
        let title: String
        let body: String
        let destination: NotificationDestination
    }

    static func evaluate(profile: UserProfile, context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Supplement — outstanding items in today's stack
        let supplements = UserSupplementStore.active(context: context)
        let taken = Set(todaysHealthLog(context: context)?.supplementsTaken ?? [])
        let supplementsOutstanding = !supplements.isEmpty && supplements.contains { !taken.contains($0.name) }
        apply(
            Reminder(
                category: .supplement, idPrefix: "lifestyle_supp", hour: 20, minute: 0,
                title: "Supplement check 💊",
                body: "Some of today's stack is still unchecked — knock it out before the day ends.",
                destination: .nutrition
            ),
            condition: supplementsOutstanding, profile: profile, context: context
        )

        // Hydration — behind pace by mid-afternoon
        let waterMl = todaysHealthLog(context: context)?.waterMl ?? 0
        let waterBehind = Double(waterMl) < Double(WaterStore.dailyTargetMl) * 0.4
        apply(
            Reminder(
                category: .hydration, idPrefix: "lifestyle_water",
                hour: LifestyleReminderSettings.hydrationCheckHour, minute: 0,
                title: "Hydration check 💧",
                body: "You're under 40% of your water target — a glass now keeps the afternoon on track.",
                destination: .health
            ),
            condition: waterBehind, profile: profile, context: context
        )

        // Meal — protein badly behind by evening
        let nutritionPid = ActiveProfile.id
        let nutritionDescriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == nutritionPid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let todayLog = ((try? context.fetch(nutritionDescriptor)) ?? [])
            .first { calendar.isDate($0.date, inSameDayAs: today) }
        let proteinBehind: Bool
        if let todayLog, todayLog.proteinTarget > 0 {
            proteinBehind = todayLog.totalProtein < todayLog.proteinTarget * 0.6
        } else {
            proteinBehind = true   // nothing logged at all counts as behind
        }
        apply(
            Reminder(
                category: .meal, idPrefix: "lifestyle_meal", hour: 18, minute: 30,
                title: "Protein check 🍽️",
                body: "You're under 60% of your protein target — dinner is the catch-up window.",
                destination: .nutrition
            ),
            condition: proteinBehind, profile: profile, context: context
        )

        // Weigh-in — weekly cadence
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weightPid = ActiveProfile.id
        let weightDescriptor = FetchDescriptor<BodyWeightLog>(
            predicate: #Predicate<BodyWeightLog> { $0.profileId == weightPid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let lastWeighIn = ((try? context.fetch(weightDescriptor)) ?? []).first?.date
        let weighInDue = (lastWeighIn ?? .distantPast) < weekAgo
        apply(
            Reminder(
                category: .weighIn, idPrefix: "lifestyle_weigh", hour: 9, minute: 0,
                title: "Weekly weigh-in ⚖️",
                body: "It's been a week since your last weigh-in — morning is the most consistent time.",
                destination: .home
            ),
            condition: weighInDue, profile: profile, context: context
        )

        // Eye care — periodic reminders through the waking day. No screen-time
        // signal exists to make this conditional (Screen Time/DeviceActivity
        // needs the com.apple.developer.family-controls entitlement, which
        // is hard-blocked for this app's current free/personal developer
        // team — see the comment in Paya.entitlements), so this is a fixed
        // schedule rather than a behavior-triggered one. Alternates two
        // distinct, real pieces of eye-health guidance: lubricating drops on
        // a roughly 4-hour cadence (typical OTC dosing spacing for dry-eye
        // relief) and the 20-20-20 rule (American Optometric Association:
        // every ~20 minutes of screen work, look at something 20 feet away
        // for 20 seconds, to reduce digital eye strain).
        let eyeCareStart = LifestyleReminderSettings.eyeCareStartHour
        let eyeCareEnd = max(eyeCareStart + 1, LifestyleReminderSettings.eyeCareEndHour)
        let eyeCareSpan = eyeCareEnd - eyeCareStart
        let eyeCareSlotCount = 4
        let eyeCareSlots: [(hour: Int, minute: Int, isDropReminder: Bool)] = (0..<eyeCareSlotCount).map { i in
            let hour = eyeCareStart + (eyeCareSpan * i) / (eyeCareSlotCount - 1)
            return (hour, 0, i % 2 == 0)
        }
        for (index, slot) in eyeCareSlots.enumerated() {
            let title = slot.isDropReminder ? "Eye drops 👁️" : "20-20-20 break 👁️"
            let body = slot.isDropReminder
                ? "A good time for lubricating eye drops if you use them — especially on a long screen day."
                : "Look at something 20 feet away for 20 seconds — the American Optometric Association's rule of thumb for reducing digital eye strain."
            apply(
                Reminder(
                    category: .eyeCare, idPrefix: "lifestyle_eyecare_\(index)", hour: slot.hour, minute: slot.minute,
                    title: title, body: body, destination: .health
                ),
                condition: true, profile: profile, context: context
            )
        }

        // Morning light — a single fixed-time nudge, same honesty caveat as
        // eye care: there's no live "minutes of daylight so far today"
        // signal cheap enough to check at schedule-evaluation time (Personal
        // Health Management's daylight tracking looks at completed past
        // days), so this is a schedule, not a sensor-triggered prompt.
        // Grounded in circadian photoentrainment research (Czeisler et al.
        // on light's role in resetting the human circadian pacemaker):
        // bright light exposure soon after waking is the strongest daily
        // anchor for the sleep/wake rhythm, which is also why Personal
        // Health's retrospective insights flag sunny hours spent indoors.
        apply(
            Reminder(
                category: .circadian, idPrefix: "lifestyle_circadian",
                hour: LifestyleReminderSettings.morningLightHour,
                minute: LifestyleReminderSettings.morningLightMinute,
                title: "Morning light ☀️",
                body: "A few minutes outside now does more for tonight's sleep than the same minutes later in the day — bright morning light is the strongest daily anchor for your circadian rhythm.",
                destination: .health
            ),
            condition: true, profile: profile, context: context
        )

        // Calorie deficit end-of-day summary
        CalorieDeficitEngine.scheduleEndOfDayNotification(context: context, profile: profile)

        // Medication — one reminder per due-and-not-yet-taken medication,
        // since each can be on its own schedule (unlike the fixed-condition
        // reminders above).
        for medication in MedicationStore.active(context: context) {
            guard medication.frequency != .asNeeded else { continue }
            let due = MedicationStore.isDueToday(medication, context: context)
                && !MedicationStore.takenToday(medication, context: context)
            apply(
                Reminder(
                    category: .medication, idPrefix: "lifestyle_med_\(medication.id.uuidString)", hour: 9, minute: 30,
                    title: "\(medication.name) is due 💊",
                    body: "\(medication.dose) · \(medication.frequency.displayName) — mark it taken once you've had it.",
                    destination: .health
                ),
                condition: due, profile: profile, context: context
            )
        }
    }

    // MARK: - Core

    private static func apply(
        _ reminder: Reminder,
        condition: Bool,
        profile: UserProfile,
        context: ModelContext
    ) {
        let id = "\(reminder.idPrefix)_\(todayStamp())"
        let dedupKey = id

        let enabled = profile.notificationCategoryEnabled[reminder.category.rawValue] ?? false
        guard enabled, condition else {
            // Condition resolved (or category off): cancel pending + remove stale inbox record.
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
            deleteInboxRecord(dedupKey: dedupKey, context: context)
            return
        }

        // Only schedule while the slot is still ahead of us today.
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: Date())
        comps.hour = reminder.hour
        comps.minute = reminder.minute
        guard let fireDate = calendar.date(from: comps), fireDate > Date() else { return }
        guard !NotificationManager.shared.isQuietHours(hour: reminder.hour, minute: reminder.minute, profile: profile) else { return }

        NotificationManager.shared.recordInInbox(
            category: reminder.category,
            title: reminder.title,
            body: reminder.body,
            destination: reminder.destination,
            deduplicationKey: dedupKey,
            context: context
        )

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.threadIdentifier = "lifestyle"
        content.userInfo = ["destination": reminder.destination.rawValue]
        if reminder.category == .hydration {
            content.categoryIdentifier = PayaNotificationDelegate.hydrationCategoryId
        }

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers

    private static func todaysHealthLog(context: ModelContext) -> HealthLog? {
        let pid = ActiveProfile.id
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate { $0.profileId == pid && $0.date >= startOfDay },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.first
    }

    private static func deleteInboxRecord(dedupKey: String, context: ModelContext) {
        guard let pid = ActiveProfile.id else { return }
        let descriptor = FetchDescriptor<NotificationRecord>(
            predicate: #Predicate { $0.profileId == pid && $0.deduplicationKey == dedupKey }
        )
        for record in (try? context.fetch(descriptor)) ?? [] {
            // Only silently retract unread reminders — if the user already saw
            // it in the inbox, leave their history alone.
            if record.readAt == nil {
                context.delete(record)
            }
        }
        try? context.save()
    }

    private static func todayStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }
}
