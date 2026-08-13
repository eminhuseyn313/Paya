import Foundation

// MARK: - Training Science Engine
// Decouples two axes the old catalog conflated: "which split fits your
// actual available days" and "how hard/how much volume for your
// experience." Previously a template's tier AND day count were locked
// together (e.g. only a beginner ever got a 3-day full-body plan, only an
// advanced lifter ever got 5 days) — so an advanced lifter with 2 days
// available had no correct-intensity option, and a beginner who wanted 4
// days got forced into 3. This picks the split by (goal, days available),
// then scales volume/intensity by experience independently.
//
// Split-by-frequency mapping follows the frequency/volume literature
// (Schoenfeld et al. meta-analyses on training frequency; Israetel/RP
// volume-landmark guidance): full-body is the correct choice at low
// frequency, upper/lower captures the ≥2×/week-per-muscle sweet spot at
// four days, and a push/pull/legs-style split with heavier isolation only
// pays off once frequency is high enough (5–6 days) to still hit twice a
// week per muscle. Six-plus days rarely outperforms five well-recovered
// ones, so the engine caps recommendations there and says why.

enum TrainingScienceEngine {

    struct Recommendation {
        let template: ProgramTemplate
        let daysPerWeek: Int
        let exactDayMatch: Bool
        let volumeAdjustment: VolumeAdjustment
        let rationale: [String]
    }

    struct VolumeAdjustment {
        let setDelta: Int          // added/removed sets on compound lifts
        let restMultiplier: Double
        let intensityNote: String  // appended to every exercise's note
    }

    static let allowedDaysRange = 2...5

    /// A sensible default if the user hasn't stated a preference yet.
    static func suggestedDaysPerWeek(goal: TrainingGoal, experience: ExperienceLevel) -> Int {
        switch (goal, experience) {
        case (.fatLoss, _), (.stayFit, _), (.endurance, _):
            return experience == .beginner ? 2 : 3
        case (_, .beginner):
            return 3
        case (_, .intermediate):
            return 4
        case (_, .advanced):
            return 5
        }
    }

    // MARK: - Volume/intensity scaling by experience

    private static func volumeAdjustment(for experience: ExperienceLevel) -> VolumeAdjustment {
        switch experience {
        case .beginner:
            return VolumeAdjustment(
                setDelta: 0,
                restMultiplier: 1.15,
                intensityNote: "Stop 2-3 reps short of failure — build the movement pattern first"
            )
        case .intermediate:
            return VolumeAdjustment(setDelta: 0, restMultiplier: 1.0, intensityNote: "")
        case .advanced:
            return VolumeAdjustment(
                setDelta: 1,
                restMultiplier: 0.9,
                intensityNote: "Push the last set to RPE 9-10"
            )
        }
    }

    // MARK: - Full recommendation with explanation

    static func recommend(
        goal: TrainingGoal,
        experience: ExperienceLevel,
        equipment: EquipmentAccess,
        injuries: Set<InjuryArea>,
        daysPerWeek: Int,
        priorityMuscle: MusclePriority = .none,
        sexRaw: String = "male"
    ) -> Recommendation? {
        let clamped = min(max(daysPerWeek, allowedDaysRange.lowerBound), allowedDaysRange.upperBound)
        let generated = ProgramAssembler.assemble(
            goal: goal, experience: experience, equipment: equipment,
            injuries: injuries, daysPerWeek: clamped, priorityMuscle: priorityMuscle, sexRaw: sexRaw
        )
        let adjustment = volumeAdjustment(for: experience)

        var rationale: [String] = []
        rationale.append(splitRationale(daysPerWeek: clamped, goal: goal))
        if clamped != daysPerWeek {
            rationale.append("You asked for \(daysPerWeek)×/week — that's outside the supported 2-5 day range, so this is built at \(clamped)×/week instead.")
        }
        rationale.append("Every exercise is picked from a real movement-pattern pool — not a fixed catalogue entry — so the plan is assembled specifically for your goal, equipment, and level. Tap any exercise for the coaching note explaining why that pattern is in the session.")
        rationale.append("Progression is double progression: add a rep each session until you hit the top of the rep range, then add weight and drop back down. After 5 consecutive training weeks, the next week auto-deloads (~35% lighter) to dissipate fatigue before the next block — this isn't a one-time plan, it's how the same plan should evolve week to week.")
        if goal == .hypertrophy, priorityMuscle != .none {
            rationale.append("\(priorityMuscle.displayName) gets one extra exercise every day it's not already the focus — hypertrophy is where prioritizing a muscle actually changes the plan.")
        }
        if sexRaw.lowercased() == "female" {
            // Fatigue resistance: Hunter SK. "Sex differences in human
            // fatigability: mechanisms and insight to physiological
            // responses." Acta Physiol (Oxf). 2014 — women show greater
            // fatigue resistance than men in submaximal/sustained efforts.
            // ACL risk: Prodromos CC, et al. "A meta-analysis of the
            // incidence of anterior cruciate ligament tears as a function
            // of gender, sport, and a knee injury-reduction regimen."
            // Arthroscopy. 2007 — female athletes show substantially higher
            // ACL injury rates in comparable sports; hip/glute neuromuscular
            // training is a standard evidence-based countermeasure.
            rationale.append("Rest periods are trimmed slightly (women show greater resistance to fatigue in sustained effort), and a hip/glute activation exercise is added on lower-body days — real injury-prevention research (ACL risk), not a different program.")
        }
        rationale.append(experienceRationale(experience))
        if equipment != .fullGym {
            rationale.append("Exercises are chosen to fit \(equipment.displayName.lowercased()) directly, not swapped in after the fact.")
        }
        if !injuries.isEmpty {
            let names = injuries.map { $0.displayName.lowercased() }.joined(separator: ", ")
            rationale.append("Exercises that commonly stress your flagged areas (\(names)) are deprioritized in favor of a gentler pick when one exists.")
        }

        return Recommendation(
            template: generated,
            daysPerWeek: clamped,
            exactDayMatch: true,
            volumeAdjustment: adjustment,
            rationale: rationale
        )
    }

    private static func splitRationale(daysPerWeek: Int, goal: TrainingGoal) -> String {
        switch daysPerWeek {
        case ..<3:
            return "At \(daysPerWeek)×/week, full-body sessions are the only way to hit every muscle group with enough weekly frequency to grow — split routines lose too much per muscle at this frequency."
        case 3:
            return "3×/week full-body gives each muscle group frequency roughly twice a week, which the frequency research favors over a single hard hit."
        case 4:
            return "4×/week upper/lower lets you train each muscle group twice weekly at more volume per session than full-body allows — the frequency sweet spot once you have four days."
        default:
            return "At \(daysPerWeek)×/week there's enough frequency to specialize by day (push/pull/legs-style) while still hitting everything twice a week."
        }
    }

    private static func experienceRationale(_ experience: ExperienceLevel) -> String {
        switch experience {
        case .beginner:
            return "As someone newer to training, sets are kept at the plan's baseline and rests a bit longer — technique first, intensity later."
        case .intermediate:
            return "Volume and rest are used as written — you're past the point where more sets beat consistent, progressive ones."
        case .advanced:
            return "An extra set is added to key compounds and rests are tightened — you need the added stimulus to keep progressing."
        }
    }
}
