import Foundation

// MARK: - Plateau Engine
//
// Flags exercises whose estimated 1RM has been flat or declining for 3+
// consecutive logged sessions. Standard RP/Helms-style autoregulation
// guidance: a stall that persists past a couple of sessions is either a
// fatigue problem (answer: deload — already handled by DeloadEngine) or an
// accommodation problem (answer: rotate the exercise variant — same
// movement pattern, different lift, to get a fresh stimulus). This doesn't
// duplicate DeloadEngine's whole-program fatigue detection; it's narrower
// and per-exercise, catching the case where one specific lift stalls while
// the rest of the program is still progressing normally.

@MainActor
enum PlateauEngine {

    struct Flag: Identifiable {
        var id: String { exerciseId }
        let exerciseId: String
        let exerciseName: String
        let sessionsStalled: Int
        let currentE1RM: Double
        let peakE1RM: Double
        let suggestion: String
    }

    private static let minSessionsToFlag = 3

    /// Looks at every exercise with at least `minSessionsToFlag` completed
    /// sessions and flags ones where e1RM hasn't improved (allowing a small
    /// noise margin) across the most recent stretch.
    static func detect(sessions: [TrainingSession]) -> [Flag] {
        detect(sessions: sessions, maxHR: LiveHRManager.shared.maxHR)
    }

    static func detect(sessions: [TrainingSession], maxHR: Int) -> [Flag] {
        let completed = sessions.filter { $0.isCompleted }
        let logged = ProgressAnalytics.loggedExercises(sessions: completed)

        var flags: [Flag] = []
        for exercise in logged {
            let points = ProgressAnalytics.progression(exerciseId: exercise.exerciseId, sessions: completed)
            guard points.count >= minSessionsToFlag else { continue }

            let recent = Array(points.suffix(minSessionsToFlag))
            let peak = points.map(\.bestE1RM).max() ?? 0
            guard peak > 0 else { continue }

            // "Stalled" = no session in the recent window beat the peak from
            // before that window by more than 1% — small enough to not flag
            // normal week-to-week noise, large enough to catch a real stall.
            let priorPeak = points.dropLast(minSessionsToFlag).map(\.bestE1RM).max() ?? 0
            let recentPeak = recent.map(\.bestE1RM).max() ?? 0
            let improved = priorPeak > 0 && recentPeak > priorPeak * 1.01
            guard !improved else { continue }

            // Also require the recent window itself to be flat/declining,
            // not still climbing within the window (a real stall, not a
            // still-in-progress ramp that just started this window).
            guard let recentLast = recent.last, let recentFirst = recent.first else { continue }
            let isFlatOrDeclining = recentLast.bestE1RM <= recentFirst.bestE1RM * 1.01
            guard isFlatOrDeclining else { continue }

            flags.append(Flag(
                exerciseId: exercise.exerciseId,
                exerciseName: exercise.name,
                sessionsStalled: minSessionsToFlag,
                currentE1RM: recentLast.bestE1RM,
                peakE1RM: peak,
                suggestion: suggestion(for: exercise, sessions: completed, maxHR: maxHR)
            ))
        }
        return flags.sorted { $0.peakE1RM > $1.peakE1RM }
    }

    /// Cross-references the stall against actual effort (per-set heart rate,
    /// same data the Effort Map card uses) instead of giving the same
    /// generic "try a variation" line regardless of whether the lifter was
    /// actually pushing. A stall while running consistently light/moderate
    /// %HRmax points at under-intensity, not accommodation — a different
    /// fix (train closer to failure) than a stall while already vigorous/
    /// near-max, where more effort isn't available and rotating the
    /// exercise or deloading is the more sensible next move.
    private static func suggestion(
        for exercise: ProgressAnalytics.LoggedExercise,
        sessions: [TrainingSession],
        maxHR: Int
    ) -> String {
        let avgHRs = sessions
            .flatMap { $0.exercises }
            .filter { $0.exerciseName == exercise.exerciseId }
            .flatMap { $0.sets }
            .compactMap { $0.avgHR }

        guard !avgHRs.isEmpty, maxHR > 0 else {
            return "No progress on \(exercise.name) in \(minSessionsToFlag) straight sessions. If fatigue feels normal, try swapping in a variation of the same movement for a few weeks — same pattern, fresh stimulus."
        }

        let avgPercentMax = (Double(avgHRs.reduce(0, +)) / Double(avgHRs.count)) / Double(maxHR) * 100

        if avgPercentMax < 77 {
            return "No progress on \(exercise.name) in \(minSessionsToFlag) straight sessions — and your heart rate on it has been running light (~\(Int(avgPercentMax))% of max). Worth leaving less in the tank before assuming this needs a deload or variation."
        } else {
            return "No progress on \(exercise.name) in \(minSessionsToFlag) straight sessions despite genuinely pushing (~\(Int(avgPercentMax))% of max HR) — this looks like a real accommodation stall, not an effort problem. Try a variation of the same movement for a few weeks, or check whether you're due a deload."
        }
    }
}
