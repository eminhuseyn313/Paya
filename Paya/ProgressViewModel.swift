import SwiftUI
import SwiftData

@MainActor
@Observable
class ProgressViewModel {

    // MARK: - State

    var weightLogs: [BodyWeightLog] = []
    var allSessions: [TrainingSession] = []
    var weeklyVolumes: [WeeklyVolume] = []

    // MARK: - Data Types

    struct WeeklyVolume: Identifiable {
        let id = UUID()
        let weekStart: Date
        let volume: Double
        let sessionCount: Int
    }

    // MARK: - Load All Data

    func loadAll(context: ModelContext) {
        loadWeightLogs(context: context)
        loadSessions(context: context)
        buildWeeklyVolumes()
    }

    // MARK: - Weight Logs

    private func loadWeightLogs(context: ModelContext) {
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<BodyWeightLog>(
            predicate: #Predicate<BodyWeightLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        weightLogs = (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Sessions

    private func loadSessions(context: ModelContext) {
            let pid = ActiveProfile.id
            let descriptor = FetchDescriptor<TrainingSession>(
                predicate: #Predicate { $0.profileId == pid && $0.isCompleted == true },
                sortBy: [SortDescriptor(\.date)]
            )
            allSessions = (try? context.fetch(descriptor)) ?? []
        }
    // MARK: - Weekly Volumes

    private func buildWeeklyVolumes() {
        weeklyVolumes = []
        guard !allSessions.isEmpty else { return }

        let calendar = Calendar.current
        var grouped: [Date: [TrainingSession]] = [:]

        for session in allSessions {
            let weekStart = calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.date)
            ) ?? session.date
            grouped[weekStart, default: []].append(session)
        }

        weeklyVolumes = grouped.map { weekStart, sessions in
            let volume = sessions.reduce(0.0) { total, session in
                total + session.exercises.reduce(0.0) { exTotal, ex in
                    exTotal + ex.sets.filter { $0.isCompleted }.reduce(0.0) {
                        $0 + ($1.weightKg * Double($1.reps))
                    }
                }
            }
            return WeeklyVolume(
                weekStart: weekStart,
                volume: volume,
                sessionCount: sessions.count
            )
        }
        .sorted { $0.weekStart < $1.weekStart }
        .suffix(12)
        .map { $0 }
    }

    // MARK: - Computed

    var last30Weights: [BodyWeightLog] {
        Array(weightLogs.suffix(30))
    }

    var totalWeightChange: Double {
        guard let first = weightLogs.first, let last = weightLogs.last else { return 0 }
        return last.weightKg - first.weightKg
    }

    var weeklyWeightChange: Double {
        guard weightLogs.count >= 2 else { return 0 }
        let recent = Array(weightLogs.suffix(7))
        guard let first = recent.first, let last = recent.last else { return 0 }
        return last.weightKg - first.weightKg
    }

    /// Consecutive WEEKS with at least one completed session, not
    /// consecutive calendar days — a daily-streak count is meaningless for
    /// the typical 3-5x/week program (it reads as "1" or "0" almost
    /// permanently for anyone who isn't training literally every single
    /// day, which made this stat look broken rather than motivating).
    /// Doesn't require the current week to already have a session — a
    /// streak shouldn't reset to 0 on a Monday morning before today's
    /// workout is even logged.
    var currentStreak: Int {
        let calendar = Calendar.current
        guard !allSessions.isEmpty else { return 0 }

        var weeksWithSession = Set<DateComponents>()
        for session in allSessions {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.date)
            weeksWithSession.insert(comps)
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
                // The current week (index 0) is allowed to be empty so far —
                // any earlier empty week breaks the streak.
                break
            }
            checkWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: checkWeekStart) ?? checkWeekStart
        }
        return streak
    }

    var totalSessionCount: Int { allSessions.count }
}
