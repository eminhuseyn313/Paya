import Foundation
import SwiftData
import SwiftUI

// MARK: - Momentum System
//
// Streaks that graduate into permanent habit badges after a
// threshold number of consecutive days. Grounded in Lally et al.
// (2010), "How are habits formed: Modelling habit formation in
// the real world," European Journal of Social Psychology —
// the study found the average time for a new behavior to become
// automatic was 66 days, with a range of 18–254. We use 21 days
// as the first milestone (popular heuristic) and 66 as the
// "science-backed" permanence badge.
//
// Unlike Duolingo-style streaks that reset and punish, Paya's
// momentum badges are permanent once earned. Missing a day
// resets the active streak counter but never revokes earned badges.

// MARK: - Habit Definition

struct HabitDef: Identifiable {
    let id: String
    let label: String
    let icon: String
    let colorHex: String
    let category: String
    /// Closure to check if this habit was fulfilled for a given date.
    /// Called with (date, modelContext). Returns true if the habit
    /// was done that day.
    let check: @MainActor (Date, ModelContext) -> Bool
}

// MARK: - Habit Registry

enum HabitRegistry {

    static let all: [HabitDef] = [
        HabitDef(
            id: "training_consistency",
            label: "Training",
            icon: "dumbbell.fill",
            colorHex: "059669",
            category: "fitness"
        ) { date, ctx in
            let pid = ActiveProfile.id
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
            let desc = FetchDescriptor<TrainingSession>(
                predicate: #Predicate<TrainingSession> {
                    $0.profileId == pid && $0.isCompleted && $0.date >= start && $0.date < end
                }
            )
            return ((try? ctx.fetchCount(desc)) ?? 0) > 0
        },

        HabitDef(
            id: "protein_target",
            label: "Protein target",
            icon: "target",
            colorHex: "2563EB",
            category: "nutrition"
        ) { date, ctx in
            let pid = ActiveProfile.id
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: date)
            let desc = FetchDescriptor<NutritionLog>(
                predicate: #Predicate<NutritionLog> { $0.profileId == pid && $0.date >= start }
            )
            guard let log = (try? ctx.fetch(desc))?.first else { return false }
            return log.totalProtein >= Double(log.proteinTarget) * 0.9  // 90% counts
        },

        HabitDef(
            id: "hydration",
            label: "Hydration",
            icon: "drop.fill",
            colorHex: "0891B2",
            category: "health"
        ) { date, ctx in
            let pid = ActiveProfile.id
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
            let desc = FetchDescriptor<WaterEventLog>(
                predicate: #Predicate<WaterEventLog> {
                    $0.profileId == pid && $0.date >= start && $0.date < end
                }
            )
            let logs = (try? ctx.fetch(desc)) ?? []
            let totalMl = logs.reduce(0) { $0 + $1.ml }
            return totalMl >= 2000  // 2L minimum
        },

        HabitDef(
            id: "check_in",
            label: "Morning check-in",
            icon: "sun.max.fill",
            colorHex: "F59E0B",
            category: "wellness"
        ) { date, ctx in
            let pid = ActiveProfile.id
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
            let desc = FetchDescriptor<DailyCheckIn>(
                predicate: #Predicate<DailyCheckIn> {
                    $0.profileId == pid && $0.date >= start && $0.date < end
                }
            )
            return ((try? ctx.fetchCount(desc)) ?? 0) > 0
        },

        HabitDef(
            id: "supplements",
            label: "Supplements",
            icon: "pills.fill",
            colorHex: "8B5CF6",
            category: "health"
        ) { date, ctx in
            let pid = ActiveProfile.id
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return false }
            // Check if any supplement doses were logged
            let desc = FetchDescriptor<MedicationDoseLog>(
                predicate: #Predicate<MedicationDoseLog> {
                    $0.profileId == pid && $0.takenAt >= start && $0.takenAt < end
                }
            )
            return ((try? ctx.fetchCount(desc)) ?? 0) > 0
        },
    ]
}

// MARK: - Momentum Streak

struct MomentumStreak: Identifiable {
    let id: String  // matches HabitDef.id
    let habit: HabitDef
    var currentStreak: Int
    var longestStreak: Int
    var hasFormedHabit: Bool      // 21+ days consecutive
    var hasPermanentBadge: Bool   // 66+ days (Lally et al. 2010)
    var todayDone: Bool
}

// MARK: - Momentum Engine

enum MomentumEngine {

    @MainActor
    static func computeStreaks(context: ModelContext) -> [MomentumStreak] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        return HabitRegistry.all.map { habit in
            var streak = 0
            var longest = 0

            // Walk backwards from today
            let todayDone = habit.check(today, context)
            if todayDone { streak = 1 }

            // Check yesterday and further back
            var checkDay = calendar.date(byAdding: .day, value: -1, to: today)!
            var counting = todayDone

            for _ in 0..<120 {  // look back up to 120 days
                let done = habit.check(checkDay, context)
                if done {
                    if counting {
                        streak += 1
                    }
                    // Always count for longest
                } else {
                    if counting {
                        longest = max(longest, streak)
                        counting = false
                    }
                }
                checkDay = calendar.date(byAdding: .day, value: -1, to: checkDay)!
            }
            longest = max(longest, streak)

            return MomentumStreak(
                id: habit.id,
                habit: habit,
                currentStreak: streak,
                longestStreak: longest,
                hasFormedHabit: longest >= 21,
                hasPermanentBadge: longest >= 66,
                todayDone: todayDone
            )
        }
    }

    /// Grants Achievement badges for momentum milestones.
    @MainActor
    static func grantBadges(context: ModelContext) {
        let streaks = computeStreaks(context: context)
        let pid = ActiveProfile.id

        let existingDesc = FetchDescriptor<Achievement>(
            predicate: #Predicate<Achievement> { $0.profileId == pid }
        )
        let existing = (try? context.fetch(existingDesc)) ?? []
        let existingKeys = Set(existing.map(\.key))

        for s in streaks {
            // 21-day badge
            if s.hasFormedHabit {
                let key = "momentum_21_\(s.id)"
                if !existingKeys.contains(key) {
                    let badge = Achievement(
                        key: key,
                        title: "Habit formed: \(s.habit.label)",
                        subtitle: "21-day \(s.habit.label.lowercased()) streak",
                        icon: "checkmark.seal.fill",
                        colorHex: s.habit.colorHex,
                        category: "momentum"
                    )
                    context.insert(badge)
                }
            }

            // 66-day permanent badge (Lally et al. 2010)
            if s.hasPermanentBadge {
                let key = "momentum_66_\(s.id)"
                if !existingKeys.contains(key) {
                    let badge = Achievement(
                        key: key,
                        title: "Automatic: \(s.habit.label)",
                        subtitle: "66 days — habit is now automatic (Lally 2010)",
                        icon: "star.circle.fill",
                        colorHex: s.habit.colorHex,
                        category: "momentum"
                    )
                    context.insert(badge)
                }
            }
        }
        try? context.save()
    }
}
