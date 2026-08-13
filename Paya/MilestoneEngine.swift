import Foundation
import SwiftData
import UserNotifications

// MARK: - Milestone Engine
// Data-driven appreciation notifications. Fires each milestone at most once
// per day per profile, based on real HealthKit + logged data only.

enum MilestoneEngine {

    struct Milestone {
        let id: String
        let title: String
        let body: String
    }

    // MARK: - Entry point (call after data loads)

    @MainActor
    static func checkDailyMilestones(context: ModelContext, profile: UserProfile) async {
        // Ensure permission (no-op if already granted/denied)
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .notDetermined else { return }

        var milestones: [Milestone] = []

        // 1. Steps
        if let steps = await HealthMetricsProvider.shared.fetchStepsRobust() {
            if steps >= 15000 {
                milestones.append(Milestone(
                    id: "steps_15k",
                    title: "15,000 steps! 🏆",
                    body: "Outstanding day of movement — that's elite territory."
                ))
            } else if steps >= 10000 {
                milestones.append(Milestone(
                    id: "steps_10k",
                    title: "10,000 steps! 🎉",
                    body: "You crushed the classic daily target. Great work."
                ))
            } else if steps >= 5000 {
                milestones.append(Milestone(
                    id: "steps_5k",
                    title: "5,000 steps 👟",
                    body: "Solid movement today — halfway to 10k."
                ))
            }
        }

        // 2. Sleep
        if let sleep = await HealthMetricsProvider.shared.fetchSleepRobust(), sleep >= 7.0 {
            milestones.append(Milestone(
                id: "sleep_7h",
                title: String(format: "%.1fh of sleep 😴", sleep),
                body: "Recovery fuel secured — your muscles thank you."
            ))
        }

        // 3. Protein target
        let pid = ActiveProfile.id
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let nutritionDescriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate { $0.profileId == pid && $0.date >= startOfDay }
        )
        if let todayLog = (try? context.fetch(nutritionDescriptor))?.first,
           todayLog.proteinTarget > 0,
           todayLog.totalProtein >= todayLog.proteinTarget {
            milestones.append(Milestone(
                id: "protein_target",
                title: "Protein target hit 💪",
                body: "\(Int(todayLog.totalProtein))g logged — growth conditions met."
            ))
        }

        // 4. Calorie target adherence (evening only, so it isn't a false-positive at breakfast)
        if Calendar.current.component(.hour, from: Date()) >= 18,
           let todayLog = (try? context.fetch(nutritionDescriptor))?.first,
           todayLog.calorieTarget > 0 {
            let ratio = todayLog.totalCalories / todayLog.calorieTarget
            if ratio >= 0.9 && ratio <= 1.1 {
                milestones.append(Milestone(
                    id: "calorie_target",
                    title: "Calories on target 🎯",
                    body: "\(Int(todayLog.totalCalories)) kcal logged — right where the plan wants you."
                ))
            }
        }

        // 5. Supplement streak milestones
        let streak = supplementStreak(context: context)
        for threshold in [7, 14, 30] where streak == threshold {
            milestones.append(Milestone(
                id: "supp_streak_\(threshold)",
                title: "\(threshold)-day supplement streak 🔥",
                body: "Consistency compounds. Keep the chain going."
            ))
        }

        // 6. Weekly session count (fires when hitting planned count)
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let sessionDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.profileId == pid && $0.isCompleted == true && $0.date >= weekAgo }
        )
        let weekSessions = (try? context.fetch(sessionDescriptor))?.count ?? 0
        let planned = TrainingDayStore.all(context: context).filter { $0.weekday != 0 }.count
        if planned > 0 && weekSessions == planned {
            milestones.append(Milestone(
                id: "week_complete",
                title: "Training week complete ✅",
                body: "\(weekSessions)/\(planned) sessions done. The plan is working because you are."
            ))
        }

        // Fire the ones not yet sent today
        for milestone in milestones where !alreadySent(milestone.id) {
            send(milestone, context: context, profile: profile)
            markSent(milestone.id)
        }
    }

    // MARK: - Dedupe (once per day per profile)

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

    // MARK: - Delivery

    @MainActor
    private static func send(_ milestone: Milestone, context: ModelContext, profile: UserProfile) {
        NotificationManager.shared.recordInInbox(
            category: .milestone,
            title: milestone.title,
            body: milestone.body,
            destination: .progress,
            deduplicationKey: "milestone_\(milestone.id)_\(todayKey(milestone.id))",
            context: context
        )

        MilestoneToastManager.shared.show(milestone)

        guard NotificationManager.shared.isCategoryEnabled(.milestone, profile: profile) else { return }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: .now)
        guard !NotificationManager.shared.isQuietHours(
            hour: comps.hour ?? 0, minute: comps.minute ?? 0, profile: profile
        ) else { return }

        let content = UNMutableNotificationContent()
        content.title = milestone.title
        content.body = milestone.body
        content.sound = .default
        content.userInfo = ["destination": NotificationDestination.progress.rawValue]

        let request = UNNotificationRequest(
            identifier: "milestone_\(milestone.id)_\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers

    private static func supplementStreak(context: ModelContext) -> Int {
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .day, value: -35, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate { $0.profileId == pid && $0.date >= monthAgo },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        let logsByDay = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.date) }

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        if (logsByDay[cursor]?.first?.supplementsTaken.isEmpty ?? true) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while let dayLogs = logsByDay[cursor],
              let log = dayLogs.first,
              !log.supplementsTaken.isEmpty {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }
}//
//  MilestoneEngine.swift
//  Paya
//
//  Created by Emin Huseynzade on 17.07.26.
//
