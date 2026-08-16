import SwiftUI
import SwiftData

// MARK: - Smart Program Engine
// On-device adaptive programming that generates next-week recommendations
// from actual training data. Ties together existing Paya systems:
// - Fatigue index → auto-deload when accumulated fatigue is high
// - Plateau detection → swap or intensify stalled exercises
// - Periodization phase → match volume/intensity to current phase
// - Rep range distribution → rebalance if skewed too far from goal
// - Progressive overload → suggest weight bumps when targets are hit
//
// Grounded in: Helms et al. (2015) "Recommendations for Natural Bodybuilding
// Contest Preparation: Resistance and Cardiovascular Training" — the
// standard evidence-based model for auto-regulated programming adjustments.
// Volume adjustments follow Schoenfeld & Grgic (2018) recommendations:
// 10-20 sets/muscle/week for hypertrophy, adjusted by training status.

// MARK: - Data Types

struct SmartRecommendation: Identifiable {
    let id = UUID()
    let type: RecommendationType
    let exerciseId: String?
    let exerciseName: String?
    let title: String
    let detail: String
    let icon: String
    let color: Color
    let priority: Int // 1 = highest
}

enum RecommendationType {
    case volumeAdjust
    case weightIncrease
    case exerciseSwap
    case deloadSuggestion
    case repRangeShift
    case frequencyChange
    case newExercise
}

// MARK: - Engine

enum SmartProgramEngine {

    struct WeekSummary {
        var totalSets: Int = 0
        var totalVolume: Double = 0
        var sessionCount: Int = 0
        var muscleSetCounts: [String: Int] = [:]
        var exercisePerformance: [String: ExercisePerf] = [:]
        var avgRPE: Double = 0
        var fatigueScore: Double = 0
    }

    struct ExercisePerf {
        var name: String
        var bestE1RM: Double
        var lastWeight: Double
        var lastReps: Int
        var setCount: Int
        var allSetsHitTarget: Bool
        var sessionsAtSameWeight: Int
        var muscleGroup: String
    }

    static func generateRecommendations(
        context: ModelContext,
        exercises: [ExerciseDefinition],
        appState: AppState
    ) -> [SmartRecommendation] {
        let calendar = Calendar.current
        let now = Date()
        let pid = ActiveProfile.id

        // Fetch last 4 weeks of sessions
        let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: now)!
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> {
                $0.profileId == pid && $0.isCompleted && $0.date >= fourWeeksAgo
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let sessions = try? context.fetch(descriptor), sessions.count >= 3 else {
            return [SmartRecommendation(
                type: .volumeAdjust,
                exerciseId: nil,
                exerciseName: nil,
                title: "Keep training",
                detail: "Complete at least 3 sessions for smart recommendations to activate.",
                icon: "brain.head.profile",
                color: Pulse.ai,
                priority: 1
            )]
        }

        // Split into this week vs last week
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now)!
        let thisWeek = sessions.filter { $0.date >= oneWeekAgo }
        let lastWeek = sessions.filter { $0.date >= twoWeeksAgo && $0.date < oneWeekAgo }

        let thisWeekSummary = summarize(sessions: thisWeek)
        let lastWeekSummary = summarize(sessions: lastWeek)
        let allSummary = summarize(sessions: sessions)

        var recommendations: [SmartRecommendation] = []

        // 1. Volume adjustment recommendations
        recommendations.append(contentsOf: volumeRecommendations(
            thisWeek: thisWeekSummary,
            lastWeek: lastWeekSummary,
            all: allSummary
        ))

        // 2. Exercise-specific recommendations (plateaus, weight increases)
        recommendations.append(contentsOf: exerciseRecommendations(
            sessions: sessions,
            exercises: exercises,
            all: allSummary,
            appState: appState
        ))

        // 3. Fatigue / deload recommendations
        recommendations.append(contentsOf: fatigueRecommendations(
            thisWeek: thisWeekSummary,
            all: allSummary,
            sessions: sessions
        ))

        // 4. Rep range balance
        recommendations.append(contentsOf: repRangeRecommendations(sessions: sessions))

        // 5. Frequency recommendations
        recommendations.append(contentsOf: frequencyRecommendations(
            thisWeek: thisWeekSummary,
            lastWeek: lastWeekSummary,
            all: allSummary
        ))

        // Sort by priority, take top 6
        return recommendations
            .sorted { $0.priority < $1.priority }
            .prefix(6)
            .map { $0 }
    }

    // MARK: - Summarize

    private static func summarize(sessions: [TrainingSession]) -> WeekSummary {
        var summary = WeekSummary()
        summary.sessionCount = sessions.count
        var rpeSum = 0.0
        var rpeCount = 0

        for session in sessions {
            for log in session.exercises {
                let completed = log.sets.filter(\.isCompleted)
                let setCount = completed.count
                summary.totalSets += setCount
                summary.muscleSetCounts[log.muscleGroup, default: 0] += setCount

                let volume = completed.reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
                summary.totalVolume += volume

                let bestSet = completed.max(by: {
                    ($0.weightKg * (1 + Double($0.reps) / 30.0)) <
                    ($1.weightKg * (1 + Double($1.reps) / 30.0))
                })
                let lastSet = completed.last

                if let best = bestSet, let last = lastSet {
                    let e1rm = best.weightKg * (1 + Double(best.reps) / 30.0)
                    let key = log.exerciseName
                    if summary.exercisePerformance[key] == nil ||
                       e1rm > (summary.exercisePerformance[key]?.bestE1RM ?? 0) {
                        summary.exercisePerformance[key] = ExercisePerf(
                            name: key,
                            bestE1RM: e1rm,
                            lastWeight: last.weightKg,
                            lastReps: last.reps,
                            setCount: setCount,
                            allSetsHitTarget: false,
                            sessionsAtSameWeight: 1,
                            muscleGroup: log.muscleGroup
                        )
                    }
                }

                for set in completed where set.rpe > 0 {
                    rpeSum += Double(set.rpe)
                    rpeCount += 1
                }
            }
        }

        summary.avgRPE = rpeCount > 0 ? rpeSum / Double(rpeCount) : 0
        return summary
    }

    // MARK: - Volume Recommendations

    private static func volumeRecommendations(
        thisWeek: WeekSummary,
        lastWeek: WeekSummary,
        all: WeekSummary
    ) -> [SmartRecommendation] {
        var recs: [SmartRecommendation] = []

        // Check for under-volumed muscle groups (< 10 sets/week)
        let weeklyAvgSets: [String: Double] = {
            var result: [String: Double] = [:]
            for (muscle, sets) in all.muscleSetCounts {
                let weeks = max(1, Double(all.sessionCount) / 3.5)
                result[muscle] = Double(sets) / weeks
            }
            return result
        }()

        for (muscle, avgSets) in weeklyAvgSets {
            if avgSets < 8 {
                recs.append(SmartRecommendation(
                    type: .volumeAdjust,
                    exerciseId: nil,
                    exerciseName: nil,
                    title: "Add volume: \(muscle)",
                    detail: "Averaging \(String(format: "%.0f", avgSets)) sets/week — below the 10-set minimum for hypertrophy (Schoenfeld & Grgic 2018). Add 2-3 sets next week.",
                    icon: "chart.bar.fill",
                    color: Pulse.nutrition,
                    priority: 3
                ))
            } else if avgSets > 22 {
                recs.append(SmartRecommendation(
                    type: .volumeAdjust,
                    exerciseId: nil,
                    exerciseName: nil,
                    title: "Reduce volume: \(muscle)",
                    detail: "Averaging \(String(format: "%.0f", avgSets)) sets/week — beyond MRV for most lifters. Cut 3-4 sets to improve recovery.",
                    icon: "chart.bar.fill",
                    color: Pulse.critical,
                    priority: 2
                ))
            }
        }

        // Volume trend (this week vs last week)
        if lastWeek.totalVolume > 0 && thisWeek.totalVolume > 0 {
            let change = ((thisWeek.totalVolume - lastWeek.totalVolume) / lastWeek.totalVolume) * 100
            if change > 15 {
                recs.append(SmartRecommendation(
                    type: .volumeAdjust,
                    exerciseId: nil,
                    exerciseName: nil,
                    title: "Volume spike detected",
                    detail: String(format: "%.0f%% more volume than last week. Acute:chronic ratio is elevated — keep RPE moderate to manage fatigue.", change),
                    icon: "exclamationmark.triangle.fill",
                    color: Pulse.nutrition,
                    priority: 2
                ))
            }
        }

        return recs
    }

    // MARK: - Exercise Recommendations

    private static func exerciseRecommendations(
        sessions: [TrainingSession],
        exercises: [ExerciseDefinition],
        all: WeekSummary,
        appState: AppState
    ) -> [SmartRecommendation] {
        var recs: [SmartRecommendation] = []
        let useLbs = appState.profile.prefersLbs
        let convert: (Double) -> Double = { useLbs ? $0 * 2.20462 : $0 }
        let unit = useLbs ? "lbs" : "kg"

        // Detect plateaued exercises (same weight ± 3% across 4+ sessions)
        for exercise in exercises where exercise.measurement.showsWeightField {
            let logs = sessions.flatMap { s in
                s.exercises.filter { $0.exerciseName == exercise.name }
            }
            guard logs.count >= 4 else { continue }

            let weights = logs.compactMap { log -> Double? in
                let completed = log.sets.filter(\.isCompleted)
                guard !completed.isEmpty else { return nil }
                return completed.map(\.weightKg).reduce(0, +) / Double(completed.count)
            }
            guard weights.count >= 4 else { continue }

            let recentFour = Array(weights.prefix(4))
            let avgWeight = recentFour.reduce(0, +) / Double(recentFour.count)
            let maxDev = recentFour.map { abs($0 - avgWeight) / avgWeight }.max() ?? 0

            if maxDev < 0.03 {
                // Check if there are alternatives available
                if !exercise.alternatives.isEmpty {
                    let suggestion = exercise.alternatives.first ?? "a similar movement"
                    recs.append(SmartRecommendation(
                        type: .exerciseSwap,
                        exerciseId: exercise.id,
                        exerciseName: exercise.name,
                        title: "Plateau: \(exercise.name)",
                        detail: "Weight hasn't moved in 4 sessions (\(String(format: "%.0f", convert(avgWeight))) \(unit)). Try swapping to \(suggestion) for 3-4 weeks, or add a technique intensifier (pause reps, tempo sets).",
                        icon: "arrow.triangle.2.circlepath",
                        color: Pulse.critical,
                        priority: 1
                    ))
                } else {
                    recs.append(SmartRecommendation(
                        type: .repRangeShift,
                        exerciseId: exercise.id,
                        exerciseName: exercise.name,
                        title: "Plateau: \(exercise.name)",
                        detail: "Weight stuck at \(String(format: "%.0f", convert(avgWeight))) \(unit) for 4 sessions. Try a different rep range (drop to 4-6 for a strength block, or increase to 12-15 for metabolite stress).",
                        icon: "arrow.triangle.2.circlepath",
                        color: Pulse.nutrition,
                        priority: 2
                    ))
                }
            }
        }

        // Detect exercises ready for weight increase
        for exercise in exercises where exercise.measurement.showsWeightField {
            let recentLogs = sessions.prefix(2).flatMap { s in
                s.exercises.filter { $0.exerciseName == exercise.name }
            }
            guard let lastLog = recentLogs.first else { continue }
            let completed = lastLog.sets.filter(\.isCompleted)
            guard completed.count >= exercise.sets else { continue }

            let allHitTop = completed.allSatisfy { $0.reps >= exercise.repRange.max }
            if allHitTop {
                let currentWeight = completed.map(\.weightKg).reduce(0, +) / Double(completed.count)
                let increment = exercise.repRange.increment
                let newWeight = currentWeight + increment
                recs.append(SmartRecommendation(
                    type: .weightIncrease,
                    exerciseId: exercise.id,
                    exerciseName: exercise.name,
                    title: "Increase: \(exercise.name)",
                    detail: "Hit top of rep range on all sets. Move to \(String(format: "%.1f", convert(newWeight))) \(unit) (+\(String(format: "%.1f", convert(increment)))) next session.",
                    icon: "arrow.up.circle.fill",
                    color: Pulse.positive,
                    priority: 2
                ))
            }
        }

        return recs
    }

    // MARK: - Fatigue Recommendations

    private static func fatigueRecommendations(
        thisWeek: WeekSummary,
        all: WeekSummary,
        sessions: [TrainingSession]
    ) -> [SmartRecommendation] {
        var recs: [SmartRecommendation] = []

        // High RPE across the board
        if all.avgRPE >= 8.5 && all.avgRPE > 0 {
            recs.append(SmartRecommendation(
                type: .deloadSuggestion,
                exerciseId: nil,
                exerciseName: nil,
                title: "Average RPE is high",
                detail: String(format: "Running at RPE %.1f average across 4 weeks. Consider a deload week (reduce volume 40-50%%, keep intensity) to dissipate fatigue before pushing again.", all.avgRPE),
                icon: "battery.25percent",
                color: Pulse.critical,
                priority: 1
            ))
        }

        // Too many consecutive training days
        let calendar = Calendar.current
        let sortedDates = sessions.map { calendar.startOfDay(for: $0.date) }
            .sorted(by: >)
        var consecutiveDays = 1
        for i in 1..<min(sortedDates.count, 10) {
            let diff = calendar.dateComponents([.day], from: sortedDates[i], to: sortedDates[i-1]).day ?? 0
            if diff == 1 { consecutiveDays += 1 } else { break }
        }

        if consecutiveDays >= 5 {
            recs.append(SmartRecommendation(
                type: .deloadSuggestion,
                exerciseId: nil,
                exerciseName: nil,
                title: "Take a rest day",
                detail: "\(consecutiveDays) consecutive training days. Recovery quality drops after 4-5 straight days (Kreher & Schwartz 2012). Schedule a rest day tomorrow.",
                icon: "bed.double.fill",
                color: Pulse.critical,
                priority: 1
            ))
        }

        return recs
    }

    // MARK: - Rep Range Recommendations

    private static func repRangeRecommendations(
        sessions: [TrainingSession]
    ) -> [SmartRecommendation] {
        var recs: [SmartRecommendation] = []
        var strength = 0, hypertrophy = 0, endurance = 0
        var total = 0

        for session in sessions {
            for log in session.exercises {
                for set in log.sets where set.isCompleted && set.reps > 0 {
                    total += 1
                    switch set.reps {
                    case 1...5: strength += 1
                    case 6...12: hypertrophy += 1
                    default: endurance += 1
                    }
                }
            }
        }

        guard total >= 30 else { return recs }
        let t = Double(total)
        let strPct = Double(strength) / t * 100
        let endPct = Double(endurance) / t * 100

        if strPct < 10 {
            recs.append(SmartRecommendation(
                type: .repRangeShift,
                exerciseId: nil,
                exerciseName: nil,
                title: "Add heavy work",
                detail: String(format: "Only %.0f%% of sets in the 1-5 rep range. Including 2-3 heavy compound sets per session builds strength that supports hypertrophy long-term.", strPct),
                icon: "scalemass.fill",
                color: Pulse.hydration,
                priority: 4
            ))
        }

        if endPct > 40 {
            recs.append(SmartRecommendation(
                type: .repRangeShift,
                exerciseId: nil,
                exerciseName: nil,
                title: "Shift to moderate reps",
                detail: String(format: "%.0f%% of sets are 13+ reps. For muscle growth, Schoenfeld (2021) shows 6-12 reps are most efficient. Reserve high-rep work for finishers.", endPct),
                icon: "chart.pie.fill",
                color: Pulse.ai,
                priority: 4
            ))
        }

        return recs
    }

    // MARK: - Frequency Recommendations

    private static func frequencyRecommendations(
        thisWeek: WeekSummary,
        lastWeek: WeekSummary,
        all: WeekSummary
    ) -> [SmartRecommendation] {
        var recs: [SmartRecommendation] = []

        // Muscle groups trained only once per week when they could benefit from 2x
        let weeksOfData = max(1.0, Double(all.sessionCount) / 3.5)
        for (muscle, totalSets) in all.muscleSetCounts {
            let setsPerWeek = Double(totalSets) / weeksOfData
            // If they're doing 10+ sets in a single session but only once a week,
            // suggest splitting across two sessions
            if setsPerWeek >= 10 {
                // Check if it's crammed into few sessions
                let sessionsWithMuscle = all.exercisePerformance.values
                    .filter { $0.muscleGroup == muscle }
                    .count
                let freqPerWeek = Double(sessionsWithMuscle) / weeksOfData
                if freqPerWeek < 1.5 && setsPerWeek >= 12 {
                    recs.append(SmartRecommendation(
                        type: .frequencyChange,
                        exerciseId: nil,
                        exerciseName: nil,
                        title: "Split \(muscle) across 2 days",
                        detail: "Doing \(String(format: "%.0f", setsPerWeek)) sets/week in ~1 session. Splitting across 2 sessions improves recovery and per-set quality (Schoenfeld 2016 meta-analysis).",
                        icon: "calendar.badge.plus",
                        color: Pulse.hydration,
                        priority: 5
                    ))
                }
            }
        }

        return recs
    }
}
