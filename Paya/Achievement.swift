import Foundation
import SwiftData

@Model
class Achievement {
    var id: UUID
    var key: String
    var title: String
    var subtitle: String
    var icon: String
    var colorHex: String
    var category: String
    var earnedAt: Date
    var profileId: UUID?

    init(key: String, title: String, subtitle: String, icon: String, colorHex: String, category: String) {
        self.id = UUID()
        self.key = key
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.colorHex = colorHex
        self.category = category
        self.earnedAt = Date()
        self.profileId = ActiveProfile.id
    }
}

enum AchievementEngine {

    struct Badge {
        let key: String
        let title: String
        let subtitle: String
        let icon: String
        let colorHex: String
        let category: String
        let check: ([TrainingSession], ModelContext) -> Bool
    }

    static let allBadges: [Badge] = [
        // Session milestones
        Badge(key: "first_session", title: "First Rep", subtitle: "Complete your first session", icon: "figure.strengthtraining.traditional", colorHex: "059669", category: "sessions") { sessions, _ in
            sessions.count >= 1
        },
        Badge(key: "10_sessions", title: "Dedicated", subtitle: "Complete 10 sessions", icon: "flame.fill", colorHex: "F59E0B", category: "sessions") { sessions, _ in
            sessions.count >= 10
        },
        Badge(key: "25_sessions", title: "Quarter Century", subtitle: "Complete 25 sessions", icon: "star.fill", colorHex: "2563EB", category: "sessions") { sessions, _ in
            sessions.count >= 25
        },
        Badge(key: "50_sessions", title: "Iron Will", subtitle: "Complete 50 sessions", icon: "trophy.fill", colorHex: "8B5CF6", category: "sessions") { sessions, _ in
            sessions.count >= 50
        },
        Badge(key: "100_sessions", title: "Centurion", subtitle: "Complete 100 sessions", icon: "crown.fill", colorHex: "D97706", category: "sessions") { sessions, _ in
            sessions.count >= 100
        },

        // Streak milestones
        Badge(key: "streak_4w", title: "Month Strong", subtitle: "4-week training streak", icon: "flame.fill", colorHex: "DC2626", category: "consistency") { sessions, _ in
            weekStreak(sessions) >= 4
        },
        Badge(key: "streak_8w", title: "Two Months In", subtitle: "8-week training streak", icon: "flame.circle.fill", colorHex: "DC2626", category: "consistency") { sessions, _ in
            weekStreak(sessions) >= 8
        },
        Badge(key: "streak_12w", title: "Quarter Year", subtitle: "12-week training streak", icon: "bolt.shield.fill", colorHex: "D97706", category: "consistency") { sessions, _ in
            weekStreak(sessions) >= 12
        },

        // Strength milestones
        Badge(key: "first_pr", title: "New Record", subtitle: "Set your first personal record", icon: "trophy.fill", colorHex: "F59E0B", category: "strength") { sessions, _ in
            let prs = ProgressAnalytics.recentPRs(sessions: sessions, daysBack: 9999)
            return !prs.isEmpty
        },
        Badge(key: "10_prs", title: "PR Machine", subtitle: "Set 10 personal records", icon: "bolt.fill", colorHex: "F59E0B", category: "strength") { sessions, _ in
            let prs = ProgressAnalytics.recentPRs(sessions: sessions, daysBack: 9999)
            return prs.count >= 10
        },

        // Volume milestones
        Badge(key: "volume_10t", title: "10 Tonnes", subtitle: "Lift 10,000 kg total volume", icon: "scalemass.fill", colorHex: "0891B2", category: "volume") { sessions, _ in
            totalVolume(sessions) >= 10_000
        },
        Badge(key: "volume_50t", title: "50 Tonnes", subtitle: "Lift 50,000 kg total volume", icon: "dumbbell.fill", colorHex: "0891B2", category: "volume") { sessions, _ in
            totalVolume(sessions) >= 50_000
        },
        Badge(key: "volume_100t", title: "100 Tonnes", subtitle: "Lift 100,000 kg total volume", icon: "figure.strengthtraining.functional", colorHex: "2563EB", category: "volume") { sessions, _ in
            totalVolume(sessions) >= 100_000
        },

        // Duration milestones
        Badge(key: "60min_session", title: "Marathon Set", subtitle: "Complete a 60+ minute session", icon: "timer", colorHex: "8B5CF6", category: "sessions") { sessions, _ in
            sessions.contains { $0.durationMinutes >= 60 }
        },

        // Nutrition (checked via context)
        Badge(key: "protein_7d", title: "Protein Week", subtitle: "Hit protein target 7 days straight", icon: "fork.knife", colorHex: "059669", category: "nutrition") { _, ctx in
            proteinStreak(ctx) >= 7
        },

        // Body tracking
        Badge(key: "first_measurement", title: "Measured Up", subtitle: "Log your first body measurement", icon: "ruler.fill", colorHex: "B45309", category: "body") { _, ctx in
            let pid = ActiveProfile.id
            let desc = FetchDescriptor<BodyMeasurementLog>(
                predicate: #Predicate<BodyMeasurementLog> { $0.profileId == pid }
            )
            return ((try? ctx.fetchCount(desc)) ?? 0) > 0
        },
        Badge(key: "first_photo", title: "Snapshot", subtitle: "Take your first progress photo", icon: "camera.fill", colorHex: "8B5CF6", category: "body") { _, ctx in
            let pid = ActiveProfile.id
            let desc = FetchDescriptor<ProgressPhoto>(
                predicate: #Predicate<ProgressPhoto> { $0.profileId == pid }
            )
            return ((try? ctx.fetchCount(desc)) ?? 0) > 0
        },
    ]

    @MainActor
    static func evaluate(sessions: [TrainingSession], context: ModelContext) {
        let pid = ActiveProfile.id
        let desc = FetchDescriptor<Achievement>(
            predicate: #Predicate<Achievement> { $0.profileId == pid }
        )
        let earned = Set((try? context.fetch(desc))?.map(\.key) ?? [])

        for badge in allBadges {
            guard !earned.contains(badge.key) else { continue }
            if badge.check(sessions, context) {
                let achievement = Achievement(
                    key: badge.key,
                    title: badge.title,
                    subtitle: badge.subtitle,
                    icon: badge.icon,
                    colorHex: badge.colorHex,
                    category: badge.category
                )
                context.insert(achievement)
                MilestoneToastManager.shared.show(
                    MilestoneEngine.Milestone(id: badge.key, title: badge.title, body: badge.subtitle)
                )
            }
        }
        try? context.save()
    }

    private static func weekStreak(_ sessions: [TrainingSession]) -> Int {
        let calendar = Calendar.current
        guard !sessions.isEmpty else { return 0 }
        var weeksWithSession = Set<DateComponents>()
        for session in sessions {
            weeksWithSession.insert(calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.date))
        }
        var streak = 0
        var checkWeekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        ) ?? Date()
        for weekIndex in 0..<104 {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: checkWeekStart)
            if weeksWithSession.contains(comps) {
                streak += 1
            } else if weekIndex > 0 {
                break
            }
            checkWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: checkWeekStart) ?? checkWeekStart
        }
        return streak
    }

    private static func totalVolume(_ sessions: [TrainingSession]) -> Double {
        sessions.reduce(0) { total, session in
            total + session.exercises.reduce(0) { exTotal, log in
                exTotal + log.sets.filter(\.isCompleted).reduce(0) { $0 + $1.weightKg * Double($1.reps) }
            }
        }
    }

    private static func proteinStreak(_ context: ModelContext) -> Int {
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        var streak = 0
        for dayOffset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { break }
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { break }
            let desc = FetchDescriptor<NutritionLog>(
                predicate: #Predicate<NutritionLog> { $0.profileId == pid && $0.date >= start && $0.date < end }
            )
            guard let log = try? context.fetch(desc).first,
                  log.totalProtein >= log.proteinTarget else {
                if dayOffset == 0 { continue }
                break
            }
            streak += 1
        }
        return streak
    }
}
