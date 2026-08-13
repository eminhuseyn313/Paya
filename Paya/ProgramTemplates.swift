import Foundation
import SwiftData

// MARK: - Program Templates
// Research-based programs per goal AND experience tier.
// Alternatives are embedded per exercise and shown in exercise notes.

// MARK: - Tier

enum ProgramTier: String, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner:     return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced:     return "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .beginner:     return "0-1 year of consistent training"
        case .intermediate: return "1-3 years, knows the main lifts"
        case .advanced:     return "3+ years, needs volume to grow"
        }
    }

    var icon: String {
        switch self {
        case .beginner:     return "leaf.fill"
        case .intermediate: return "flame.fill"
        case .advanced:     return "bolt.fill"
        }
    }
}

// MARK: - Template Models

struct TemplateExercise {
    let name: String
    let sets: Int
    let repMin: Int
    let repMax: Int
    let startWeightKg: Double
    let restSeconds: Int
    let jointSensitive: Bool
    let note: String
    let muscleGroup: String
    let alternatives: [String]

    init(
        name: String, sets: Int, repMin: Int, repMax: Int,
        startWeightKg: Double, restSeconds: Int,
        jointSensitive: Bool = false, note: String = "",
        muscleGroup: String, alternatives: [String] = []
    ) {
        self.name = name
        self.sets = sets
        self.repMin = repMin
        self.repMax = repMax
        self.startWeightKg = startWeightKg
        self.restSeconds = restSeconds
        self.jointSensitive = jointSensitive
        self.note = note
        self.muscleGroup = muscleGroup
        self.alternatives = alternatives
    }

    var measurement: ExerciseMeasurement { .infer(name: name, startWeightKg: startWeightKg) }

    /// Alternatives are now a real tappable swap action on the exercise
    /// card (see ExerciseCardView's swap menu), so the coaching note no
    /// longer needs to spell them out as inert text.
    var fullNote: String { note }
}

struct TemplateDay {
    let code: String
    let name: String
    let focus: String
    let colorHex: String
    let weekday: Int
    let exercises: [TemplateExercise]
}

struct ProgramTemplate: Identifiable {
    let id: String
    let name: String
    let goal: TrainingGoal
    let tier: ProgramTier
    let daysPerWeek: Int
    let summary: String
    let days: [TemplateDay]
}

// MARK: - Catalog

enum ProgramTemplates {

    static func templates(for goal: TrainingGoal) -> [ProgramTemplate] {
        all.filter { $0.goal == goal }
    }

    static func templates(for goal: TrainingGoal, tier: ProgramTier) -> [ProgramTemplate] {
        all.filter { $0.goal == goal && $0.tier == tier }
    }

    static let all: [ProgramTemplate] = [
        hypBeginner, hypIntermediate, hypAdvanced,
        strBeginner, strIntermediate, strAdvanced,
        fatLossBeginner, fatLossStandard, fatLossAdvanced,
        stayFitStandard, stayFitIntermediate, stayFitAdvanced,
        enduranceStandard, enduranceIntermediate, enduranceAdvanced
    ]

    // ==================================================================
    // MARK: HYPERTROPHY — BEGINNER (Full Body 3×)
    // ~10 sets/muscle/week · RPE 6-8 · machine/DB bias · skill building
    // ==================================================================

    static let hypBeginner = ProgramTemplate(
        id: "hyp_beg_fb3",
        name: "Foundation Full Body 3×",
        goal: .hypertrophy,
        tier: .beginner,
        daysPerWeek: 3,
        summary: "The proven starting point: 3 full-body days built on machines and dumbbells, 2-3 sets per exercise at RPE 6-8. Learn movement patterns while your newbie gains do the heavy lifting.",
        days: [
            TemplateDay(
                code: "A", name: "Full Body A", focus: "Push emphasis",
                colorHex: "2563EB", weekday: 2,
                exercises: [
                    TemplateExercise(name: "Leg Press", sets: 3, repMin: 10, repMax: 15, startWeightKg: 60, restSeconds: 120, note: "Full depth, controlled", muscleGroup: "Quads", alternatives: ["Goblet Squat", "Hack Squat"]),
                    TemplateExercise(name: "Machine Chest Press", sets: 3, repMin: 10, repMax: 12, startWeightKg: 30, restSeconds: 90, jointSensitive: true, note: "Stop 2-3 reps before failure", muscleGroup: "Chest", alternatives: ["DB Bench Press", "Push-Up"]),
                    TemplateExercise(name: "Lat Pulldown", sets: 3, repMin: 10, repMax: 12, startWeightKg: 40, restSeconds: 90, muscleGroup: "Back", alternatives: ["Assisted Pull-Up", "Machine Row"]),
                    TemplateExercise(name: "Seated DB Shoulder Press", sets: 2, repMin: 10, repMax: 12, startWeightKg: 8, restSeconds: 90, jointSensitive: true, note: "30° back support", muscleGroup: "Shoulders", alternatives: ["Machine Shoulder Press", "Barbell OHP", "Arnold Press"]),
                    TemplateExercise(name: "Seated Leg Curl", sets: 2, repMin: 12, repMax: 15, startWeightKg: 30, restSeconds: 75, muscleGroup: "Hamstrings", alternatives: ["Lying Leg Curl", "Romanian Deadlift"]),
                    TemplateExercise(name: "Plank", sets: 2, repMin: 30, repMax: 45, startWeightKg: 0, restSeconds: 60, note: "Seconds, not reps", muscleGroup: "Core", alternatives: ["Dead Bug", "Cable Crunch", "Hanging Knee Raise"])
                ]
            ),
            TemplateDay(
                code: "B", name: "Full Body B", focus: "Pull emphasis",
                colorHex: "059669", weekday: 4,
                exercises: [
                    TemplateExercise(name: "Goblet Squat", sets: 3, repMin: 10, repMax: 12, startWeightKg: 16, restSeconds: 120, note: "Heels down, chest up", muscleGroup: "Quads", alternatives: ["Leg Press", "Split Squat"]),
                    TemplateExercise(name: "Seated Cable Row", sets: 3, repMin: 10, repMax: 12, startWeightKg: 35, restSeconds: 90, muscleGroup: "Back", alternatives: ["Chest-Supported Row", "Machine Row"]),
                    TemplateExercise(name: "Incline DB Press", sets: 3, repMin: 10, repMax: 12, startWeightKg: 12, restSeconds: 90, jointSensitive: true, note: "30° incline", muscleGroup: "Chest", alternatives: ["Machine Incline Press", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Face Pulls", sets: 2, repMin: 15, repMax: 20, startWeightKg: 15, restSeconds: 60, note: "Shoulder health priority", muscleGroup: "Rear Delts", alternatives: ["Reverse Pec Deck", "Band Pull-Apart"]),
                    TemplateExercise(name: "Standing Calf Raise", sets: 3, repMin: 12, repMax: 15, startWeightKg: 40, restSeconds: 60, note: "Pause at stretch", muscleGroup: "Calves", alternatives: ["Seated Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise"]),
                    TemplateExercise(name: "DB Curl", sets: 2, repMin: 10, repMax: 12, startWeightKg: 8, restSeconds: 60, muscleGroup: "Biceps", alternatives: ["EZ Bar Curl", "Cable Curl"])
                ]
            ),
            TemplateDay(
                code: "C", name: "Full Body C", focus: "Balanced",
                colorHex: "D97706", weekday: 7,
                exercises: [
                    TemplateExercise(name: "Romanian Deadlift", sets: 3, repMin: 10, repMax: 12, startWeightKg: 30, restSeconds: 120, note: "Hinge, soft knees, flat back", muscleGroup: "Hamstrings", alternatives: ["45° Back Extension", "Seated Leg Curl"]),
                    TemplateExercise(name: "Lat Pulldown", sets: 3, repMin: 10, repMax: 12, startWeightKg: 40, restSeconds: 90, muscleGroup: "Back", alternatives: ["Assisted Pull-Up", "Pull-Up", "Neutral-Grip Pulldown"]),
                    TemplateExercise(name: "Machine Chest Press", sets: 2, repMin: 10, repMax: 12, startWeightKg: 30, restSeconds: 90, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Push-Up", "DB Bench Press"]),
                    TemplateExercise(name: "DB Lateral Raise", sets: 3, repMin: 12, repMax: 15, startWeightKg: 5, restSeconds: 60, jointSensitive: true, note: "Light, strict, no swing", muscleGroup: "Side Delts", alternatives: ["Cable Lateral Raise", "Machine Lateral Raise"]),
                    TemplateExercise(name: "Rope Pushdown", sets: 2, repMin: 12, repMax: 15, startWeightKg: 20, restSeconds: 60, muscleGroup: "Triceps", alternatives: ["Overhead Cable Extension", "Dips", "Close-Grip Bench"]),
                    TemplateExercise(name: "Hanging Knee Raise", sets: 2, repMin: 10, repMax: 15, startWeightKg: 0, restSeconds: 60, muscleGroup: "Core", alternatives: ["Cable Crunch", "Dead Bug"])
                ]
            )
        ]
    )

    // ==================================================================
    // MARK: HYPERTROPHY — INTERMEDIATE (Upper/Lower 4×)
    // 10-16 sets/muscle/week · RPE 7-9 · double progression
    // ==================================================================

    static let hypIntermediate = ProgramTemplate(
        id: "hyp_int_ul4",
        name: "Growth Upper/Lower 4×",
        goal: .hypertrophy,
        tier: .intermediate,
        daysPerWeek: 4,
        summary: "The intermediate sweet spot: upper/lower ×2, 10-16 weekly sets per muscle at RPE 7-9 with double progression. Every muscle trained twice per week — the frequency the meta-analyses favor.",
        days: [
            TemplateDay(
                code: "A", name: "Upper 1", focus: "Horizontal push/pull",
                colorHex: "2563EB", weekday: 2,
                exercises: [
                    TemplateExercise(name: "DB Bench Press", sets: 4, repMin: 8, repMax: 10, startWeightKg: 22, restSeconds: 120, jointSensitive: true, note: "RPE 8, tucked elbows", muscleGroup: "Chest", alternatives: ["Machine Chest Press", "Barbell Bench"]),
                    TemplateExercise(name: "Chest-Supported Row", sets: 4, repMin: 8, repMax: 10, startWeightKg: 20, restSeconds: 120, note: "Squeeze 1s at top", muscleGroup: "Back", alternatives: ["Seated Cable Row", "T-Bar Row"]),
                    TemplateExercise(name: "Seated DB Shoulder Press", sets: 3, repMin: 8, repMax: 12, startWeightKg: 14, restSeconds: 90, jointSensitive: true, muscleGroup: "Shoulders", alternatives: ["Machine Shoulder Press", "Barbell OHP", "Arnold Press"]),
                    TemplateExercise(name: "Lat Pulldown", sets: 3, repMin: 10, repMax: 12, startWeightKg: 50, restSeconds: 90, muscleGroup: "Back", alternatives: ["Pull-Up", "Neutral-Grip Pulldown"]),
                    TemplateExercise(name: "Cable Fly", sets: 2, repMin: 12, repMax: 15, startWeightKg: 12, restSeconds: 75, jointSensitive: true, note: "Stretch focus", muscleGroup: "Chest", alternatives: ["Pec Deck", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "EZ Bar Curl", sets: 3, repMin: 8, repMax: 12, startWeightKg: 20, restSeconds: 75, muscleGroup: "Biceps", alternatives: ["DB Curl", "Cable Curl"]),
                    TemplateExercise(name: "Rope Pushdown", sets: 3, repMin: 10, repMax: 12, startWeightKg: 25, restSeconds: 75, muscleGroup: "Triceps", alternatives: ["Overhead Cable Extension", "Dips"])
                ]
            ),
            TemplateDay(
                code: "B", name: "Lower 1", focus: "Quad emphasis",
                colorHex: "059669", weekday: 3,
                exercises: [
                    TemplateExercise(name: "Leg Press", sets: 4, repMin: 8, repMax: 12, startWeightKg: 100, restSeconds: 150, note: "RPE 8, deep", muscleGroup: "Quads", alternatives: ["Hack Squat", "Barbell Squat"]),
                    TemplateExercise(name: "Romanian Deadlift", sets: 3, repMin: 8, repMax: 10, startWeightKg: 50, restSeconds: 150, note: "Stretch the hamstrings", muscleGroup: "Hamstrings", alternatives: ["45° Back Extension", "Seated Leg Curl", "Lying Leg Curl"]),
                    TemplateExercise(name: "Bulgarian Split Squat", sets: 3, repMin: 8, repMax: 12, startWeightKg: 12, restSeconds: 90, note: "Per leg", muscleGroup: "Quads", alternatives: ["Walking Lunge", "Step-Up"]),
                    TemplateExercise(name: "Seated Leg Curl", sets: 3, repMin: 10, repMax: 15, startWeightKg: 40, restSeconds: 90, muscleGroup: "Hamstrings", alternatives: ["Lying Leg Curl", "Romanian Deadlift", "45° Back Extension"]),
                    TemplateExercise(name: "Standing Calf Raise", sets: 4, repMin: 10, repMax: 15, startWeightKg: 60, restSeconds: 60, note: "Full ROM, pause bottom", muscleGroup: "Calves", alternatives: ["Seated Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise"]),
                    TemplateExercise(name: "Cable Crunch", sets: 3, repMin: 10, repMax: 15, startWeightKg: 30, restSeconds: 60, muscleGroup: "Core", alternatives: ["Hanging Knee Raise", "Plank", "Dead Bug"])
                ]
            ),
            TemplateDay(
                code: "C", name: "Upper 2", focus: "Vertical push/pull + arms",
                colorHex: "8B5CF6", weekday: 5,
                exercises: [
                    TemplateExercise(name: "Incline DB Press", sets: 4, repMin: 8, repMax: 12, startWeightKg: 18, restSeconds: 120, jointSensitive: true, note: "30° incline, RPE 8", muscleGroup: "Chest", alternatives: ["Machine Incline Press", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "One-Arm DB Row", sets: 3, repMin: 8, repMax: 10, startWeightKg: 24, restSeconds: 90, note: "Per arm", muscleGroup: "Back", alternatives: ["Chest-Supported Row", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "Cable Lateral Raise", sets: 4, repMin: 12, repMax: 15, startWeightKg: 5, restSeconds: 60, jointSensitive: true, note: "Side delts respond to volume", muscleGroup: "Side Delts", alternatives: ["DB Lateral Raise", "Machine Lateral Raise"]),
                    TemplateExercise(name: "Face Pulls", sets: 3, repMin: 15, repMax: 20, startWeightKg: 18, restSeconds: 60, note: "Rear delt + cuff health", muscleGroup: "Rear Delts", alternatives: ["Reverse Pec Deck", "Band Pull-Apart", "Rear Delt Fly"]),
                    TemplateExercise(name: "Hammer Curl", sets: 3, repMin: 10, repMax: 12, startWeightKg: 10, restSeconds: 75, muscleGroup: "Biceps", alternatives: ["DB Curl", "EZ Bar Curl", "Cable Curl"]),
                    TemplateExercise(name: "Overhead Cable Extension", sets: 3, repMin: 10, repMax: 15, startWeightKg: 20, restSeconds: 75, note: "Long-head stretch", muscleGroup: "Triceps", alternatives: ["Rope Pushdown", "Dips", "Close-Grip Bench"])
                ]
            ),
            TemplateDay(
                code: "D", name: "Lower 2", focus: "Posterior emphasis",
                colorHex: "DC2626", weekday: 6,
                exercises: [
                    TemplateExercise(name: "Barbell Hip Thrust", sets: 4, repMin: 8, repMax: 12, startWeightKg: 60, restSeconds: 120, note: "1s squeeze at top", muscleGroup: "Glutes", alternatives: ["Machine Hip Thrust", "Glute Bridge"]),
                    TemplateExercise(name: "Hack Squat", sets: 3, repMin: 8, repMax: 12, startWeightKg: 60, restSeconds: 150, note: "Or leg press if unavailable", muscleGroup: "Quads", alternatives: ["Leg Press", "Goblet Squat"]),
                    TemplateExercise(name: "Lying Leg Curl", sets: 3, repMin: 10, repMax: 12, startWeightKg: 35, restSeconds: 90, muscleGroup: "Hamstrings", alternatives: ["Seated Leg Curl", "Romanian Deadlift", "45° Back Extension"]),
                    TemplateExercise(name: "Leg Extension", sets: 3, repMin: 12, repMax: 15, startWeightKg: 40, restSeconds: 75, note: "Squeeze at top", muscleGroup: "Quads", alternatives: ["Sissy Squat", "Leg Press", "Hack Squat"]),
                    TemplateExercise(name: "Seated Calf Raise", sets: 4, repMin: 12, repMax: 15, startWeightKg: 40, restSeconds: 60, muscleGroup: "Calves", alternatives: ["Standing Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise"]),
                    TemplateExercise(name: "Hanging Knee Raise", sets: 3, repMin: 10, repMax: 15, startWeightKg: 0, restSeconds: 60, muscleGroup: "Core", alternatives: ["Cable Crunch", "Plank", "Dead Bug"])
                ]
            )
        ]
    )

    // ==================================================================
    // MARK: HYPERTROPHY — ADVANCED (Upper/Lower/Push/Pull/Legs 5×)
    // 16-20 sets/muscle/week · RPE 8-10 on isolations · high frequency
    // ==================================================================

    static let hypAdvanced = ProgramTemplate(
        id: "hyp_adv_5",
        name: "Peak Hypertrophy 5×",
        goal: .hypertrophy,
        tier: .advanced,
        daysPerWeek: 5,
        summary: "For lifters who've exhausted intermediate gains: 5 days, 16-20 weekly sets per muscle, isolations pushed to RPE 9-10, wide rep ranges (5-20). Demands solid recovery — sleep and food non-negotiable.",
        days: [
            TemplateDay(
                code: "A", name: "Upper Power", focus: "Heavy push/pull",
                colorHex: "2563EB", weekday: 2,
                exercises: [
                    TemplateExercise(name: "DB Bench Press", sets: 4, repMin: 5, repMax: 8, startWeightKg: 28, restSeconds: 180, jointSensitive: true, note: "Neutral grip at lockout, 2s pause on chest, RPE 8", muscleGroup: "Chest", alternatives: ["Barbell Bench", "Machine Press"]),
                    TemplateExercise(name: "Weighted Pull-Up", sets: 4, repMin: 5, repMax: 8, startWeightKg: 0, restSeconds: 180, note: "Wide pronated grip for lat width, add weight when 4×8", muscleGroup: "Back", alternatives: ["Heavy Lat Pulldown", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "Seated DB Shoulder Press", sets: 3, repMin: 6, repMax: 10, startWeightKg: 18, restSeconds: 150, jointSensitive: true, note: "Palms forward, full overhead lockout", muscleGroup: "Shoulders", alternatives: ["Machine Shoulder Press", "Barbell OHP", "Arnold Press"]),
                    TemplateExercise(name: "Chest-Supported Row", sets: 3, repMin: 8, repMax: 10, startWeightKg: 26, restSeconds: 120, note: "Wide overhand grip, 1s squeeze for upper-back width", muscleGroup: "Back", alternatives: ["T-Bar Row", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "EZ Bar Curl", sets: 3, repMin: 8, repMax: 10, startWeightKg: 25, restSeconds: 90, note: "Wide grip on the bar shifts emphasis to the short head", muscleGroup: "Biceps", alternatives: ["Barbell Curl", "DB Curl", "Cable Curl"]),
                    TemplateExercise(name: "Close-Grip Bench", sets: 3, repMin: 8, repMax: 10, startWeightKg: 40, restSeconds: 90, jointSensitive: true, note: "Hands just inside shoulder width, elbows tucked ~30°", muscleGroup: "Triceps", alternatives: ["Dips", "Rope Pushdown"])
                ]
            ),
            TemplateDay(
                code: "B", name: "Lower Power", focus: "Heavy legs",
                colorHex: "059669", weekday: 3,
                exercises: [
                    TemplateExercise(name: "Hack Squat", sets: 4, repMin: 6, repMax: 8, startWeightKg: 80, restSeconds: 180, note: "2s pause at the bottom, RPE 8", muscleGroup: "Quads", alternatives: ["Barbell Squat", "Leg Press"]),
                    TemplateExercise(name: "Romanian Deadlift", sets: 4, repMin: 6, repMax: 8, startWeightKg: 70, restSeconds: 180, note: "Slow 3s eccentric, stop at mid-shin", muscleGroup: "Hamstrings", alternatives: ["Barbell Deadlift", "Seated Leg Curl", "Lying Leg Curl"]),
                    TemplateExercise(name: "Walking Lunge", sets: 3, repMin: 8, repMax: 10, startWeightKg: 16, restSeconds: 120, note: "Long stride, back knee grazes floor — per leg", muscleGroup: "Quads", alternatives: ["Bulgarian Split Squat", "Leg Press", "Hack Squat"]),
                    TemplateExercise(name: "Standing Calf Raise", sets: 4, repMin: 8, repMax: 12, startWeightKg: 80, restSeconds: 90, note: "Full stretch at bottom, 1s pause at top", muscleGroup: "Calves", alternatives: ["Seated Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise"]),
                    TemplateExercise(name: "Cable Crunch", sets: 3, repMin: 10, repMax: 12, startWeightKg: 40, restSeconds: 75, note: "Round the spine — don't just hinge at the hips", muscleGroup: "Core", alternatives: ["Weighted Hanging Raise", "Plank", "Dead Bug"])
                ]
            ),
            TemplateDay(
                code: "C", name: "Push Volume", focus: "Chest/delts/tris pump",
                colorHex: "D97706", weekday: 4,
                exercises: [
                    TemplateExercise(name: "Incline DB Press", sets: 4, repMin: 10, repMax: 12, startWeightKg: 20, restSeconds: 120, jointSensitive: true, note: "3s eccentric every rep, RPE 9", muscleGroup: "Chest", alternatives: ["Machine Incline Press", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Cable Fly", sets: 3, repMin: 12, repMax: 15, startWeightKg: 15, restSeconds: 75, jointSensitive: true, note: "High-to-low path for lower chest, deep stretch, RPE 9", muscleGroup: "Chest", alternatives: ["Pec Deck", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Cable Lateral Raise", sets: 5, repMin: 12, repMax: 20, startWeightKg: 6, restSeconds: 60, jointSensitive: true, note: "Cable behind the back keeps tension at the bottom, RPE 9-10", muscleGroup: "Side Delts", alternatives: ["DB Lateral Raise", "Machine Lateral Raise"]),
                    TemplateExercise(name: "Overhead Cable Extension", sets: 3, repMin: 12, repMax: 15, startWeightKg: 22, restSeconds: 75, note: "Rope behind the head for long-head stretch bias", muscleGroup: "Triceps", alternatives: ["Skull Crusher", "Rope Pushdown", "Dips"]),
                    TemplateExercise(name: "Rope Pushdown", sets: 3, repMin: 12, repMax: 15, startWeightKg: 28, restSeconds: 60, note: "Split the rope wide at lockout, elbows pinned, RPE 10 last set", muscleGroup: "Triceps", alternatives: ["Dips", "Overhead Cable Extension", "Close-Grip Bench"])
                ]
            ),
            TemplateDay(
                code: "D", name: "Pull Volume", focus: "Back/rear delts/bis pump",
                colorHex: "8B5CF6", weekday: 6,
                exercises: [
                    TemplateExercise(name: "Neutral-Grip Pulldown", sets: 4, repMin: 10, repMax: 12, startWeightKg: 55, restSeconds: 120, note: "Neutral grip biases the lower lats, RPE 9", muscleGroup: "Back", alternatives: ["Pull-Up", "Lat Pulldown", "Assisted Pull-Up"]),
                    TemplateExercise(name: "Seated Cable Row", sets: 4, repMin: 10, repMax: 12, startWeightKg: 50, restSeconds: 120, note: "Wide grip, 1s squeeze for upper-back thickness", muscleGroup: "Back", alternatives: ["Machine Row", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "Face Pulls", sets: 4, repMin: 15, repMax: 20, startWeightKg: 20, restSeconds: 60, note: "Rope high on the stack, external rotation at peak", muscleGroup: "Rear Delts", alternatives: ["Reverse Pec Deck", "Band Pull-Apart", "Rear Delt Fly"]),
                    TemplateExercise(name: "Incline DB Curl", sets: 3, repMin: 10, repMax: 12, startWeightKg: 10, restSeconds: 75, note: "Full stretch position curl — arm hangs behind torso", muscleGroup: "Biceps", alternatives: ["Cable Curl", "DB Curl", "EZ Bar Curl"]),
                    TemplateExercise(name: "Hammer Curl", sets: 3, repMin: 10, repMax: 15, startWeightKg: 12, restSeconds: 60, note: "Cross-body path for a brachialis peak, RPE 10 last set", muscleGroup: "Biceps", alternatives: ["Rope Hammer Curl", "DB Curl", "EZ Bar Curl"])
                ]
            ),
            TemplateDay(
                code: "E", name: "Legs Volume", focus: "Quads/hams/glutes pump",
                colorHex: "DC2626", weekday: 7,
                exercises: [
                    TemplateExercise(name: "Leg Press", sets: 4, repMin: 12, repMax: 15, startWeightKg: 120, restSeconds: 120, note: "Feet low and close for quad bias, RPE 9", muscleGroup: "Quads", alternatives: ["Hack Squat", "Barbell Squat", "Goblet Squat"]),
                    TemplateExercise(name: "Seated Leg Curl", sets: 4, repMin: 10, repMax: 15, startWeightKg: 45, restSeconds: 90, note: "Point toes to bring the calves in, RPE 9", muscleGroup: "Hamstrings", alternatives: ["Lying Leg Curl", "Romanian Deadlift", "45° Back Extension"]),
                    TemplateExercise(name: "Leg Extension", sets: 3, repMin: 15, repMax: 20, startWeightKg: 45, restSeconds: 75, note: "1.5-rep style — full extension, half rep, full rep, RPE 10", muscleGroup: "Quads", alternatives: ["Sissy Squat", "Leg Press", "Hack Squat"]),
                    TemplateExercise(name: "Barbell Hip Thrust", sets: 3, repMin: 10, repMax: 12, startWeightKg: 80, restSeconds: 120, note: "Feet close together shifts emphasis onto glutes over quads", muscleGroup: "Glutes", alternatives: ["Machine Hip Thrust", "Glute Bridge", "Cable Pull-Through"]),
                    TemplateExercise(name: "Seated Calf Raise", sets: 4, repMin: 15, repMax: 20, startWeightKg: 45, restSeconds: 60, note: "Full stretch at bottom, no bounce out of it", muscleGroup: "Calves", alternatives: ["Standing Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise"])
                ]
            )
        ]
    )

    // ==================================================================
    // MARK: STRENGTH — BEGINNER (Full Body 3×, linear progression)
    // ==================================================================

    static let strBeginner = ProgramTemplate(
        id: "str_beg_fb3",
        name: "Linear Strength 3×",
        goal: .strength,
        tier: .beginner,
        daysPerWeek: 3,
        summary: "Classic linear progression: 3 full-body days around the big patterns at 5-8 reps. Add weight nearly every session — the fastest strength phase of your life.",
        days: [
            TemplateDay(
                code: "A", name: "Strength A", focus: "Squat pattern",
                colorHex: "2563EB", weekday: 2,
                exercises: [
                    TemplateExercise(name: "Goblet Squat", sets: 3, repMin: 6, repMax: 8, startWeightKg: 20, restSeconds: 180, note: "Add 2kg when 3×8 clean", muscleGroup: "Quads", alternatives: ["Leg Press", "Hack Squat"]),
                    TemplateExercise(name: "DB Bench Press", sets: 3, repMin: 6, repMax: 8, startWeightKg: 20, restSeconds: 180, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Machine Chest Press", "Barbell Bench", "Incline DB Press"]),
                    TemplateExercise(name: "Seated Cable Row", sets: 3, repMin: 6, repMax: 8, startWeightKg: 45, restSeconds: 150, muscleGroup: "Back", alternatives: ["Chest-Supported Row", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "Plank", sets: 3, repMin: 30, repMax: 60, startWeightKg: 0, restSeconds: 60, note: "Seconds", muscleGroup: "Core", alternatives: ["Dead Bug", "Cable Crunch", "Hanging Knee Raise"])
                ]
            ),
            TemplateDay(
                code: "B", name: "Strength B", focus: "Hinge pattern",
                colorHex: "059669", weekday: 4,
                exercises: [
                    TemplateExercise(name: "Romanian Deadlift", sets: 3, repMin: 6, repMax: 8, startWeightKg: 40, restSeconds: 180, note: "Hinge mastery first", muscleGroup: "Hamstrings", alternatives: ["Trap Bar Deadlift", "Seated Leg Curl", "Lying Leg Curl"]),
                    TemplateExercise(name: "Seated DB Shoulder Press", sets: 3, repMin: 6, repMax: 8, startWeightKg: 10, restSeconds: 150, jointSensitive: true, muscleGroup: "Shoulders", alternatives: ["Machine Shoulder Press", "Barbell OHP", "Arnold Press"]),
                    TemplateExercise(name: "Lat Pulldown", sets: 3, repMin: 6, repMax: 10, startWeightKg: 50, restSeconds: 150, muscleGroup: "Back", alternatives: ["Assisted Pull-Up", "Pull-Up", "Neutral-Grip Pulldown"]),
                    TemplateExercise(name: "Standing Calf Raise", sets: 3, repMin: 8, repMax: 12, startWeightKg: 50, restSeconds: 90, muscleGroup: "Calves", alternatives: ["Seated Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise"])
                ]
            ),
            TemplateDay(
                code: "C", name: "Strength C", focus: "Mixed",
                colorHex: "D97706", weekday: 7,
                exercises: [
                    TemplateExercise(name: "Leg Press", sets: 3, repMin: 6, repMax: 10, startWeightKg: 90, restSeconds: 180, muscleGroup: "Quads", alternatives: ["Goblet Squat", "Hack Squat", "Barbell Squat"]),
                    TemplateExercise(name: "Incline DB Press", sets: 3, repMin: 6, repMax: 8, startWeightKg: 16, restSeconds: 180, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Machine Incline Press", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "One-Arm DB Row", sets: 3, repMin: 6, repMax: 8, startWeightKg: 22, restSeconds: 150, note: "Per arm", muscleGroup: "Back", alternatives: ["Seated Cable Row", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "Face Pulls", sets: 2, repMin: 12, repMax: 15, startWeightKg: 15, restSeconds: 75, note: "Shoulder insurance", muscleGroup: "Rear Delts", alternatives: ["Band Pull-Apart", "Reverse Pec Deck", "Rear Delt Fly"])
                ]
            )
        ]
    )

    // ==================================================================
    // MARK: STRENGTH — INTERMEDIATE (Upper/Lower 4×)
    // ==================================================================

    static let strIntermediate = ProgramTemplate(
        id: "str_int_ul4",
        name: "Strength Builder 4×",
        goal: .strength,
        tier: .intermediate,
        daysPerWeek: 4,
        summary: "Weekly progression with heavy/volume split: two heavy days at 4-6 reps, two back-off days at 6-10. 180s rests on main lifts — strength is built between sets.",
        days: [
            TemplateDay(
                code: "A", name: "Upper Heavy", focus: "4-6 reps",
                colorHex: "2563EB", weekday: 2,
                exercises: [
                    TemplateExercise(name: "DB Bench Press", sets: 4, repMin: 4, repMax: 6, startWeightKg: 26, restSeconds: 210, jointSensitive: true, note: "RPE 8", muscleGroup: "Chest", alternatives: ["Barbell Bench", "Machine Chest Press", "Incline DB Press"]),
                    TemplateExercise(name: "Weighted Pull-Up", sets: 4, repMin: 4, repMax: 6, startWeightKg: 0, restSeconds: 210, muscleGroup: "Back", alternatives: ["Heavy Lat Pulldown", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "Seated DB Shoulder Press", sets: 3, repMin: 5, repMax: 8, startWeightKg: 16, restSeconds: 180, jointSensitive: true, muscleGroup: "Shoulders", alternatives: ["Machine Shoulder Press", "Barbell OHP", "Arnold Press"]),
                    TemplateExercise(name: "Chest-Supported Row", sets: 3, repMin: 6, repMax: 8, startWeightKg: 24, restSeconds: 150, muscleGroup: "Back", alternatives: ["T-Bar Row", "Lat Pulldown", "Pull-Up"])
                ]
            ),
            TemplateDay(
                code: "B", name: "Lower Heavy", focus: "4-6 reps",
                colorHex: "059669", weekday: 3,
                exercises: [
                    TemplateExercise(name: "Hack Squat", sets: 4, repMin: 4, repMax: 6, startWeightKg: 80, restSeconds: 240, note: "RPE 8", muscleGroup: "Quads", alternatives: ["Barbell Squat", "Leg Press"]),
                    TemplateExercise(name: "Romanian Deadlift", sets: 4, repMin: 5, repMax: 6, startWeightKg: 70, restSeconds: 240, muscleGroup: "Hamstrings", alternatives: ["Trap Bar Deadlift", "Seated Leg Curl", "Lying Leg Curl"]),
                    TemplateExercise(name: "Bulgarian Split Squat", sets: 3, repMin: 6, repMax: 8, startWeightKg: 14, restSeconds: 120, note: "Per leg", muscleGroup: "Quads", alternatives: ["Walking Lunge", "Leg Press", "Hack Squat"]),
                    TemplateExercise(name: "Standing Calf Raise", sets: 3, repMin: 6, repMax: 10, startWeightKg: 70, restSeconds: 90, muscleGroup: "Calves", alternatives: ["Seated Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise"])
                ]
            ),
            TemplateDay(
                code: "C", name: "Upper Volume", focus: "6-10 reps back-off",
                colorHex: "8B5CF6", weekday: 5,
                exercises: [
                    TemplateExercise(name: "Incline DB Press", sets: 3, repMin: 8, repMax: 10, startWeightKg: 18, restSeconds: 150, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Machine Incline Press", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Lat Pulldown", sets: 3, repMin: 8, repMax: 10, startWeightKg: 55, restSeconds: 120, muscleGroup: "Back", alternatives: ["Pull-Up", "Assisted Pull-Up", "Neutral-Grip Pulldown"]),
                    TemplateExercise(name: "Cable Lateral Raise", sets: 3, repMin: 10, repMax: 15, startWeightKg: 6, restSeconds: 75, jointSensitive: true, muscleGroup: "Side Delts", alternatives: ["DB Lateral Raise", "Machine Lateral Raise"]),
                    TemplateExercise(name: "EZ Bar Curl", sets: 3, repMin: 8, repMax: 10, startWeightKg: 22, restSeconds: 90, muscleGroup: "Biceps", alternatives: ["DB Curl", "Cable Curl", "Barbell Curl"]),
                    TemplateExercise(name: "Rope Pushdown", sets: 3, repMin: 8, repMax: 12, startWeightKg: 25, restSeconds: 90, muscleGroup: "Triceps", alternatives: ["Overhead Extension", "Overhead Cable Extension", "Dips"])
                ]
            ),
            TemplateDay(
                code: "D", name: "Lower Volume", focus: "8-12 reps back-off",
                colorHex: "DC2626", weekday: 6,
                exercises: [
                    TemplateExercise(name: "Leg Press", sets: 3, repMin: 8, repMax: 12, startWeightKg: 110, restSeconds: 150, muscleGroup: "Quads", alternatives: ["Hack Squat", "Barbell Squat", "Goblet Squat"]),
                    TemplateExercise(name: "Seated Leg Curl", sets: 3, repMin: 8, repMax: 12, startWeightKg: 45, restSeconds: 90, muscleGroup: "Hamstrings", alternatives: ["Lying Leg Curl", "Romanian Deadlift", "45° Back Extension"]),
                    TemplateExercise(name: "Barbell Hip Thrust", sets: 3, repMin: 8, repMax: 10, startWeightKg: 70, restSeconds: 120, muscleGroup: "Glutes", alternatives: ["Glute Bridge", "Machine Hip Thrust", "Cable Pull-Through"]),
                    TemplateExercise(name: "Cable Crunch", sets: 3, repMin: 10, repMax: 12, startWeightKg: 35, restSeconds: 75, muscleGroup: "Core", alternatives: ["Hanging Knee Raise", "Plank", "Dead Bug"])
                ]
            )
        ]
    )

    // ==================================================================
    // MARK: STRENGTH — ADVANCED
    // ==================================================================

    static let strAdvanced = ProgramTemplate(
        id: "str_adv_4",
        name: "Peak Strength 4×",
        goal: .strength,
        tier: .advanced,
        daysPerWeek: 4,
        summary: "Heavy specificity: top sets at 2-5 reps RPE 8-9 with back-off volume. For lifters chasing e1RM PRs who already own their technique.",
        days: [
            TemplateDay(
                code: "A", name: "Press Heavy", focus: "Top set + back-off",
                colorHex: "2563EB", weekday: 2,
                exercises: [
                    TemplateExercise(name: "DB Bench Press", sets: 5, repMin: 3, repMax: 5, startWeightKg: 32, restSeconds: 240, jointSensitive: true, note: "Neutral grip, top set RPE 9, back-offs -10%", muscleGroup: "Chest", alternatives: ["Barbell Bench", "Machine Chest Press", "Incline DB Press"]),
                    TemplateExercise(name: "Seated DB Shoulder Press", sets: 4, repMin: 4, repMax: 6, startWeightKg: 20, restSeconds: 210, jointSensitive: true, note: "Palms forward, full lockout each rep", muscleGroup: "Shoulders", alternatives: ["Machine Press", "Machine Shoulder Press", "Barbell OHP"]),
                    TemplateExercise(name: "Close-Grip Bench", sets: 3, repMin: 6, repMax: 8, startWeightKg: 45, restSeconds: 150, jointSensitive: true, note: "Hands just inside shoulder width, elbows tucked", muscleGroup: "Triceps", alternatives: ["Dips", "Rope Pushdown", "Overhead Cable Extension"]),
                    TemplateExercise(name: "Face Pulls", sets: 3, repMin: 15, repMax: 20, startWeightKg: 20, restSeconds: 60, note: "External rotation at peak — balances the pressing", muscleGroup: "Rear Delts", alternatives: ["Band Pull-Apart", "Reverse Pec Deck", "Rear Delt Fly"])
                ]
            ),
            TemplateDay(
                code: "B", name: "Squat Heavy", focus: "Top set + back-off",
                colorHex: "059669", weekday: 3,
                exercises: [
                    TemplateExercise(name: "Hack Squat", sets: 5, repMin: 3, repMax: 5, startWeightKg: 100, restSeconds: 300, note: "2s pause at depth on the top set, RPE 9", muscleGroup: "Quads", alternatives: ["Barbell Squat", "Leg Press", "Goblet Squat"]),
                    TemplateExercise(name: "Romanian Deadlift", sets: 4, repMin: 5, repMax: 6, startWeightKg: 80, restSeconds: 240, note: "Slow 3s eccentric, stop at mid-shin", muscleGroup: "Hamstrings", alternatives: ["Deficit RDL", "Seated Leg Curl", "Lying Leg Curl"]),
                    TemplateExercise(name: "Leg Press", sets: 3, repMin: 8, repMax: 10, startWeightKg: 130, restSeconds: 150, note: "Feet low and close for quad bias — back-off volume", muscleGroup: "Quads", alternatives: ["Split Squat", "Hack Squat", "Barbell Squat"]),
                    TemplateExercise(name: "Standing Calf Raise", sets: 4, repMin: 8, repMax: 10, startWeightKg: 90, restSeconds: 90, note: "Full stretch at bottom, 1s pause at top", muscleGroup: "Calves", alternatives: ["Seated Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise"])
                ]
            ),
            TemplateDay(
                code: "C", name: "Pull Heavy", focus: "Vertical + horizontal",
                colorHex: "8B5CF6", weekday: 5,
                exercises: [
                    TemplateExercise(name: "Weighted Pull-Up", sets: 5, repMin: 3, repMax: 5, startWeightKg: 10, restSeconds: 240, note: "Wide pronated grip, top set RPE 9", muscleGroup: "Back", alternatives: ["Heavy Pulldown", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "Chest-Supported Row", sets: 4, repMin: 5, repMax: 6, startWeightKg: 30, restSeconds: 180, note: "Wide overhand grip, 1s squeeze at the top", muscleGroup: "Back", alternatives: ["T-Bar Row", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "One-Arm DB Row", sets: 3, repMin: 6, repMax: 8, startWeightKg: 30, restSeconds: 120, note: "Full stretch at bottom — per arm", muscleGroup: "Back", alternatives: ["Seal Row", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "EZ Bar Curl", sets: 3, repMin: 6, repMax: 8, startWeightKg: 30, restSeconds: 90, note: "Wide grip biases the short head", muscleGroup: "Biceps", alternatives: ["Barbell Curl", "DB Curl", "Cable Curl"])
                ]
            ),
            TemplateDay(
                code: "D", name: "Full Body Speed", focus: "Technique + volume",
                colorHex: "DC2626", weekday: 6,
                exercises: [
                    TemplateExercise(name: "Leg Press", sets: 4, repMin: 6, repMax: 8, startWeightKg: 120, restSeconds: 150, note: "Explosive concentric, controlled 2s eccentric", muscleGroup: "Quads", alternatives: ["Hack Squat", "Barbell Squat", "Goblet Squat"]),
                    TemplateExercise(name: "Incline DB Press", sets: 4, repMin: 6, repMax: 8, startWeightKg: 22, restSeconds: 150, jointSensitive: true, note: "Neutral grip, drive through the top half fast", muscleGroup: "Chest", alternatives: ["Machine Incline", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Seated Cable Row", sets: 3, repMin: 8, repMax: 10, startWeightKg: 55, restSeconds: 120, note: "Wide grip for upper-back width", muscleGroup: "Back", alternatives: ["Machine Row", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "Barbell Hip Thrust", sets: 3, repMin: 6, repMax: 8, startWeightKg: 90, restSeconds: 150, note: "Feet close together for glute bias", muscleGroup: "Glutes", alternatives: ["Machine Hip Thrust", "Glute Bridge", "Cable Pull-Through"]),
                    TemplateExercise(name: "Cable Crunch", sets: 3, repMin: 10, repMax: 12, startWeightKg: 40, restSeconds: 60, note: "Round the spine, don't just hinge at the hips", muscleGroup: "Core", alternatives: ["Ab Wheel", "Plank", "Dead Bug"])
                ]
            )
        ]
    )

    // ==================================================================
    // MARK: FAT LOSS — BEGINNER (Full Body 2×)
    // Short 75s rests, machine/DB bias, higher reps for metabolic effect
    // ==================================================================

    static let fatLossBeginner = ProgramTemplate(
        id: "fat_beg_fb2",
        name: "Metabolic Foundations 2×",
        goal: .fatLoss,
        tier: .beginner,
        daysPerWeek: 2,
        summary: "Two full-body sessions on machines and dumbbells with short 75s rests to keep heart rate up. Preserve muscle while the calorie deficit does the fat-loss work.",
        days: [
            TemplateDay(
                code: "A", name: "Metabolic Foundation A", focus: "Full body circuit",
                colorHex: "2563EB", weekday: 2,
                exercises: [
                    TemplateExercise(name: "Leg Press", sets: 3, repMin: 12, repMax: 15, startWeightKg: 50, restSeconds: 75, muscleGroup: "Quads", alternatives: ["Goblet Squat", "Hack Squat", "Barbell Squat"]),
                    TemplateExercise(name: "Machine Chest Press", sets: 3, repMin: 10, repMax: 12, startWeightKg: 25, restSeconds: 75, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Push-Up", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Lat Pulldown", sets: 3, repMin: 10, repMax: 12, startWeightKg: 35, restSeconds: 75, muscleGroup: "Back", alternatives: ["Assisted Pull-Up", "Pull-Up", "Neutral-Grip Pulldown"]),
                    TemplateExercise(name: "DB Lateral Raise", sets: 2, repMin: 12, repMax: 15, startWeightKg: 4, restSeconds: 60, jointSensitive: true, muscleGroup: "Side Delts", alternatives: ["Cable Lateral Raise", "Machine Lateral Raise"]),
                    TemplateExercise(name: "Plank", sets: 2, repMin: 30, repMax: 45, startWeightKg: 0, restSeconds: 60, note: "Seconds", muscleGroup: "Core", alternatives: ["Dead Bug", "Cable Crunch", "Hanging Knee Raise"]),
                    TemplateExercise(name: "Standing Calf Raise", sets: 2, repMin: 12, repMax: 15, startWeightKg: 30, restSeconds: 60, muscleGroup: "Calves", alternatives: ["Seated Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise"])
                ]
            ),
            TemplateDay(
                code: "B", name: "Metabolic Foundation B", focus: "Full body circuit 2",
                colorHex: "059669", weekday: 5,
                exercises: [
                    TemplateExercise(name: "Romanian Deadlift", sets: 3, repMin: 10, repMax: 12, startWeightKg: 30, restSeconds: 90, muscleGroup: "Hamstrings", alternatives: ["Glute Bridge", "Seated Leg Curl", "Lying Leg Curl"]),
                    TemplateExercise(name: "Seated Cable Row", sets: 3, repMin: 10, repMax: 12, startWeightKg: 32, restSeconds: 75, muscleGroup: "Back", alternatives: ["Machine Row", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "Incline DB Press", sets: 2, repMin: 10, repMax: 12, startWeightKg: 10, restSeconds: 75, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Machine Chest Press", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Walking Lunge", sets: 2, repMin: 10, repMax: 12, startWeightKg: 8, restSeconds: 75, note: "Per leg", muscleGroup: "Quads", alternatives: ["Split Squat", "Leg Press", "Hack Squat"]),
                    TemplateExercise(name: "Hanging Knee Raise", sets: 2, repMin: 10, repMax: 15, startWeightKg: 0, restSeconds: 60, muscleGroup: "Core", alternatives: ["Cable Crunch", "Plank", "Dead Bug"]),
                    TemplateExercise(name: "Hammer Curl", sets: 2, repMin: 10, repMax: 12, startWeightKg: 8, restSeconds: 60, muscleGroup: "Biceps", alternatives: ["DB Curl", "EZ Bar Curl", "Cable Curl"])
                ]
            )
        ]
    )

    // ==================================================================
    // MARK: FAT LOSS — INTERMEDIATE (Full Body 3×)
    // ~75s rests · muscle-preserving resistance work · pairs with deficit
    // ==================================================================

    static let fatLossStandard = ProgramTemplate(
        id: "fat_fullbody_3",
        name: "Metabolic Full Body 3×",
        goal: .fatLoss,
        tier: .intermediate,
        daysPerWeek: 3,
        summary: "Muscle-preserving resistance work with short 75s rests for metabolic effect. Pair with the calorie deficit — training defends muscle, the deficit burns fat.",
        days: [
            TemplateDay(
                code: "A", name: "Metabolic A", focus: "Full body circuit-ish",
                colorHex: "2563EB", weekday: 2,
                exercises: [
                    TemplateExercise(name: "Goblet Squat", sets: 3, repMin: 12, repMax: 15, startWeightKg: 16, restSeconds: 75, muscleGroup: "Quads", alternatives: ["Leg Press", "Hack Squat", "Barbell Squat"]),
                    TemplateExercise(name: "DB Bench Press", sets: 3, repMin: 10, repMax: 12, startWeightKg: 18, restSeconds: 75, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Push-Up", "Barbell Bench", "Machine Chest Press"]),
                    TemplateExercise(name: "Seated Cable Row", sets: 3, repMin: 10, repMax: 12, startWeightKg: 40, restSeconds: 75, muscleGroup: "Back", alternatives: ["Machine Row", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "DB Lateral Raise", sets: 2, repMin: 12, repMax: 15, startWeightKg: 6, restSeconds: 60, jointSensitive: true, muscleGroup: "Side Delts", alternatives: ["Cable Lateral Raise", "Machine Lateral Raise"]),
                    TemplateExercise(name: "Plank", sets: 3, repMin: 30, repMax: 60, startWeightKg: 0, restSeconds: 60, note: "Seconds", muscleGroup: "Core", alternatives: ["Dead Bug", "Cable Crunch", "Hanging Knee Raise"])
                ]
            ),
            TemplateDay(
                code: "B", name: "Metabolic B", focus: "Posterior + pull",
                colorHex: "059669", weekday: 4,
                exercises: [
                    TemplateExercise(name: "Romanian Deadlift", sets: 3, repMin: 10, repMax: 12, startWeightKg: 40, restSeconds: 90, muscleGroup: "Hamstrings", alternatives: ["45° Back Extension", "Seated Leg Curl", "Lying Leg Curl"]),
                    TemplateExercise(name: "Lat Pulldown", sets: 3, repMin: 10, repMax: 12, startWeightKg: 45, restSeconds: 75, muscleGroup: "Back", alternatives: ["Assisted Pull-Up", "Pull-Up", "Neutral-Grip Pulldown"]),
                    TemplateExercise(name: "Incline DB Press", sets: 3, repMin: 10, repMax: 12, startWeightKg: 14, restSeconds: 75, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Machine Press", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Walking Lunge", sets: 2, repMin: 10, repMax: 12, startWeightKg: 10, restSeconds: 75, note: "Per leg", muscleGroup: "Quads", alternatives: ["Split Squat", "Leg Press", "Hack Squat"]),
                    TemplateExercise(name: "Hanging Knee Raise", sets: 3, repMin: 10, repMax: 15, startWeightKg: 0, restSeconds: 60, muscleGroup: "Core", alternatives: ["Cable Crunch", "Plank", "Dead Bug"]),
                    TemplateExercise(name: "EZ Bar Curl", sets: 2, repMin: 12, repMax: 15, startWeightKg: 15, restSeconds: 60, muscleGroup: "Biceps", alternatives: ["DB Curl", "Cable Curl", "Barbell Curl"])
                ]
            ),
            TemplateDay(
                code: "C", name: "Metabolic C", focus: "Full body finisher",
                colorHex: "D97706", weekday: 6,
                exercises: [
                    TemplateExercise(name: "Leg Press", sets: 3, repMin: 12, repMax: 15, startWeightKg: 80, restSeconds: 75, muscleGroup: "Quads", alternatives: ["Goblet Squat", "Hack Squat", "Barbell Squat"]),
                    TemplateExercise(name: "Chest-Supported Row", sets: 3, repMin: 10, repMax: 12, startWeightKg: 18, restSeconds: 75, muscleGroup: "Back", alternatives: ["One-Arm DB Row", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "Machine Chest Press", sets: 3, repMin: 10, repMax: 12, startWeightKg: 30, restSeconds: 75, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Push-Up", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Face Pulls", sets: 2, repMin: 15, repMax: 20, startWeightKg: 15, restSeconds: 60, muscleGroup: "Rear Delts", alternatives: ["Reverse Pec Deck", "Band Pull-Apart", "Rear Delt Fly"]),
                    TemplateExercise(name: "Standing Calf Raise", sets: 2, repMin: 12, repMax: 15, startWeightKg: 40, restSeconds: 60, muscleGroup: "Calves", alternatives: ["Seated Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise"])
                ]
            )
        ]
    )

    // ==================================================================
    // MARK: FAT LOSS — ADVANCED (Upper/Lower 4×, metabolic finishers)
    // 60-75s rests · moderate loads · finisher each session
    // ==================================================================

    static let fatLossAdvanced = ProgramTemplate(
        id: "fat_adv_ul4",
        name: "Shred Upper/Lower 4×",
        goal: .fatLoss,
        tier: .advanced,
        daysPerWeek: 4,
        summary: "Four days of upper/lower work at moderate loads with short 60-75s rests and a metabolic finisher each session. Built for lifters who want to preserve strength while running a steeper deficit.",
        days: [
            TemplateDay(
                code: "A", name: "Upper 1", focus: "Push emphasis + finisher",
                colorHex: "2563EB", weekday: 2,
                exercises: [
                    TemplateExercise(name: "DB Bench Press", sets: 4, repMin: 10, repMax: 12, startWeightKg: 18, restSeconds: 75, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Machine Chest Press", "Barbell Bench", "Incline DB Press"]),
                    TemplateExercise(name: "Seated Cable Row", sets: 3, repMin: 10, repMax: 12, startWeightKg: 38, restSeconds: 75, muscleGroup: "Back", alternatives: ["Chest-Supported Row", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "Seated DB Shoulder Press", sets: 3, repMin: 10, repMax: 12, startWeightKg: 10, restSeconds: 60, jointSensitive: true, muscleGroup: "Shoulders", alternatives: ["Machine Shoulder Press", "Barbell OHP", "Arnold Press"]),
                    TemplateExercise(name: "Rope Pushdown", sets: 2, repMin: 12, repMax: 15, startWeightKg: 18, restSeconds: 60, muscleGroup: "Triceps", alternatives: ["Dips", "Overhead Cable Extension", "Close-Grip Bench"]),
                    TemplateExercise(name: "Mountain Climbers", sets: 3, repMin: 20, repMax: 30, startWeightKg: 0, restSeconds: 45, note: "Finisher — steady pace", muscleGroup: "Core", alternatives: ["Plank", "Dead Bug", "Cable Crunch"])
                ]
            ),
            TemplateDay(
                code: "B", name: "Lower 1", focus: "Quad emphasis + finisher",
                colorHex: "059669", weekday: 3,
                exercises: [
                    TemplateExercise(name: "Leg Press", sets: 4, repMin: 12, repMax: 15, startWeightKg: 80, restSeconds: 75, muscleGroup: "Quads", alternatives: ["Hack Squat", "Barbell Squat", "Goblet Squat"]),
                    TemplateExercise(name: "Bulgarian Split Squat", sets: 3, repMin: 10, repMax: 12, startWeightKg: 10, restSeconds: 60, note: "Per leg", muscleGroup: "Quads", alternatives: ["Walking Lunge", "Leg Press", "Hack Squat"]),
                    TemplateExercise(name: "Seated Leg Curl", sets: 3, repMin: 12, repMax: 15, startWeightKg: 32, restSeconds: 60, muscleGroup: "Hamstrings", alternatives: ["Lying Leg Curl", "Romanian Deadlift", "45° Back Extension"]),
                    TemplateExercise(name: "Standing Calf Raise", sets: 3, repMin: 12, repMax: 15, startWeightKg: 50, restSeconds: 60, muscleGroup: "Calves", alternatives: ["Seated Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise"]),
                    TemplateExercise(name: "Jump Rope (or step-ups)", sets: 3, repMin: 30, repMax: 45, startWeightKg: 0, restSeconds: 45, note: "Finisher — seconds", muscleGroup: "Cardio", alternatives: ["Step-Up", "Jump Rope", "Battle Rope"])
                ]
            ),
            TemplateDay(
                code: "C", name: "Upper 2", focus: "Pull emphasis + finisher",
                colorHex: "8B5CF6", weekday: 5,
                exercises: [
                    TemplateExercise(name: "Lat Pulldown", sets: 4, repMin: 10, repMax: 12, startWeightKg: 42, restSeconds: 75, muscleGroup: "Back", alternatives: ["Assisted Pull-Up", "Pull-Up", "Neutral-Grip Pulldown"]),
                    TemplateExercise(name: "Incline DB Press", sets: 3, repMin: 10, repMax: 12, startWeightKg: 14, restSeconds: 75, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Machine Incline Press", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Face Pulls", sets: 3, repMin: 15, repMax: 20, startWeightKg: 16, restSeconds: 60, muscleGroup: "Rear Delts", alternatives: ["Reverse Pec Deck", "Band Pull-Apart", "Rear Delt Fly"]),
                    TemplateExercise(name: "EZ Bar Curl", sets: 2, repMin: 12, repMax: 15, startWeightKg: 15, restSeconds: 60, muscleGroup: "Biceps", alternatives: ["DB Curl", "Cable Curl", "Barbell Curl"]),
                    TemplateExercise(name: "Battle Rope (or fast punches)", sets: 3, repMin: 20, repMax: 30, startWeightKg: 0, restSeconds: 45, note: "Finisher — seconds", muscleGroup: "Cardio", alternatives: ["Jumping Jacks", "Jump Rope", "Battle Rope"])
                ]
            ),
            TemplateDay(
                code: "D", name: "Lower 2", focus: "Posterior emphasis + finisher",
                colorHex: "DC2626", weekday: 6,
                exercises: [
                    TemplateExercise(name: "Romanian Deadlift", sets: 4, repMin: 10, repMax: 12, startWeightKg: 45, restSeconds: 90, muscleGroup: "Hamstrings", alternatives: ["45° Back Extension", "Seated Leg Curl", "Lying Leg Curl"]),
                    TemplateExercise(name: "Goblet Squat", sets: 3, repMin: 12, repMax: 15, startWeightKg: 18, restSeconds: 75, muscleGroup: "Quads", alternatives: ["Leg Press", "Hack Squat", "Barbell Squat"]),
                    TemplateExercise(name: "Glute Bridge", sets: 3, repMin: 15, repMax: 20, startWeightKg: 10, restSeconds: 60, muscleGroup: "Glutes", alternatives: ["Barbell Hip Thrust", "Machine Hip Thrust", "Cable Pull-Through"]),
                    TemplateExercise(name: "Hanging Knee Raise", sets: 3, repMin: 10, repMax: 15, startWeightKg: 0, restSeconds: 60, muscleGroup: "Core", alternatives: ["Cable Crunch", "Plank", "Dead Bug"]),
                    TemplateExercise(name: "Kettlebell Swing (or fast squats)", sets: 3, repMin: 15, repMax: 20, startWeightKg: 12, restSeconds: 45, note: "Finisher", muscleGroup: "Cardio", alternatives: ["Bodyweight Squat", "Jump Rope", "Battle Rope"])
                ]
            )
        ]
    )

    // ==================================================================
    // MARK: STAY FIT — BEGINNER (Full Body 2×)
    // Minimal effective dose · sustainable for busy weeks
    // ==================================================================

    static let stayFitStandard = ProgramTemplate(
        id: "fit_fullbody_2",
        name: "Balanced 2-3×",
        goal: .stayFit,
        tier: .beginner,
        daysPerWeek: 2,
        summary: "Two true full-body sessions — each trains ONE primary lower-body pattern (never squat and a heavy hinge stacked the same day), plus push, pull, delts, and core. Sustainable for busy weeks — consistency beats intensity for staying fit.",
        days: [
            TemplateDay(
                code: "A", name: "Balance A", focus: "Squat-dominant full body",
                colorHex: "2563EB", weekday: 2,
                exercises: [
                    TemplateExercise(name: "Goblet Squat", sets: 3, repMin: 10, repMax: 12, startWeightKg: 12, restSeconds: 90, muscleGroup: "Quads", alternatives: ["Leg Press", "Hack Squat", "Barbell Squat"]),
                    TemplateExercise(name: "Machine Chest Press", sets: 3, repMin: 10, repMax: 12, startWeightKg: 25, restSeconds: 90, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Push-Up", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Seated Cable Row", sets: 3, repMin: 10, repMax: 12, startWeightKg: 30, restSeconds: 90, muscleGroup: "Back", alternatives: ["Chest-Supported Row", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "Plank", sets: 2, repMin: 30, repMax: 45, startWeightKg: 0, restSeconds: 60, note: "Seconds", muscleGroup: "Core", alternatives: ["Dead Bug", "Cable Crunch", "Hanging Knee Raise"]),
                    TemplateExercise(name: "DB Lateral Raise", sets: 2, repMin: 12, repMax: 15, startWeightKg: 4, restSeconds: 60, jointSensitive: true, muscleGroup: "Side Delts", alternatives: ["Cable Lateral Raise", "Machine Lateral Raise"]),
                    TemplateExercise(name: "Standing Calf Raise", sets: 2, repMin: 12, repMax: 15, startWeightKg: 25, restSeconds: 60, muscleGroup: "Calves", alternatives: ["Seated Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise"])
                ]
            ),
            TemplateDay(
                code: "B", name: "Balance B", focus: "Hinge-dominant full body",
                colorHex: "059669", weekday: 5,
                exercises: [
                    TemplateExercise(name: "Romanian Deadlift", sets: 3, repMin: 10, repMax: 12, startWeightKg: 25, restSeconds: 90, muscleGroup: "Hamstrings", alternatives: ["Glute Bridge", "Seated Leg Curl", "Lying Leg Curl"]),
                    TemplateExercise(name: "Incline DB Press", sets: 3, repMin: 10, repMax: 12, startWeightKg: 10, restSeconds: 90, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Machine Incline Press", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Lat Pulldown", sets: 3, repMin: 10, repMax: 12, startWeightKg: 35, restSeconds: 90, muscleGroup: "Back", alternatives: ["Assisted Pull-Up", "Pull-Up", "Neutral-Grip Pulldown"]),
                    TemplateExercise(name: "Dead Bug", sets: 2, repMin: 10, repMax: 12, startWeightKg: 0, restSeconds: 60, note: "Per side", muscleGroup: "Core", alternatives: ["Plank", "Cable Crunch", "Hanging Knee Raise"]),
                    TemplateExercise(name: "Face Pulls", sets: 2, repMin: 15, repMax: 20, startWeightKg: 12, restSeconds: 60, muscleGroup: "Rear Delts", alternatives: ["Band Pull-Apart", "Reverse Pec Deck", "Rear Delt Fly"]),
                    TemplateExercise(name: "Hammer Curl", sets: 2, repMin: 10, repMax: 12, startWeightKg: 6, restSeconds: 60, muscleGroup: "Biceps", alternatives: ["DB Curl", "EZ Bar Curl", "Cable Curl"])
                ]
            )
        ]
    )

    // ==================================================================
    // MARK: STAY FIT — INTERMEDIATE (Full Body 3×)
    // Moderate volume · RPE 6-8 · every pattern each session
    // ==================================================================

    static let stayFitIntermediate = ProgramTemplate(
        id: "fit_fb3",
        name: "Balanced 3×",
        goal: .stayFit,
        tier: .intermediate,
        daysPerWeek: 3,
        summary: "Three full-body days, each with ONE primary lower-body pattern — squat day, hinge day, unilateral day — never squat and a heavy hinge stacked together. Moderate volume at RPE 6-8, with arms and calves rotated in across the week so nothing gets skipped; frequency, not exercise count, is the point of full-body at 3×/week.",
        days: [
            TemplateDay(
                code: "A", name: "Balance A", focus: "Squat-dominant full body",
                colorHex: "2563EB", weekday: 2,
                exercises: [
                    TemplateExercise(name: "Goblet Squat", sets: 3, repMin: 10, repMax: 12, startWeightKg: 16, restSeconds: 90, muscleGroup: "Quads", alternatives: ["Leg Press", "Hack Squat", "Barbell Squat"]),
                    TemplateExercise(name: "Machine Chest Press", sets: 3, repMin: 10, repMax: 12, startWeightKg: 28, restSeconds: 90, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Push-Up", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Seated Cable Row", sets: 3, repMin: 10, repMax: 12, startWeightKg: 32, restSeconds: 90, muscleGroup: "Back", alternatives: ["Chest-Supported Row", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "Plank", sets: 2, repMin: 30, repMax: 45, startWeightKg: 0, restSeconds: 60, note: "Seconds", muscleGroup: "Core", alternatives: ["Dead Bug", "Cable Crunch", "Hanging Knee Raise"]),
                    TemplateExercise(name: "DB Lateral Raise", sets: 2, repMin: 12, repMax: 15, startWeightKg: 5, restSeconds: 60, jointSensitive: true, muscleGroup: "Side Delts", alternatives: ["Cable Lateral Raise", "Machine Lateral Raise"]),
                    TemplateExercise(name: "Standing Calf Raise", sets: 2, repMin: 12, repMax: 15, startWeightKg: 30, restSeconds: 60, muscleGroup: "Calves", alternatives: ["Seated Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise"])
                ]
            ),
            TemplateDay(
                code: "B", name: "Balance B", focus: "Hinge-dominant full body",
                colorHex: "059669", weekday: 4,
                exercises: [
                    TemplateExercise(name: "Romanian Deadlift", sets: 3, repMin: 10, repMax: 12, startWeightKg: 30, restSeconds: 90, muscleGroup: "Hamstrings", alternatives: ["Hip Thrust", "Seated Leg Curl", "Lying Leg Curl"]),
                    TemplateExercise(name: "Incline DB Press", sets: 3, repMin: 10, repMax: 12, startWeightKg: 12, restSeconds: 90, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Machine Incline Press", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Lat Pulldown", sets: 3, repMin: 10, repMax: 12, startWeightKg: 40, restSeconds: 90, muscleGroup: "Back", alternatives: ["Assisted Pull-Up", "Pull-Up", "Neutral-Grip Pulldown"]),
                    TemplateExercise(name: "Hanging Knee Raise", sets: 2, repMin: 10, repMax: 15, startWeightKg: 0, restSeconds: 60, muscleGroup: "Core", alternatives: ["Cable Crunch", "Plank", "Dead Bug"]),
                    TemplateExercise(name: "Face Pulls", sets: 2, repMin: 15, repMax: 20, startWeightKg: 14, restSeconds: 60, muscleGroup: "Rear Delts", alternatives: ["Band Pull-Apart", "Reverse Pec Deck", "Rear Delt Fly"]),
                    TemplateExercise(name: "Hammer Curl", sets: 2, repMin: 10, repMax: 12, startWeightKg: 8, restSeconds: 60, muscleGroup: "Biceps", alternatives: ["DB Curl", "EZ Bar Curl", "Cable Curl"])
                ]
            ),
            TemplateDay(
                code: "C", name: "Balance C", focus: "Unilateral + posterior full body",
                colorHex: "D97706", weekday: 6,
                exercises: [
                    TemplateExercise(name: "Bulgarian Split Squat", sets: 3, repMin: 10, repMax: 12, startWeightKg: 8, restSeconds: 90, note: "Per leg", muscleGroup: "Quads", alternatives: ["Walking Lunge", "Leg Press", "Hack Squat"]),
                    TemplateExercise(name: "Seated DB Shoulder Press", sets: 3, repMin: 10, repMax: 12, startWeightKg: 12, restSeconds: 90, jointSensitive: true, muscleGroup: "Shoulders", alternatives: ["Machine Shoulder Press", "Barbell OHP", "Arnold Press"]),
                    TemplateExercise(name: "One-Arm DB Row", sets: 3, repMin: 10, repMax: 12, startWeightKg: 16, restSeconds: 90, note: "Per arm", muscleGroup: "Back", alternatives: ["Seated Cable Row", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "Cable Crunch", sets: 2, repMin: 12, repMax: 15, startWeightKg: 25, restSeconds: 60, muscleGroup: "Core", alternatives: ["Hanging Knee Raise", "Plank", "Dead Bug"]),
                    TemplateExercise(name: "Cable Lateral Raise", sets: 2, repMin: 12, repMax: 15, startWeightKg: 6, restSeconds: 60, jointSensitive: true, muscleGroup: "Side Delts", alternatives: ["DB Lateral Raise", "Machine Lateral Raise"]),
                    TemplateExercise(name: "Rope Pushdown", sets: 2, repMin: 12, repMax: 15, startWeightKg: 15, restSeconds: 60, muscleGroup: "Triceps", alternatives: ["Overhead Cable Extension", "Dips", "Close-Grip Bench"])
                ]
            )
        ]
    )

    // ==================================================================
    // MARK: STAY FIT — ADVANCED (Upper/Lower 4×)
    // Structured split, RPE 7-8, enough volume to maintain without hypertrophy-level fatigue
    // ==================================================================

    static let stayFitAdvanced = ProgramTemplate(
        id: "fit_ul4",
        name: "Balanced Upper/Lower 4×",
        goal: .stayFit,
        tier: .advanced,
        daysPerWeek: 4,
        summary: "For the experienced lifter who wants a structured split without hypertrophy-level fatigue. Two upper, two lower, RPE 7-8, enough volume to maintain everything you've built.",
        days: [
            TemplateDay(
                code: "A", name: "Upper 1", focus: "Push/pull",
                colorHex: "2563EB", weekday: 2,
                exercises: [
                    TemplateExercise(name: "DB Bench Press", sets: 3, repMin: 8, repMax: 10, startWeightKg: 20, restSeconds: 100, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Machine Chest Press", "Barbell Bench", "Incline DB Press"]),
                    TemplateExercise(name: "Chest-Supported Row", sets: 3, repMin: 8, repMax: 10, startWeightKg: 18, restSeconds: 100, muscleGroup: "Back", alternatives: ["Seated Cable Row", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "Seated DB Shoulder Press", sets: 2, repMin: 10, repMax: 12, startWeightKg: 12, restSeconds: 90, jointSensitive: true, muscleGroup: "Shoulders", alternatives: ["Machine Shoulder Press", "Barbell OHP", "Arnold Press"]),
                    TemplateExercise(name: "EZ Bar Curl", sets: 2, repMin: 10, repMax: 12, startWeightKg: 18, restSeconds: 75, muscleGroup: "Biceps", alternatives: ["DB Curl", "Cable Curl", "Barbell Curl"])
                ]
            ),
            TemplateDay(
                code: "B", name: "Lower 1", focus: "Quad emphasis",
                colorHex: "059669", weekday: 3,
                exercises: [
                    TemplateExercise(name: "Leg Press", sets: 3, repMin: 10, repMax: 12, startWeightKg: 80, restSeconds: 100, muscleGroup: "Quads", alternatives: ["Hack Squat", "Barbell Squat", "Goblet Squat"]),
                    TemplateExercise(name: "Seated Leg Curl", sets: 3, repMin: 10, repMax: 12, startWeightKg: 35, restSeconds: 90, muscleGroup: "Hamstrings", alternatives: ["Lying Leg Curl", "Romanian Deadlift", "45° Back Extension"]),
                    TemplateExercise(name: "Standing Calf Raise", sets: 3, repMin: 10, repMax: 15, startWeightKg: 55, restSeconds: 75, muscleGroup: "Calves", alternatives: ["Seated Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise"]),
                    TemplateExercise(name: "Cable Crunch", sets: 2, repMin: 12, repMax: 15, startWeightKg: 30, restSeconds: 60, muscleGroup: "Core", alternatives: ["Hanging Knee Raise", "Plank", "Dead Bug"])
                ]
            ),
            TemplateDay(
                code: "C", name: "Upper 2", focus: "Vertical push/pull",
                colorHex: "8B5CF6", weekday: 5,
                exercises: [
                    TemplateExercise(name: "Lat Pulldown", sets: 3, repMin: 10, repMax: 12, startWeightKg: 45, restSeconds: 100, muscleGroup: "Back", alternatives: ["Assisted Pull-Up", "Pull-Up", "Neutral-Grip Pulldown"]),
                    TemplateExercise(name: "Incline DB Press", sets: 3, repMin: 10, repMax: 12, startWeightKg: 14, restSeconds: 100, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Machine Incline Press", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Cable Lateral Raise", sets: 2, repMin: 12, repMax: 15, startWeightKg: 6, restSeconds: 60, jointSensitive: true, muscleGroup: "Side Delts", alternatives: ["DB Lateral Raise", "Machine Lateral Raise"]),
                    TemplateExercise(name: "Rope Pushdown", sets: 2, repMin: 12, repMax: 15, startWeightKg: 20, restSeconds: 75, muscleGroup: "Triceps", alternatives: ["Overhead Cable Extension", "Dips", "Close-Grip Bench"])
                ]
            ),
            TemplateDay(
                code: "D", name: "Lower 2", focus: "Posterior emphasis",
                colorHex: "DC2626", weekday: 6,
                exercises: [
                    TemplateExercise(name: "Romanian Deadlift", sets: 3, repMin: 8, repMax: 10, startWeightKg: 40, restSeconds: 120, muscleGroup: "Hamstrings", alternatives: ["45° Back Extension", "Seated Leg Curl", "Lying Leg Curl"]),
                    TemplateExercise(name: "Bulgarian Split Squat", sets: 3, repMin: 8, repMax: 10, startWeightKg: 10, restSeconds: 90, note: "Per leg", muscleGroup: "Quads", alternatives: ["Walking Lunge", "Leg Press", "Hack Squat"]),
                    TemplateExercise(name: "Barbell Hip Thrust", sets: 3, repMin: 10, repMax: 12, startWeightKg: 50, restSeconds: 100, muscleGroup: "Glutes", alternatives: ["Glute Bridge", "Machine Hip Thrust", "Cable Pull-Through"]),
                    TemplateExercise(name: "Hanging Knee Raise", sets: 2, repMin: 10, repMax: 15, startWeightKg: 0, restSeconds: 60, muscleGroup: "Core", alternatives: ["Cable Crunch", "Plank", "Dead Bug"])
                ]
            )
        ]
    )

    // ==================================================================
    // MARK: ENDURANCE — BEGINNER (Circuit 2×)
    // ==================================================================

    static let enduranceStandard = ProgramTemplate(
        id: "end_circuit_2",
        name: "Endurance Circuit 2×",
        goal: .endurance,
        tier: .beginner,
        daysPerWeek: 2,
        summary: "Higher-rep resistance circuits (15-20 reps, 45-60s rests) to support your cardio base with muscular endurance and injury resilience.",
        days: [
            TemplateDay(
                code: "A", name: "Circuit A", focus: "Lower + core endurance",
                colorHex: "2563EB", weekday: 3,
                exercises: [
                    TemplateExercise(name: "Goblet Squat", sets: 3, repMin: 15, repMax: 20, startWeightKg: 10, restSeconds: 60, muscleGroup: "Quads", alternatives: ["Bodyweight Squat", "Leg Press", "Hack Squat"]),
                    TemplateExercise(name: "Walking Lunge", sets: 3, repMin: 12, repMax: 15, startWeightKg: 6, restSeconds: 60, note: "Per leg", muscleGroup: "Quads", alternatives: ["Step-Up", "Leg Press", "Hack Squat"]),
                    TemplateExercise(name: "Glute Bridge", sets: 3, repMin: 15, repMax: 20, startWeightKg: 0, restSeconds: 45, muscleGroup: "Glutes", alternatives: ["Hip Thrust", "Barbell Hip Thrust", "Machine Hip Thrust"]),
                    TemplateExercise(name: "Plank", sets: 3, repMin: 45, repMax: 60, startWeightKg: 0, restSeconds: 45, note: "Seconds", muscleGroup: "Core", alternatives: ["Side Plank", "Dead Bug", "Cable Crunch"]),
                    TemplateExercise(name: "Standing Calf Raise", sets: 3, repMin: 15, repMax: 20, startWeightKg: 20, restSeconds: 45, muscleGroup: "Calves", alternatives: ["Seated Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise"])
                ]
            ),
            TemplateDay(
                code: "B", name: "Circuit B", focus: "Upper endurance",
                colorHex: "059669", weekday: 6,
                exercises: [
                    TemplateExercise(name: "Push-Up", sets: 3, repMin: 12, repMax: 20, startWeightKg: 0, restSeconds: 60, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Machine Chest Press", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Seated Cable Row", sets: 3, repMin: 15, repMax: 20, startWeightKg: 25, restSeconds: 60, muscleGroup: "Back", alternatives: ["Band Row", "Lat Pulldown", "Pull-Up"]),
                    TemplateExercise(name: "Lat Pulldown", sets: 3, repMin: 15, repMax: 20, startWeightKg: 30, restSeconds: 60, muscleGroup: "Back", alternatives: ["Assisted Pull-Up", "Pull-Up", "Neutral-Grip Pulldown"]),
                    TemplateExercise(name: "DB Lateral Raise", sets: 2, repMin: 15, repMax: 20, startWeightKg: 3, restSeconds: 45, jointSensitive: true, muscleGroup: "Side Delts", alternatives: ["Band Lateral Raise", "Cable Lateral Raise", "Machine Lateral Raise"]),
                    TemplateExercise(name: "Dead Bug", sets: 3, repMin: 10, repMax: 12, startWeightKg: 0, restSeconds: 45, note: "Per side", muscleGroup: "Core", alternatives: ["Plank", "Cable Crunch", "Hanging Knee Raise"])
                ]
            )
        ]
    )

    // ==================================================================
    // MARK: ENDURANCE — INTERMEDIATE (Circuit 3×)
    // 12-18 reps · 45-60s rests · lower/upper/full-body split
    // ==================================================================

    static let enduranceIntermediate = ProgramTemplate(
        id: "end_circuit_3",
        name: "Endurance Circuit 3×",
        goal: .endurance,
        tier: .intermediate,
        daysPerWeek: 3,
        summary: "Three weekly circuits — lower, upper, full-body — at 12-18 reps and 45-60s rests. Builds the muscular endurance and joint resilience your cardio volume demands.",
        days: [
            TemplateDay(
                code: "A", name: "Circuit A", focus: "Lower endurance",
                colorHex: "2563EB", weekday: 2,
                exercises: [
                    TemplateExercise(name: "Goblet Squat", sets: 3, repMin: 15, repMax: 18, startWeightKg: 14, restSeconds: 60, muscleGroup: "Quads", alternatives: ["Leg Press", "Hack Squat", "Barbell Squat"]),
                    TemplateExercise(name: "Romanian Deadlift", sets: 3, repMin: 12, repMax: 15, startWeightKg: 25, restSeconds: 60, muscleGroup: "Hamstrings", alternatives: ["Glute Bridge", "Seated Leg Curl", "Lying Leg Curl"]),
                    TemplateExercise(name: "Walking Lunge", sets: 3, repMin: 12, repMax: 15, startWeightKg: 8, restSeconds: 60, note: "Per leg", muscleGroup: "Quads", alternatives: ["Step-Up", "Leg Press", "Hack Squat"]),
                    TemplateExercise(name: "Standing Calf Raise", sets: 3, repMin: 15, repMax: 20, startWeightKg: 25, restSeconds: 45, muscleGroup: "Calves", alternatives: ["Seated Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise"])
                ]
            ),
            TemplateDay(
                code: "B", name: "Circuit B", focus: "Upper endurance",
                colorHex: "059669", weekday: 4,
                exercises: [
                    TemplateExercise(name: "Push-Up", sets: 3, repMin: 12, repMax: 20, startWeightKg: 0, restSeconds: 60, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Machine Chest Press", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Seated Cable Row", sets: 3, repMin: 15, repMax: 18, startWeightKg: 28, restSeconds: 60, muscleGroup: "Back", alternatives: ["Lat Pulldown", "Pull-Up", "Assisted Pull-Up"]),
                    TemplateExercise(name: "DB Lateral Raise", sets: 3, repMin: 15, repMax: 20, startWeightKg: 4, restSeconds: 45, jointSensitive: true, muscleGroup: "Side Delts", alternatives: ["Cable Lateral Raise", "Machine Lateral Raise"]),
                    TemplateExercise(name: "Face Pulls", sets: 2, repMin: 15, repMax: 20, startWeightKg: 12, restSeconds: 45, muscleGroup: "Rear Delts", alternatives: ["Band Pull-Apart", "Reverse Pec Deck", "Rear Delt Fly"])
                ]
            ),
            TemplateDay(
                code: "C", name: "Circuit C", focus: "Full body endurance",
                colorHex: "D97706", weekday: 6,
                exercises: [
                    TemplateExercise(name: "Leg Press", sets: 3, repMin: 15, repMax: 18, startWeightKg: 60, restSeconds: 60, muscleGroup: "Quads", alternatives: ["Goblet Squat", "Hack Squat", "Barbell Squat"]),
                    TemplateExercise(name: "Lat Pulldown", sets: 3, repMin: 15, repMax: 18, startWeightKg: 32, restSeconds: 60, muscleGroup: "Back", alternatives: ["Assisted Pull-Up", "Pull-Up", "Neutral-Grip Pulldown"]),
                    TemplateExercise(name: "Machine Chest Press", sets: 3, repMin: 15, repMax: 18, startWeightKg: 22, restSeconds: 60, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Push-Up", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Plank", sets: 3, repMin: 45, repMax: 60, startWeightKg: 0, restSeconds: 45, note: "Seconds", muscleGroup: "Core", alternatives: ["Side Plank", "Dead Bug", "Cable Crunch"])
                ]
            )
        ]
    )

    // ==================================================================
    // MARK: ENDURANCE — ADVANCED (Circuit 4×, upper/lower ×2)
    // 15-20 reps · short rests · structured resistance to protect against overuse
    // ==================================================================

    static let enduranceAdvanced = ProgramTemplate(
        id: "end_circuit_4",
        name: "Endurance Circuit 4×",
        goal: .endurance,
        tier: .advanced,
        daysPerWeek: 4,
        summary: "Four days split lower/upper ×2 at high reps (15-20) and short rests, for athletes with a heavy cardio base who still want structured resistance work to protect against overuse injury.",
        days: [
            TemplateDay(
                code: "A", name: "Lower 1", focus: "Quad + core endurance",
                colorHex: "2563EB", weekday: 2,
                exercises: [
                    TemplateExercise(name: "Goblet Squat", sets: 4, repMin: 15, repMax: 20, startWeightKg: 16, restSeconds: 50, muscleGroup: "Quads", alternatives: ["Leg Press", "Hack Squat", "Barbell Squat"]),
                    TemplateExercise(name: "Walking Lunge", sets: 3, repMin: 15, repMax: 18, startWeightKg: 8, restSeconds: 50, note: "Per leg", muscleGroup: "Quads", alternatives: ["Bulgarian Split Squat", "Leg Press", "Hack Squat"]),
                    TemplateExercise(name: "Standing Calf Raise", sets: 3, repMin: 18, repMax: 20, startWeightKg: 30, restSeconds: 45, muscleGroup: "Calves", alternatives: ["Seated Calf Raise", "Leg Press Calf Raise", "Smith Machine Calf Raise"]),
                    TemplateExercise(name: "Plank", sets: 3, repMin: 45, repMax: 60, startWeightKg: 0, restSeconds: 45, note: "Seconds", muscleGroup: "Core", alternatives: ["Side Plank", "Dead Bug", "Cable Crunch"])
                ]
            ),
            TemplateDay(
                code: "B", name: "Upper 1", focus: "Push endurance",
                colorHex: "059669", weekday: 3,
                exercises: [
                    TemplateExercise(name: "Push-Up", sets: 4, repMin: 15, repMax: 20, startWeightKg: 0, restSeconds: 50, jointSensitive: true, muscleGroup: "Chest", alternatives: ["Machine Chest Press", "DB Bench Press", "Barbell Bench"]),
                    TemplateExercise(name: "Seated DB Shoulder Press", sets: 3, repMin: 15, repMax: 18, startWeightKg: 6, restSeconds: 50, jointSensitive: true, muscleGroup: "Shoulders", alternatives: ["Machine Shoulder Press", "Barbell OHP", "Arnold Press"]),
                    TemplateExercise(name: "DB Lateral Raise", sets: 3, repMin: 18, repMax: 20, startWeightKg: 4, restSeconds: 45, jointSensitive: true, muscleGroup: "Side Delts", alternatives: ["Cable Lateral Raise", "Machine Lateral Raise"]),
                    TemplateExercise(name: "Rope Pushdown", sets: 3, repMin: 15, repMax: 20, startWeightKg: 15, restSeconds: 45, muscleGroup: "Triceps", alternatives: ["Dips", "Overhead Cable Extension", "Close-Grip Bench"])
                ]
            ),
            TemplateDay(
                code: "C", name: "Lower 2", focus: "Posterior + core endurance",
                colorHex: "8B5CF6", weekday: 5,
                exercises: [
                    TemplateExercise(name: "Romanian Deadlift", sets: 4, repMin: 15, repMax: 18, startWeightKg: 30, restSeconds: 50, muscleGroup: "Hamstrings", alternatives: ["Glute Bridge", "Seated Leg Curl", "Lying Leg Curl"]),
                    TemplateExercise(name: "Glute Bridge", sets: 3, repMin: 18, repMax: 20, startWeightKg: 10, restSeconds: 45, muscleGroup: "Glutes", alternatives: ["Barbell Hip Thrust", "Machine Hip Thrust", "Cable Pull-Through"]),
                    TemplateExercise(name: "Seated Leg Curl", sets: 3, repMin: 15, repMax: 18, startWeightKg: 28, restSeconds: 45, muscleGroup: "Hamstrings", alternatives: ["Lying Leg Curl", "Romanian Deadlift", "45° Back Extension"]),
                    TemplateExercise(name: "Dead Bug", sets: 3, repMin: 12, repMax: 15, startWeightKg: 0, restSeconds: 45, note: "Per side", muscleGroup: "Core", alternatives: ["Plank", "Cable Crunch", "Hanging Knee Raise"])
                ]
            ),
            TemplateDay(
                code: "D", name: "Upper 2", focus: "Pull endurance",
                colorHex: "DC2626", weekday: 6,
                exercises: [
                    TemplateExercise(name: "Seated Cable Row", sets: 4, repMin: 15, repMax: 20, startWeightKg: 30, restSeconds: 50, muscleGroup: "Back", alternatives: ["Lat Pulldown", "Pull-Up", "Assisted Pull-Up"]),
                    TemplateExercise(name: "Lat Pulldown", sets: 3, repMin: 15, repMax: 18, startWeightKg: 34, restSeconds: 50, muscleGroup: "Back", alternatives: ["Assisted Pull-Up", "Pull-Up", "Neutral-Grip Pulldown"]),
                    TemplateExercise(name: "Face Pulls", sets: 3, repMin: 18, repMax: 20, startWeightKg: 14, restSeconds: 45, muscleGroup: "Rear Delts", alternatives: ["Band Pull-Apart", "Reverse Pec Deck", "Rear Delt Fly"]),
                    TemplateExercise(name: "Hammer Curl", sets: 2, repMin: 15, repMax: 20, startWeightKg: 6, restSeconds: 45, muscleGroup: "Biceps", alternatives: ["DB Curl", "EZ Bar Curl", "Cable Curl"])
                ]
            )
        ]
    )
}

// MARK: - Installer

enum ProgramInstaller {

    @MainActor
    static func install(
        _ template: ProgramTemplate,
        context: ModelContext,
        volumeAdjustment: TrainingScienceEngine.VolumeAdjustment? = nil
    ) {
        let pid = ActiveProfile.id
        let profile = ProfileStore.current(context: context)

        // 1. Remove ONLY this profile's day configs + custom sessions
        let dayDescriptor = FetchDescriptor<TrainingDayConfig>(
            predicate: #Predicate { $0.profileId == pid }
        )
        for day in (try? context.fetch(dayDescriptor)) ?? [] {
            context.delete(day)
        }
        let sessionDescriptor = FetchDescriptor<CustomSession>(
            predicate: #Predicate { $0.profileId == pid }
        )
        for session in (try? context.fetch(sessionDescriptor)) ?? [] {
            context.delete(session)
        }

        // 2. Create days + compositions owned by this profile
        for (dayIndex, day) in template.days.enumerated() {
            let config = TrainingDayConfig(
                code: day.code,
                name: day.name,
                focus: day.focus,
                colorHex: day.colorHex,
                weekday: day.weekday,
                orderIndex: dayIndex,
                profileId: pid
            )
            context.insert(config)

            let custom = CustomSession(sessionTypeRaw: day.code)
            custom.profileId = pid
            context.insert(custom)

            for (exIndex, ex) in day.exercises.enumerated() {
                // Personalize: swap toward equipment the user actually has and
                // away from flagged injury areas, then scale the starting
                // weight to their body rather than the template's baseline lifter.
                var exerciseName = ex.name
                if let profile {
                    exerciseName = PersonalizationEngine.fitExerciseName(
                        original: exerciseName,
                        alternatives: ex.alternatives,
                        equipment: profile.equipmentAccess
                    )
                    exerciseName = PersonalizationEngine.safestExerciseName(
                        original: exerciseName,
                        alternatives: ex.alternatives,
                        injuries: profile.injuryFlags
                    )
                }
                let startWeight: Double
                if let profile {
                    startWeight = PersonalizationEngine.personalizedStartWeight(
                        templateWeightKg: ex.startWeightKg,
                        bodyWeightKg: profile.currentWeightKg,
                        sexRaw: profile.sexRaw,
                        experience: profile.experienceLevel
                    )
                } else {
                    startWeight = ex.startWeightKg
                }

                // Experience-based volume/intensity scaling (TrainingScienceEngine):
                // the extra set lands on the day's main compounds (first two
                // exercises, by this catalog's authoring convention), while rest
                // and the intensity note apply across the whole day.
                var sets = ex.sets
                var restSeconds = ex.restSeconds
                var notes = ex.fullNote
                if let adj = volumeAdjustment {
                    if exIndex < 2 { sets = max(1, sets + adj.setDelta) }
                    restSeconds = Int((Double(restSeconds) * adj.restMultiplier).rounded())
                    if !adj.intensityNote.isEmpty {
                        notes = notes.isEmpty ? adj.intensityNote : "\(notes) · \(adj.intensityNote)"
                    }
                }

                let cse = CustomSessionExercise(
                    exerciseId: "\(template.id)_\(day.code)_\(exIndex)",
                    exerciseName: exerciseName,
                    orderIndex: exIndex,
                    sets: sets,
                    repMin: ex.repMin,
                    repMax: ex.repMax,
                    startWeightKg: startWeight,
                    restSeconds: restSeconds,
                    isJointSensitive: ex.jointSensitive,
                    notes: notes,
                    muscleGroup: ex.muscleGroup,
                    sourceRaw: CustomSessionExercise.Source.program.rawValue,
                    alternatives: ex.alternatives.filter { $0 != exerciseName }
                )
                context.insert(cse)
                cse.session = custom
            }
        }

        try? context.save()
    }
}
