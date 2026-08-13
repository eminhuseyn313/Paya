import Foundation

// MARK: - Projection Engine
//
// "At this pace, where do you end up" — the one thing missing from every
// trend chart in the app so far: a number you can see moving, but no sense
// of where it's actually headed. Uses ordinary least-squares linear
// regression over the logged history, the standard, honest way to
// extrapolate a noisy real-world trend without overfitting to the last
// data point. Framed explicitly as "if this pace continues," not a
// promise — trends change, and a straight-line projection is a starting
// expectation, not a guarantee.

enum ProjectionEngine {

    struct WeightProjection {
        let currentWeightKg: Double
        let weeklyRateKg: Double
        let projectedIn4Weeks: Double
        let projectedIn8Weeks: Double
    }

    struct StrengthProjection {
        let exerciseName: String
        let currentE1RM: Double
        let weeklyRateKg: Double
        let projectedIn4Weeks: Double
        let projectedIn8Weeks: Double
    }

    /// Reuses AdaptiveCalorieEngine's own smoothed weekly-rate calculation
    /// (first-half vs. second-half average over a trailing window) so the
    /// projection agrees with whatever number is already driving the
    /// calorie-target adjustments, rather than computing a second,
    /// possibly-different trend from the same data.
    static func weightProjection(logs: [BodyWeightLog]) -> WeightProjection? {
        guard let latest = logs.last else { return nil }
        guard let rate = AdaptiveCalorieEngine.weeklyTrendKg(logs: logs) else { return nil }
        return WeightProjection(
            currentWeightKg: latest.weightKg,
            weeklyRateKg: rate,
            projectedIn4Weeks: latest.weightKg + rate * 4,
            projectedIn8Weeks: latest.weightKg + rate * 8
        )
    }

    /// Linear regression of estimated 1RM against days-since-first-session —
    /// needs at least 3 logged sessions for the exercise to avoid drawing a
    /// "trend" through two noisy points.
    static func strengthProjection(exerciseId: String, exerciseName: String, sessions: [TrainingSession]) -> StrengthProjection? {
        let points = ProgressAnalytics.progression(exerciseId: exerciseId, sessions: sessions)
        guard points.count >= 3, let first = points.first?.date, let last = points.last else { return nil }

        let xs = points.map { $0.date.timeIntervalSince(first) / 86400.0 }
        let ys = points.map(\.bestE1RM)
        guard let slopePerDay = linearRegressionSlope(xs: xs, ys: ys) else { return nil }
        let weeklyRate = slopePerDay * 7

        return StrengthProjection(
            exerciseName: exerciseName,
            currentE1RM: last.bestE1RM,
            weeklyRateKg: weeklyRate,
            projectedIn4Weeks: max(0, last.bestE1RM + weeklyRate * 4),
            projectedIn8Weeks: max(0, last.bestE1RM + weeklyRate * 8)
        )
    }

    private static func linearRegressionSlope(xs: [Double], ys: [Double]) -> Double? {
        let n = Double(xs.count)
        guard n > 1 else { return nil }
        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumX2 = xs.reduce(0) { $0 + $1 * $1 }
        let denominator = n * sumX2 - sumX * sumX
        guard abs(denominator) > 0.0001 else { return nil }
        return (n * sumXY - sumX * sumY) / denominator
    }
}
