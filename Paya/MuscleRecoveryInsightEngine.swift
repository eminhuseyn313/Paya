import Foundation
import SwiftData

// MARK: - Muscle Recovery Insight Engine
//
// Joins two things that already existed separately: VolumeLandmarkEngine's
// weekly hard-sets-per-muscle (already computed for the Weekly Volume vs.
// Landmarks card) and the user's actual active supplement stack
// (UserSupplementStore). Deliberately does NOT invent muscle-specific
// supplement claims ("creatine helps your quads specifically") — that's not
// how any of these nutrients work, and this app's whole standard is real
// research, not gimmicks. What IS legitimate: naming which muscles took
// the heaviest load this week, and pointing at the GENERAL recovery levers
// that matter most under high local training stress — protein distribution
// (Schoenfeld/Aragon protein-timing work already cited elsewhere), magnesium
// (Volpe SL. "Magnesium and the Athlete." Curr Sports Med Rep. 2015 — a
// nutrient resistance-trained populations commonly run low on), and sleep,
// checking what's actually in the user's own stack rather than assuming.

enum MuscleRecoveryInsightEngine {

    struct Insight {
        let topMuscles: [String]
        let text: String
    }

    @MainActor
    static func generate(sessions: [TrainingSession], context: ModelContext) -> Insight? {
        let volumes = VolumeLandmarkEngine.weeklyVolume(sessions: sessions)
        let top = volumes.filter { $0.sets > 0 }.sorted { $0.sets > $1.sets }.prefix(2)
        guard let leader = top.first else { return nil }

        let activeSupplementNames = UserSupplementStore.active(context: context).map(\.name)
        let hasMagnesium = activeSupplementNames.contains { $0.localizedCaseInsensitiveContains("magnesium") }
        let hasCreatine = activeSupplementNames.contains { $0.localizedCaseInsensitiveContains("creatine") }

        var levers: [String] = ["spreading protein across the day rather than one big post-workout dose"]
        levers.append(
            hasMagnesium
                ? "your magnesium — genuinely relevant this week given how much you loaded"
                : "magnesium-rich foods (nuts, leafy greens, or a supplement) — commonly low in resistance-trained diets"
        )
        if hasCreatine {
            levers.append("your creatine, which does its most useful work in exactly this kind of high-volume stretch")
        }
        levers.append("prioritizing sleep the night after your heaviest sessions")

        let muscleNames = top.map(\.muscleGroup).joined(separator: " and ")
        let text = "\(muscleNames) took the most load this week (\(leader.sets) hard sets on \(leader.muscleGroup)). Recovery levers that matter most right now: \(levers.joined(separator: "; "))."

        return Insight(topMuscles: top.map(\.muscleGroup), text: text)
    }
}
