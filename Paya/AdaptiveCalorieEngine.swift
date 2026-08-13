import Foundation
import SwiftData

// MARK: - Adaptive Calorie Engine
// Closes the loop the report flagged as the #1 gap vs. MacroFactor-style
// trackers: Paya computed a calorie target once and never revisited it.
// This compares the user's actual weigh-in trend against what their goal
// expects and nudges trainingDayCalories/restDayCalories to match reality,
// at most once a week, with a damped/capped correction and a visible reason.

enum AdaptiveCalorieEngine {

    struct Adjustment {
        let deltaKcal: Double                  // signed, already rounded to 10
        let actualWeeklyKgChange: Double
        let expectedWeeklyKgChange: Double
        let reasonHeadline: String
        let reasonDetail: String
    }

    static let minDaysBetweenAdjustments = 7

    /// Expected weekly bodyweight change scaled to the person's own
    /// bodyweight, not a fixed kg number — evidence-based rate-of-change
    /// guidance (Helms et al. 2014 lean-gain/fat-loss rate reviews; the
    /// commonly cited Aragon/Alan Lyle McDonald ranges) expresses these as
    /// %BW/week because a flat "-0.5kg/week" is a very different, and for
    /// smaller people much more aggressive, deficit than it is for someone
    /// twice their size. Fat loss: ~0.5%/week (conservative end of the
    /// 0.5-1%/week range, to protect muscle and energy); hypertrophy:
    /// ~0.25%/week lean-gain rate; strength: ~0.15%/week (recomp-leaning).
    static func expectedWeeklyChangeKg(for goal: TrainingGoal, bodyWeightKg: Double) -> Double {
        switch goal {
        case .fatLoss:     return -0.005 * bodyWeightKg
        case .hypertrophy: return 0.0025 * bodyWeightKg
        case .strength:    return 0.0015 * bodyWeightKg
        case .stayFit:     return 0.0
        case .endurance:   return 0.0
        }
    }

    /// Weekly rate of change from real weigh-ins, smoothed by comparing the
    /// average of the first half vs. second half of the trailing window
    /// (reduces noise from single-day water-weight swings).
    static func weeklyTrendKg(logs: [BodyWeightLog], asOf now: Date = .now, windowDays: Int = 14) -> Double? {
        let calendar = Calendar.current
        let windowStart = calendar.date(byAdding: .day, value: -windowDays, to: now) ?? now
        let inWindow = logs
            .filter { $0.date >= windowStart && $0.date <= now }
            .sorted { $0.date < $1.date }
        guard inWindow.count >= 2 else { return nil }

        let mid = max(1, inWindow.count / 2)
        let firstHalf = Array(inWindow[..<mid])
        let secondHalf = Array(inWindow[mid...])
        guard !firstHalf.isEmpty, !secondHalf.isEmpty else { return nil }

        let firstAvg = firstHalf.map(\.weightKg).reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.map(\.weightKg).reduce(0, +) / Double(secondHalf.count)

        guard let firstDate = inWindow.first?.date, let lastDate = inWindow.last?.date else { return nil }
        let daySpan = lastDate.timeIntervalSince(firstDate) / 86400.0
        guard daySpan >= 3 else { return nil }   // too little spread to trust a rate

        return (secondAvg - firstAvg) / daySpan * 7.0
    }

    /// Computes the damped, capped daily-calorie nudge, or nil if there's
    /// not enough data yet or the deviation is too small to bother with.
    static func computeAdjustment(goal: TrainingGoal, logs: [BodyWeightLog], bodyWeightKg: Double) -> Adjustment? {
        guard let actual = weeklyTrendKg(logs: logs) else { return nil }
        let expected = expectedWeeklyChangeKg(for: goal, bodyWeightKg: bodyWeightKg)
        let deviationKgPerWeek = expected - actual

        // ~7700 kcal per kg of body mass — the metric-converted form of the
        // classic 3500 kcal/lb rule (Wishnofsky M. "Caloric equivalents of
        // gained or lost weight." Am J Clin Nutr. 1958). That rule is a
        // known oversimplification in practice (actual kcal/kg drifts with
        // body composition and adapts over time per Hall KD's dynamic
        // energy-balance modeling), which is exactly why this is only a
        // starting point for a damped, capped nudge rather than a precise
        // prescription — apply only half the correction per cycle so the
        // target doesn't whipsaw off one noisy week, and cap the swing.
        let rawDailyKcal = deviationKgPerWeek * 7700.0 / 7.0
        let damped = rawDailyKcal * 0.5
        let capped = max(-150.0, min(150.0, damped))
        let rounded = (capped / 10.0).rounded() * 10.0

        guard abs(rounded) >= 20 else { return nil }

        let (headline, detail) = reason(deltaKcal: rounded, goal: goal, actual: actual, expected: expected)
        return Adjustment(
            deltaKcal: rounded,
            actualWeeklyKgChange: actual,
            expectedWeeklyKgChange: expected,
            reasonHeadline: headline,
            reasonDetail: detail
        )
    }

    private static func reason(
        deltaKcal: Double, goal: TrainingGoal, actual: Double, expected: Double
    ) -> (String, String) {
        let sign = deltaKcal > 0 ? "+" : ""
        let headline = "\(sign)\(Int(deltaKcal)) kcal"
        let actualStr = String(format: "%.2f", abs(actual))
        let detail: String
        switch goal {
        case .fatLoss:
            detail = actual < expected
                ? "You're losing faster than planned (\(actualStr)kg/wk) — a bit more room to protect muscle and energy."
                : "Weight loss has slowed (\(actualStr)kg/wk) — trimming a little to get back on pace."
        case .hypertrophy, .strength:
            detail = actual < expected
                ? "You're gaining slower than planned (\(actualStr)kg/wk) — adding calories to support growth."
                : "Gaining faster than planned (\(actualStr)kg/wk) — easing back so it stays lean."
        case .stayFit, .endurance:
            detail = actual < 0
                ? "Trending down (\(actualStr)kg/wk) — adding calories to hold steady."
                : "Trending up (\(actualStr)kg/wk) — trimming to hold steady."
        }
        return (headline, detail)
    }

    /// Applies the adjustment to both the persisted profile and the live
    /// AppState mirror, and stamps the adjustment date so it only runs weekly.
    @MainActor
    static func applyIfDue(profile: PersonProfile, appState: AppState, context: ModelContext) {
        let now = Date()
        if let last = profile.lastCalorieAdjustmentDate {
            let days = Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0
            guard days >= minDaysBetweenAdjustments else { return }
        }

        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<BodyWeightLog>(
            predicate: #Predicate<BodyWeightLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        let logs = (try? context.fetch(descriptor)) ?? []

        guard let adjustment = computeAdjustment(goal: profile.goal, logs: logs, bodyWeightKg: profile.currentWeightKg) else { return }

        profile.trainingDayCalories = max(1200, profile.trainingDayCalories + adjustment.deltaKcal)
        profile.restDayCalories = max(1200, profile.restDayCalories + adjustment.deltaKcal)
        profile.lastCalorieAdjustmentDate = now
        profile.lastCalorieAdjustmentKcal = adjustment.deltaKcal
        profile.lastCalorieAdjustmentReason = adjustment.reasonDetail
        try? context.save()

        appState.profile.trainingDayCalories = profile.trainingDayCalories
        appState.profile.restDayCalories = profile.restDayCalories
    }
}
