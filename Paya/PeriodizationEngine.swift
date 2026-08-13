import Foundation
import SwiftData

// MARK: - Periodization Engine
//
// DeloadEngine already manages the mesocycle level (deload after ~5
// consecutive training weeks — one mesocycle, per Israetel/RP guidance).
// This manages the level above that: the block. A single goal's rate of
// adaptation flattens over time — running hypertrophy-only volume
// indefinitely, or strength-only intensity indefinitely, both plateau
// harder than alternating blocks of each (classic block periodization —
// Issurin's block periodization model, and the same mesocycle-accumulation
// logic RP's own program design guidance uses). ~2 mesocycles (8-12 weeks)
// per block before considering a phase change is a defensible middle
// ground: long enough to actually adapt, short enough to rotate before
// returns flatten hard.
//
// Block start is read from the installed program itself (CustomSession's
// lastEditedAt, set fresh every time ProgramInstaller.install runs) rather
// than a separately-tracked timestamp — one less thing to remember to keep
// in sync, and it's already exactly the right signal: "when did the
// current plan actually start."

enum PeriodizationEngine {

    struct BlockStatus {
        let weeksInBlock: Int
        let currentGoal: TrainingGoal
        let suggestedNextGoal: TrainingGoal
        let isPhaseChangeDue: Bool
        let rationale: String
    }

    static let suggestedBlockWeeks = 10

    @MainActor
    static func evaluate(profile: PersonProfile, context: ModelContext) -> BlockStatus? {
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<CustomSession>(
            predicate: #Predicate<CustomSession> { $0.profileId == pid }
        )
        let sessions = (try? context.fetch(descriptor)) ?? []
        guard let blockStart = sessions.map(\.lastEditedAt).min() else { return nil }

        let weeks = max(0, Calendar.current.dateComponents([.weekOfYear], from: blockStart, to: .now).weekOfYear ?? 0)
        let goal = profile.goal
        let nextGoal = complementaryGoal(for: goal)
        let due = weeks >= suggestedBlockWeeks

        let rationale = due
            ? "You've been on a \(goal.displayName) block for \(weeks) weeks. A single goal's rate of progress flattens over time — rotating into a \(nextGoal.displayName) block for a few weeks is a well-supported way to keep adapting before that happens."
            : "Week \(weeks) of a typical 8-12 week \(goal.displayName) block."

        return BlockStatus(
            weeksInBlock: weeks,
            currentGoal: goal,
            suggestedNextGoal: nextGoal,
            isPhaseChangeDue: due,
            rationale: rationale
        )
    }

    /// Not a universal rule — just the most common, well-supported pairing:
    /// hypertrophy and strength blocks alternate well since they emphasize
    /// different rep ranges/intensities on the same lifts. Fat-loss and
    /// stay-fit blocks rotate toward hypertrophy (muscle retention/growth
    /// work) since that's the more common next priority once a deficit or
    /// maintenance phase ends.
    private static func complementaryGoal(for goal: TrainingGoal) -> TrainingGoal {
        switch goal {
        case .hypertrophy: return .strength
        case .strength: return .hypertrophy
        case .fatLoss: return .hypertrophy
        case .stayFit: return .hypertrophy
        case .endurance: return .strength
        }
    }
}
