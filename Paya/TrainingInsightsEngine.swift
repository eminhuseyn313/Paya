import Foundation
import SwiftData

struct TrainingInsight: Identifiable {
    let id = UUID()
    let icon: String
    let colorHex: String
    let title: String
    let detail: String
    let priority: Int
}

@MainActor
struct TrainingInsightsEngine {

    static func generate(sessions: [TrainingSession], context: ModelContext) -> [TrainingInsight] {
        var insights: [TrainingInsight] = []
        let calendar = Calendar.current
        let now = Date()
        let completed = sessions.filter { $0.isCompleted }.sorted { $0.date > $1.date }
        guard !completed.isEmpty else { return [] }

        // 1. Consistency streak
        let weekStreakInsight = weekStreakInsight(sessions: completed, calendar: calendar, now: now)
        if let ws = weekStreakInsight { insights.append(ws) }

        // 2. Volume trend (this week vs last week)
        if let vt = volumeTrendInsight(sessions: completed, calendar: calendar, now: now) {
            insights.append(vt)
        }

        // 3. Neglected muscle groups (>7 days)
        insights.append(contentsOf: neglectedMuscleInsights(sessions: completed, calendar: calendar, now: now))

        // 4. Recent PRs
        if let pr = recentPRInsight(sessions: completed, calendar: calendar, now: now) {
            insights.append(pr)
        }

        // 5. Session frequency trend
        if let freq = frequencyInsight(sessions: completed, calendar: calendar, now: now) {
            insights.append(freq)
        }

        // 6. e1RM improvements on key lifts
        insights.append(contentsOf: strengthGainInsights(sessions: completed))

        // 7. Rest day suggestion
        if let rest = restDayInsight(sessions: completed, calendar: calendar, now: now) {
            insights.append(rest)
        }

        return insights.sorted { $0.priority > $1.priority }
    }

    // MARK: - Week Streak

    private static func weekStreakInsight(sessions: [TrainingSession], calendar: Calendar, now: Date) -> TrainingInsight? {
        var streak = 0
        let today = calendar.startOfDay(for: now)
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!

        var currentWeekStart = weekStart
        while true {
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: currentWeekStart)!
            let hasSessions = sessions.contains { $0.date >= currentWeekStart && $0.date < weekEnd }
            if hasSessions {
                streak += 1
                currentWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart)!
            } else {
                break
            }
        }

        guard streak >= 3 else { return nil }
        return TrainingInsight(
            icon: "flame.fill",
            colorHex: "B45309",
            title: "\(streak)-week training streak",
            detail: "You've trained every week for \(streak) weeks straight. Keep it going!",
            priority: 70
        )
    }

    // MARK: - Volume Trend

    private static func volumeTrendInsight(sessions: [TrainingSession], calendar: Calendar, now: Date) -> TrainingInsight? {
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart)!

        let thisWeekVol = sessions
            .filter { $0.date >= weekStart }
            .flatMap(\.exercises).flatMap(\.sets)
            .filter(\.isCompleted)
            .reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }

        let lastWeekVol = sessions
            .filter { $0.date >= lastWeekStart && $0.date < weekStart }
            .flatMap(\.exercises).flatMap(\.sets)
            .filter(\.isCompleted)
            .reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }

        guard lastWeekVol > 0, thisWeekVol > 0 else { return nil }
        let change = ((thisWeekVol - lastWeekVol) / lastWeekVol) * 100
        guard abs(change) >= 5 else { return nil }

        if change > 0 {
            return TrainingInsight(
                icon: "arrow.up.right",
                colorHex: "059669",
                title: "Volume up \(Int(change))%",
                detail: String(format: "%.0f kg this week vs %.0f kg last week.", thisWeekVol, lastWeekVol),
                priority: 65
            )
        } else {
            return TrainingInsight(
                icon: "arrow.down.right",
                colorHex: "F59E0B",
                title: "Volume down \(Int(abs(change)))%",
                detail: String(format: "%.0f kg this week vs %.0f kg last week. Recovery week?", thisWeekVol, lastWeekVol),
                priority: 40
            )
        }
    }

    // MARK: - Neglected Muscles

    private static func neglectedMuscleInsights(sessions: [TrainingSession], calendar: Calendar, now: Date) -> [TrainingInsight] {
        var lastTrained: [String: Date] = [:]
        for session in sessions {
            for log in session.exercises {
                guard log.sets.contains(where: \.isCompleted) else { continue }
                let group = log.muscleGroup
                guard !group.isEmpty else { continue }
                if let existing = lastTrained[group] {
                    if session.date > existing { lastTrained[group] = session.date }
                } else {
                    lastTrained[group] = session.date
                }
            }
        }

        return lastTrained.compactMap { group, date in
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            guard days >= 7 else { return nil }
            return TrainingInsight(
                icon: "exclamationmark.circle",
                colorHex: "F59E0B",
                title: "\(group) — \(days) days untrained",
                detail: "Consider adding \(group.lowercased()) work to your next session to maintain balance.",
                priority: 50 + min(days, 14)
            )
        }
    }

    // MARK: - Recent PRs

    private static func recentPRInsight(sessions: [TrainingSession], calendar: Calendar, now: Date) -> TrainingInsight? {
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let recentPRs = sessions
            .filter { $0.date >= weekAgo }
            .flatMap(\.exercises)
            .filter(\.isPersonalBest)

        guard !recentPRs.isEmpty else { return nil }
        let names = Array(Set(recentPRs.map(\.exerciseName))).prefix(3)
        let nameList = names.joined(separator: ", ")

        return TrainingInsight(
            icon: "trophy.fill",
            colorHex: "B45309",
            title: "\(recentPRs.count) PR\(recentPRs.count > 1 ? "s" : "") this week",
            detail: "New personal bests on \(nameList). You're getting stronger.",
            priority: 80
        )
    }

    // MARK: - Frequency

    private static func frequencyInsight(sessions: [TrainingSession], calendar: Calendar, now: Date) -> TrainingInsight? {
        let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: now)!
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now)!

        let recent = sessions.filter { $0.date >= twoWeeksAgo }.count
        let prior = sessions.filter { $0.date >= fourWeeksAgo && $0.date < twoWeeksAgo }.count

        guard prior > 0 else { return nil }
        let recentPerWeek = Double(recent) / 2.0
        let priorPerWeek = Double(prior) / 2.0

        guard abs(recentPerWeek - priorPerWeek) >= 0.5 else { return nil }

        if recentPerWeek > priorPerWeek {
            return TrainingInsight(
                icon: "chart.line.uptrend.xyaxis",
                colorHex: "059669",
                title: String(format: "%.1f→%.1f sessions/week", priorPerWeek, recentPerWeek),
                detail: "Training frequency is up. Great consistency.",
                priority: 55
            )
        } else {
            return TrainingInsight(
                icon: "chart.line.downtrend.xyaxis",
                colorHex: "F59E0B",
                title: String(format: "%.1f→%.1f sessions/week", priorPerWeek, recentPerWeek),
                detail: "Frequency dipped — life happens. One session beats zero.",
                priority: 45
            )
        }
    }

    // MARK: - Strength Gains (e1RM comparison)

    private static func nameMatches(_ name: String, canonical: String) -> Bool {
        let n = name.lowercased()
        let c = canonical.lowercased()
        return n == c || n.contains(c) || c.contains(n)
    }

    private static func strengthGainInsights(sessions: [TrainingSession]) -> [TrainingInsight] {
        let keyLifts = ["Bench Press", "Squat", "Deadlift", "Overhead Press", "Barbell Row"]
        var insights: [TrainingInsight] = []

        for liftName in keyLifts {
            let matching = sessions
                .flatMap(\.exercises)
                .filter { nameMatches($0.exerciseName, canonical: liftName) }
                .sorted { ($0.session?.date ?? .distantPast) > ($1.session?.date ?? .distantPast) }

            guard matching.count >= 2 else { continue }
            let recent = matching[0]
            let older = matching.last!

            func best1RM(log: ExerciseLog) -> Double {
                log.sets.filter(\.isCompleted).map { s in
                    s.weightKg * (1 + Double(s.reps) / 30.0)
                }.max() ?? 0
            }

            let current1RM = best1RM(log: recent)
            let old1RM = best1RM(log: older)
            guard old1RM > 0 else { continue }

            let change = ((current1RM - old1RM) / old1RM) * 100
            guard abs(change) >= 3 else { continue }

            if change > 0 {
                insights.append(TrainingInsight(
                    icon: "arrow.up.circle.fill",
                    colorHex: "059669",
                    title: "\(liftName) e1RM +\(Int(change))%",
                    detail: String(format: "Estimated 1RM went from %.0f→%.0f kg since you started.", old1RM, current1RM),
                    priority: 75
                ))
            }
        }

        return insights
    }

    // MARK: - Rest Day

    private static func restDayInsight(sessions: [TrainingSession], calendar: Calendar, now: Date) -> TrainingInsight? {
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now)!
        let consecutiveDays = sessions.filter { $0.date >= threeDaysAgo }.count
        guard consecutiveDays >= 3 else { return nil }

        return TrainingInsight(
            icon: "moon.fill",
            colorHex: "8B5CF6",
            title: "Consider a rest day",
            detail: "You've trained \(consecutiveDays) days in a row. Recovery is where gains happen.",
            priority: 60
        )
    }
}
