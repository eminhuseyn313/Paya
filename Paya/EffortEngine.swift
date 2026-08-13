import Foundation
import SwiftData

// MARK: - Effort Engine
// Goal-aware weekly effort scoring. Uses the levers that actually drive
// each goal: volume/RPE for muscle, load for strength, TRIMP/deficit for
// fat loss, zone-minutes for endurance, consistency for general fitness.

enum EffortEngine {

    struct WeeklyReport {
        let goal: TrainingGoal
        let score: Int                    // 0-100
        let components: [Component]
        let headline: String

        var grade: Grade {
            switch score {
            case 80...: return .onTrack
            case 55..<80: return .close
            default: return .offTrack
            }
        }
    }

    struct Component: Identifiable {
        let id = UUID()
        let name: String
        let detail: String
        let score: Int          // 0-100
        let weight: Double      // fraction of total
        let icon: String
    }

    enum Grade {
        case onTrack, close, offTrack

        var label: String {
            switch self {
            case .onTrack:  return "On track"
            case .close:    return "Almost there"
            case .offTrack: return "Needs attention"
            }
        }

        var colorHex: String {
            switch self {
            case .onTrack:  return "059669"
            case .close:    return "D97706"
            case .offTrack: return "DC2626"
            }
        }
    }

    // MARK: - Compute

    @MainActor
    static func weeklyReport(
        goal: TrainingGoal,
        context: ModelContext,
        plannedSessionsPerWeek: Int,
        externalActiveMinutes: Int = 0
    ) -> WeeklyReport {
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: now) ?? now

        let sessionDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.profileId == pid && $0.isCompleted == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let allSessions = (try? context.fetch(sessionDescriptor)) ?? []
        let thisWeek = allSessions.filter { $0.date >= weekAgo }
        let lastFourWeeks = allSessions.filter { $0.date >= fourWeeksAgo }

        // Shared components
        let consistency = consistencyScore(
            thisWeek: thisWeek, planned: plannedSessionsPerWeek, externalActiveMinutes: externalActiveMinutes
        )

        var components: [Component] = []

        switch goal {
        case .hypertrophy:
            components = [
                volumeTrendComponent(thisWeek: thisWeek, fourWeeks: lastFourWeeks, weight: 0.4),
                rpeAdherenceComponent(thisWeek: thisWeek, weight: 0.3),
                consistencyComponent(consistency, planned: plannedSessionsPerWeek, done: thisWeek.count, externalActiveMinutes: externalActiveMinutes, weight: 0.3)
            ]
        case .strength:
            components = [
                loadTrendComponent(fourWeeks: lastFourWeeks, weight: 0.5),
                consistencyComponent(consistency, planned: plannedSessionsPerWeek, done: thisWeek.count, externalActiveMinutes: externalActiveMinutes, weight: 0.3),
                rpeAdherenceComponent(thisWeek: thisWeek, weight: 0.2)
            ]
        case .fatLoss:
            components = [
                calorieAdherenceComponent(context: context, weight: 0.4),
                trimpComponent(thisWeek: thisWeek, target: 150, weight: 0.3),
                consistencyComponent(consistency, planned: plannedSessionsPerWeek, done: thisWeek.count, externalActiveMinutes: externalActiveMinutes, weight: 0.3)
            ]
        case .stayFit:
            components = [
                consistencyComponent(consistency, planned: plannedSessionsPerWeek, done: thisWeek.count, externalActiveMinutes: externalActiveMinutes, weight: 0.6),
                trimpComponent(thisWeek: thisWeek, target: 100, weight: 0.4)
            ]
        case .endurance:
            components = [
                zoneMinutesComponent(thisWeek: thisWeek, targetMinutes: 150, weight: 0.5),
                trimpComponent(thisWeek: thisWeek, target: 200, weight: 0.3),
                consistencyComponent(consistency, planned: plannedSessionsPerWeek, done: thisWeek.count, externalActiveMinutes: externalActiveMinutes, weight: 0.2)
            ]
        }

        let total = components.reduce(0.0) { $0 + Double($1.score) * $1.weight }
        let score = Int(total.rounded())

        return WeeklyReport(
            goal: goal,
            score: score,
            components: components,
            headline: headline(for: score, goal: goal)
        )
    }

    // MARK: - Component builders

    private static func consistencyScore(thisWeek: [TrainingSession], planned: Int, externalActiveMinutes: Int) -> Int {
        guard planned > 0 else { return 100 }
        let base = Double(thisWeek.count) / Double(planned) * 100
        // Wearable-recorded activity (Zepp/Watch workouts outside the app) counts as a
        // small consistency bonus — cross-training still shows up as effort, up to +20.
        let bonus = min(20.0, Double(externalActiveMinutes) / 15.0)
        return min(100, Int(base + bonus))
    }

    private static func consistencyComponent(
        _ score: Int, planned: Int, done: Int, externalActiveMinutes: Int, weight: Double
    ) -> Component {
        var detail = "\(done)/\(planned) planned sessions"
        if externalActiveMinutes > 0 {
            detail += " + \(externalActiveMinutes)m wearable"
        }
        return Component(
            name: "Consistency",
            detail: detail,
            score: score,
            weight: weight,
            icon: "calendar.badge.checkmark"
        )
    }

    private static func volumeTrendComponent(thisWeek: [TrainingSession], fourWeeks: [TrainingSession], weight: Double) -> Component {
        let weekVolume = totalVolume(thisWeek)
        let baselineWeekly = totalVolume(fourWeeks) / 4.0

        let score: Int
        let detail: String
        if baselineWeekly < 100 {
            score = thisWeek.isEmpty ? 0 : 70
            detail = "Building baseline — keep logging"
        } else {
            let ratio = weekVolume / baselineWeekly
            // >= baseline is good; +5% or more is excellent
            score = min(100, max(0, Int(ratio * 90)))
            detail = String(format: "%.0f kg vs %.0f kg avg", weekVolume, baselineWeekly)
        }

        return Component(
            name: "Volume trend",
            detail: detail,
            score: score,
            weight: weight,
            icon: "chart.bar.fill"
        )
    }

    private static func rpeAdherenceComponent(thisWeek: [TrainingSession], weight: Double) -> Component {
        let reflected = thisWeek.compactMap { $0.subjectiveRPE }
        let score: Int
        let detail: String
        if reflected.isEmpty {
            score = 50
            detail = "No reflections this week — add RPE after sessions"
        } else {
            let inRange = reflected.filter { (7...9).contains($0) }.count
            score = Int(Double(inRange) / Double(reflected.count) * 100)
            detail = "\(inRange)/\(reflected.count) sessions at RPE 7-9"
        }
        return Component(
            name: "Effort intensity",
            detail: detail,
            score: score,
            weight: weight,
            icon: "bolt.fill"
        )
    }

    private static func loadTrendComponent(fourWeeks: [TrainingSession], weight: Double) -> Component {
        // Compare best e1RM per exercise: first half of window vs second half
        let sorted = fourWeeks.sorted { $0.date < $1.date }
        guard sorted.count >= 4 else {
            return Component(
                name: "Load trend",
                detail: "Need more sessions to measure",
                score: 60, weight: weight, icon: "arrow.up.right"
            )
        }
        let mid = sorted.count / 2
        let firstHalf = Array(sorted[..<mid])
        let secondHalf = Array(sorted[mid...])

        let firstBest = bestE1RMs(firstHalf)
        let secondBest = bestE1RMs(secondHalf)

        var improved = 0
        var compared = 0
        for (key, oldBest) in firstBest {
            guard let newBest = secondBest[key] else { continue }
            compared += 1
            if newBest >= oldBest { improved += 1 }
        }

        guard compared > 0 else {
            return Component(
                name: "Load trend",
                detail: "Not enough overlapping lifts yet",
                score: 60, weight: weight, icon: "arrow.up.right"
            )
        }
        let score = Int(Double(improved) / Double(compared) * 100)
        return Component(
            name: "Load trend",
            detail: "\(improved)/\(compared) lifts improving",
            score: score, weight: weight, icon: "arrow.up.right"
        )
    }

    // TRIMP (Training Impulse) — Banister EW. "Modeling elite athletic
    // performance." In: MacDougall JD, Wenger HA, Green HJ, eds.
    // Physiological Testing of the High-Performance Athlete. 1991. The
    // per-goal weekly targets (100/150/200) are this app's own tuning of
    // that model, not values from Banister's paper.
    private static func trimpComponent(thisWeek: [TrainingSession], target: Double, weight: Double) -> Component {
        let weekTrimp = thisWeek.compactMap { $0.sessionTrimpScore }.reduce(0, +)
        let score = min(100, Int(weekTrimp / target * 100))
        return Component(
            name: "Training load",
            detail: "TRIMP \(Int(weekTrimp)) / \(Int(target)) target",
            score: score, weight: weight, icon: "flame.fill"
        )
    }

    // 150 min/week of moderate-intensity aerobic activity: WHO Guidelines
    // on Physical Activity and Sedentary Behaviour (2020); ACSM's identical
    // adult aerobic recommendation. Zone 2 ≈ 60% of HRmax follows the
    // Karvonen/percent-of-HRmax convention used throughout endurance
    // training literature for the low end of the "moderate intensity" band.
    private static func zoneMinutesComponent(thisWeek: [TrainingSession], targetMinutes: Int, weight: Double) -> Component {
        var seconds = 0
        for session in thisWeek {
            guard let samples = session.hrSamples else { continue }
            let interval = session.hrSampleIntervalSeconds
            let threshold = Int(Double(LiveHRManager.shared.maxHR) * 0.6)
            seconds += samples.filter { $0 >= threshold }.count * interval
        }
        let minutes = seconds / 60
        let score = min(100, Int(Double(minutes) / Double(targetMinutes) * 100))
        return Component(
            name: "Zone minutes",
            detail: "\(minutes)/\(targetMinutes) min in Z2+",
            score: score, weight: weight, icon: "heart.fill"
        )
    }

    @MainActor
    private static func calorieAdherenceComponent(context: ModelContext, weight: Double) -> Component {
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        let descriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate { $0.profileId == pid }
        )
        let logs = ((try? context.fetch(descriptor)) ?? [])
            .filter { $0.date >= weekAgo }

        guard !logs.isEmpty else {
            return Component(
                name: "Calorie adherence",
                detail: "No nutrition logs this week",
                score: 30, weight: weight, icon: "fork.knife"
            )
        }

        // Days within ±10% of target count as adherent
        var adherent = 0
        for log in logs where log.calorieTarget > 0 {
            let ratio = log.totalCalories / log.calorieTarget
            if ratio >= 0.7 && ratio <= 1.1 { adherent += 1 }
        }
        let score = Int(Double(adherent) / Double(logs.count) * 100)
        return Component(
            name: "Calorie adherence",
            detail: "\(adherent)/\(logs.count) days near target",
            score: score, weight: weight, icon: "fork.knife"
        )
    }

    // MARK: - Helpers

    private static func totalVolume(_ sessions: [TrainingSession]) -> Double {
        sessions.reduce(0.0) { total, session in
            total + session.exercises.reduce(0.0) { t, ex in
                t + ex.sets.filter { $0.isCompleted }
                    .reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }
            }
        }
    }

    private static func bestE1RMs(_ sessions: [TrainingSession]) -> [String: Double] {
        var best: [String: Double] = [:]
        for session in sessions {
            for log in session.exercises {
                for set in log.sets where set.isCompleted {
                    let e1rm = ProgressAnalytics.estimatedOneRM(
                        weightKg: set.weightKg, reps: set.reps
                    )
                    if e1rm > (best[log.exerciseName] ?? 0) {
                        best[log.exerciseName] = e1rm
                    }
                }
            }
        }
        return best
    }

    private static func headline(for score: Int, goal: TrainingGoal) -> String {
        switch (score, goal) {
        case (80..., .hypertrophy): return "Growth conditions met — keep this rhythm."
        case (80..., .fatLoss):     return "Deficit and activity on point this week."
        case (80..., _):            return "Strong week — the plan is working."
        case (55..<80, _):          return "Decent week. One more push gets you on track."
        default:                    return "The week slipped. Focus on the lowest bar below."
        }
    }
}//
//  EffortEngine.swift
//  Paya
//
//  Created by Emin Huseynzade on 13.07.26.
//

