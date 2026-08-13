import SwiftUI

// MARK: - Enums

enum SessionType: String, CaseIterable {
    case a = "A"
    case b = "B"
    case c = "C"

    var displayName: String {
        switch self {
        case .a: return "Session A"
        case .b: return "Session B"
        case .c: return "Session C"
        }
    }

    var dayName: String {
        switch self {
        case .a: return "Monday"
        case .b: return "Thursday"
        case .c: return "Saturday"
        }
    }

    var focus: String {
        switch self {
        case .a: return "Push · Pull · Legs + Arms"
        case .b: return "Full Body · Hypertrophy"
        case .c: return "Full Body · Volume"
        }
    }

    var color: Color {
        switch self {
        case .a: return Color(hex: "2563EB")
        case .b: return Color(hex: "059669")
        case .c: return Color(hex: "B45309")
        }
    }
}

enum ExerciseType: String {
    case compound = "COMPOUND"
    case isolation = "ISOLATION"
}

enum RepRange {
    case eightToTen
    case tenToTwelve
    case twelveToFifteen
    case fifteenToTwenty

    var min: Int {
        switch self {
        case .eightToTen: return 8
        case .tenToTwelve: return 10
        case .twelveToFifteen: return 12
        case .fifteenToTwenty: return 15
        }
    }

    var max: Int {
        switch self {
        case .eightToTen: return 10
        case .tenToTwelve: return 12
        case .twelveToFifteen: return 15
        case .fifteenToTwenty: return 20
        }
    }

    var display: String { "\(min)–\(max)" }

    var increment: Double {
        switch self {
        case .eightToTen: return 2.5
        case .tenToTwelve: return 2.5
        case .twelveToFifteen: return 1.25
        case .fifteenToTwenty: return 1.25
        }
    }
}

// MARK: - Exercise Definition

struct ExerciseDefinition: Identifiable {
    let id: String
    let name: String
    let type: ExerciseType
    let sets: Int
    let repRange: RepRange
    let startWeightKg: Double
    let progressionNote: String
    let isJointSensitive: Bool
    let specialProgressionRule: String?
    let alternativeExercise: String?
    let muscleGroup: String
    let gifURL: String?
    let alternativeGifURL: String?
    var supersetGroup: Int? = nil
    var alternatives: [String] = []

    var measurement: ExerciseMeasurement { .infer(name: name, startWeightKg: startWeightKg) }
}

// MARK: - Meal Template

struct MealTemplate: Identifiable {
    let id = UUID()
    let name: String
    let food: String
    let protein: Double
    let calories: Double
}

// MARK: - Supplement

struct Supplement: Identifiable {
    let id = UUID()
    let name: String
    let dose: String
    let timing: String
}

// MARK: - Program Data
// Full-body 3×/week. Every session hits squat, hinge, push, pull, core.
// A = strength bias, B = hypertrophy bias, C = volume/metabolic bias.
// AC-joint-safe pressing throughout; rear delt + cuff work every session.

enum ProgramData {

    // MARK: Session A — Monday · Push/Pull/Legs + Arms
    //
    // User's actual Monday program. Incline machine bench is set to
    // inclination 7 on the machine scale. "Sonunvunu 10 təkrar" on
    // hammer curl = last set capped at 10 reps.

    static let sessionA: [ExerciseDefinition] = [
        ExerciseDefinition(
            id: "mon_a1_incline_machine_press",
            name: "Incline Machine Bench Press",
            type: .compound, sets: 3, repRange: .eightToTen, startWeightKg: 44,
            progressionNote: "+5kg when 3×10", isJointSensitive: true,
            specialProgressionRule: "Machine incline set to 7. Working sets: 44 → 49 → 54 kg (ascending pyramid). Controlled eccentric, drive through the chest.",
            alternativeExercise: "Incline DB Press", muscleGroup: "Chest · Front Delt",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Incline DB Press", "Smith Machine Incline Press", "Landmine Press"]
        ),
        ExerciseDefinition(
            id: "mon_a2_lat_pulldown_wide",
            name: "Lat Pull-Down — Wide Grip",
            type: .compound, sets: 3, repRange: .eightToTen, startWeightKg: 40,
            progressionNote: "+5kg when 3×10", isJointSensitive: false,
            specialProgressionRule: "Working sets: 40 → 45 → 50 kg (ascending). Wide overhand grip, pull to upper chest, slight lean back. Full stretch at top.",
            alternativeExercise: "Pull-Up", muscleGroup: "Lats · Mid Back",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Pull-Up", "Neutral-Grip Lat Pulldown", "Straight-Arm Pulldown"]
        ),
        ExerciseDefinition(
            id: "mon_a3_seated_cable_row_single",
            name: "Seated Cable Row — Single Arm",
            type: .compound, sets: 3, repRange: .eightToTen, startWeightKg: 30,
            progressionNote: "+5kg when 3×10", isJointSensitive: false,
            specialProgressionRule: "Each hand separately. Working sets: 30 → 40 → 40 kg (ascending). Chest-supported standing pull variation — squeeze at peak contraction, full stretch forward.",
            alternativeExercise: "Chest-Supported Row", muscleGroup: "Mid Back · Lats",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Chest-Supported Row", "T-Bar Row", "Dumbbell Row"]
        ),
        ExerciseDefinition(
            id: "mon_a4_incline_shoulder_press",
            name: "Incline Shoulder Press — Machine",
            type: .compound, sets: 2, repRange: .eightToTen, startWeightKg: 50,
            progressionNote: "+5kg when 2×10", isJointSensitive: true,
            specialProgressionRule: "Back-supported incline (reclined back). Working sets: 50 → 55 kg. Controlled press, don't lock out — keep tension on delts.",
            alternativeExercise: "DB Shoulder Press", muscleGroup: "Shoulders · Front Delt",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["DB Shoulder Press", "Arnold Press", "Landmine Press"]
        ),
        ExerciseDefinition(
            id: "mon_a5_cable_lateral_raise",
            name: "Cable Front-to-Lateral Raise",
            type: .isolation, sets: 3, repRange: .tenToTwelve, startWeightKg: 15,
            progressionNote: "+2.5kg when 3×12", isJointSensitive: false,
            specialProgressionRule: "Cable from low pulley, stand centered over it, lift from between feet upward and out. Working sets: 15 → 20 → 25 kg (ascending). Controlled tempo.",
            alternativeExercise: "DB Lateral Raise", muscleGroup: "Side Delt",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["DB Lateral Raise", "Machine Lateral Raise", "Cable Lateral Raise"]
        ),
        ExerciseDefinition(
            id: "mon_a6_goblet_squat",
            name: "Goblet Squat",
            type: .compound, sets: 3, repRange: .eightToTen, startWeightKg: 20,
            progressionNote: "+2.5kg when 3×10", isJointSensitive: false,
            specialProgressionRule: "Working sets: 20 → 22.5 → 25 kg (ascending). Hold dumbbell at chest, elbows between knees at bottom. Full depth, controlled eccentric.",
            alternativeExercise: "Leg Press", muscleGroup: "Quads · Glutes",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Leg Press", "Front Squat", "Hack Squat"]
        ),
        ExerciseDefinition(
            id: "mon_a7_overhead_tricep_rope",
            name: "Overhead Tricep Extension — Rope",
            type: .isolation, sets: 3, repRange: .tenToTwelve, startWeightKg: 12.5,
            progressionNote: "+2.5kg when 3×12", isJointSensitive: false,
            specialProgressionRule: "Cable rope, facing away from machine, arms overhead. Working sets: 12.5 → 15 → 17.5 kg (ascending). Full stretch behind head, squeeze at lockout.",
            alternativeExercise: "Skull Crusher", muscleGroup: "Triceps",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Skull Crusher", "Close-Grip Bench Press", "Dip Machine"]
        ),
        ExerciseDefinition(
            id: "mon_a8_single_arm_pushdown",
            name: "Single-Arm Cable Pushdown",
            type: .isolation, sets: 3, repRange: .tenToTwelve, startWeightKg: 7.5,
            progressionNote: "+2.5kg when 3×12", isJointSensitive: false,
            specialProgressionRule: "One hand at a time. Working sets: 7.5 → 10 → 10 kg. Keep elbow pinned to side, full extension at bottom.",
            alternativeExercise: "Rope Pushdown", muscleGroup: "Triceps",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Rope Pushdown", "V-Bar Pushdown", "Kickback"]
        ),
        ExerciseDefinition(
            id: "mon_a9_hammer_curl",
            name: "Hammer Curl",
            type: .isolation, sets: 3, repRange: .eightToTen, startWeightKg: 10,
            progressionNote: "+2.5kg when 3×10", isJointSensitive: false,
            specialProgressionRule: "Working sets: 10 → 12.5 → 15 kg (ascending). Last set capped at 10 reps. Neutral grip, no swinging — strict form, controlled negative.",
            alternativeExercise: "Incline DB Curl", muscleGroup: "Biceps · Brachialis",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Incline DB Curl", "Barbell Curl", "Cable Curl"]
        )
    ]

    // MARK: Session B — Full Body · Hypertrophy bias

    static let sessionB: [ExerciseDefinition] = [
        ExerciseDefinition(
            id: "fb_b1_leg_press",
            name: "Leg Press",
            type: .compound, sets: 4, repRange: .tenToTwelve, startWeightKg: 80,
            progressionNote: "+5kg when 4×12", isJointSensitive: false,
            specialProgressionRule: "Feet mid-platform shoulder-width. Full controlled depth, no knee lockout at top.",
            alternativeExercise: "Hack Squat", muscleGroup: "Quads",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Hack Squat", "Barbell Back Squat", "Belt Squat"]
        ),
        ExerciseDefinition(
            id: "fb_b2_seated_db_shoulder_press",
            name: "Seated DB Shoulder Press — 30° Back",
            type: .compound, sets: 4, repRange: .tenToTwelve, startWeightKg: 12.5,
            progressionNote: "+1.25kg per DB when 4×12", isJointSensitive: true,
            specialProgressionRule: "Backrest at ~30° reduces AC stress vs strict vertical. Lower to ear level only.",
            alternativeExercise: "Machine Shoulder Press", muscleGroup: "Shoulders",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Machine Shoulder Press", "Landmine Press", "Arnold Press"]
        ),
        ExerciseDefinition(
            id: "fb_b3_one_arm_db_row",
            name: "One-Arm DB Row",
            type: .compound, sets: 3, repRange: .tenToTwelve, startWeightKg: 16,
            progressionNote: "+2kg when 3×12 per side", isJointSensitive: false,
            specialProgressionRule: "Knee and hand on bench. Pull DB to hip, not armpit. Full stretch at bottom.",
            alternativeExercise: "Cable Single-Arm Row", muscleGroup: "Lats · Mid Back",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Cable Single-Arm Row", "Meadows Row", "Chest-Supported Row"]
        ),
        ExerciseDefinition(
            id: "fb_b4_hip_thrust",
            name: "Hip Thrust — Barbell",
            type: .compound, sets: 3, repRange: .tenToTwelve, startWeightKg: 40,
            progressionNote: "+5kg when 3×12", isJointSensitive: false,
            specialProgressionRule: "Shoulders on bench, chin tucked, full lockout with 1s glute squeeze. Highest-EMG glute movement in the literature.",
            alternativeExercise: "Glute Bridge", muscleGroup: "Glutes",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Glute Bridge", "Cable Pull-Through", "Reverse Hyperextension"]
        ),
        ExerciseDefinition(
            id: "fb_b5_cable_fly",
            name: "Cable Fly — Mid Height",
            type: .isolation, sets: 3, repRange: .twelveToFifteen, startWeightKg: 10,
            progressionNote: "+1.25kg when 3×15", isJointSensitive: true,
            specialProgressionRule: "Slight elbow bend held constant. Stop at chest line on the stretch — don't overstretch the shoulder capsule.",
            alternativeExercise: "Pec Deck", muscleGroup: "Chest",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Pec Deck", "DB Fly — Flat", "Svend Press"]
        ),
        ExerciseDefinition(
            id: "fb_b6_hammer_curl",
            name: "Hammer Curl",
            type: .isolation, sets: 3, repRange: .tenToTwelve, startWeightKg: 10,
            progressionNote: "+1.25kg when 3×12", isJointSensitive: false,
            specialProgressionRule: "Neutral grip is elbow-friendliest curl. Brachialis emphasis builds visible arm thickness.",
            alternativeExercise: "Cable Rope Curl", muscleGroup: "Biceps",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Cable Rope Curl", "Cross-Body Hammer Curl", "Incline DB Curl"]
        ),
        ExerciseDefinition(
            id: "fb_b7_rope_pushdown",
            name: "Triceps Rope Pushdown",
            type: .isolation, sets: 3, repRange: .tenToTwelve, startWeightKg: 17.5,
            progressionNote: "+1.25kg when 3×12", isJointSensitive: false,
            specialProgressionRule: "Split the rope at the bottom for full lateral-head contraction.",
            alternativeExercise: "V-Bar Pushdown", muscleGroup: "Triceps",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["V-Bar Pushdown", "Dip Machine", "Close-Grip Bench Press"]
        ),
        ExerciseDefinition(
            id: "fb_b8_reverse_pec_deck",
            name: "Reverse Pec Deck",
            type: .isolation, sets: 3, repRange: .twelveToFifteen, startWeightKg: 20,
            progressionNote: "+2.5kg when 3×15", isJointSensitive: false,
            specialProgressionRule: "Rear delts every session. Squeeze shoulder blades at peak, constant slight elbow bend.",
            alternativeExercise: "Bent-Over Reverse Fly", muscleGroup: "Rear Delt",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Bent-Over Reverse Fly", "Face Pulls — Rope", "Cable Reverse Fly"]
        )
    ]

    // MARK: Session C — Full Body · Volume / Metabolic bias

    static let sessionC: [ExerciseDefinition] = [
        ExerciseDefinition(
            id: "fb_c1_bulgarian_split_squat",
            name: "Bulgarian Split Squat",
            type: .compound, sets: 3, repRange: .tenToTwelve, startWeightKg: 10,
            progressionNote: "+1.25kg per DB when 3×12 per leg", isJointSensitive: false,
            specialProgressionRule: "Rear foot on bench. Torso slightly forward for glute bias, upright for quads. Also trains single-leg balance.",
            alternativeExercise: "Walking Lunge", muscleGroup: "Quads · Glutes",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Walking Lunge", "Step-Up", "Reverse Lunge"]
        ),
        ExerciseDefinition(
            id: "fb_c2_push_up_weighted",
            name: "Push-Up — Weighted or Deficit",
            type: .compound, sets: 3, repRange: .twelveToFifteen, startWeightKg: 0,
            progressionNote: "Master BW 3×15 → add plate on back or elevate feet", isJointSensitive: true,
            specialProgressionRule: "Hands slightly wider than shoulders, elbows ~45°. Scapula moves freely — that's what makes push-ups more shoulder-friendly than bench.",
            alternativeExercise: "Machine Chest Press", muscleGroup: "Chest · Triceps",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Machine Chest Press", "Flat DB Press", "Dips — Chest Bias"]
        ),
        ExerciseDefinition(
            id: "fb_c3_seated_cable_row",
            name: "Seated Cable Row — Wide Grip",
            type: .compound, sets: 3, repRange: .twelveToFifteen, startWeightKg: 40,
            progressionNote: "+2.5kg when 3×15", isJointSensitive: false,
            specialProgressionRule: "Wide grip biases upper back and rear delts. Chest tall, pull to sternum.",
            alternativeExercise: "Machine Row", muscleGroup: "Upper Back",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Machine Row", "Barbell Row", "Inverted Row"]
        ),
        ExerciseDefinition(
            id: "fb_c4_leg_curl",
            name: "Seated Leg Curl",
            type: .isolation, sets: 3, repRange: .twelveToFifteen, startWeightKg: 30,
            progressionNote: "+2.5kg when 3×15", isJointSensitive: false,
            specialProgressionRule: "Seated beats lying for hamstring hypertrophy (greater stretch under load, per 2021 comparison studies).",
            alternativeExercise: "Lying Leg Curl", muscleGroup: "Hamstrings",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Lying Leg Curl", "Nordic Hamstring Curl", "Swiss Ball Leg Curl"]
        ),
        ExerciseDefinition(
            id: "fb_c5_cable_lateral_raise",
            name: "Cable Lateral Raise",
            type: .isolation, sets: 4, repRange: .twelveToFifteen, startWeightKg: 7.5,
            progressionNote: "+1.25kg when 4×15", isJointSensitive: true,
            specialProgressionRule: "Lead with the elbow, stop at shoulder height. Constant cable tension beats DBs for side delt growth.",
            alternativeExercise: "DB Lateral Raise", muscleGroup: "Side Delt",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["DB Lateral Raise", "Machine Lateral Raise", "Leaning Cable Lateral Raise"]
        ),
        ExerciseDefinition(
            id: "fb_c6_ez_curl",
            name: "EZ Bar Curl",
            type: .isolation, sets: 3, repRange: .tenToTwelve, startWeightKg: 15,
            progressionNote: "+2.5kg when 3×12", isJointSensitive: false,
            specialProgressionRule: "EZ bar spares the wrists. Elbows pinned at sides, no swing.",
            alternativeExercise: "DB Curl", muscleGroup: "Biceps",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["DB Curl", "Preacher Curl", "Barbell Curl"]
        ),
        ExerciseDefinition(
            id: "fb_c7_overhead_tricep",
            name: "Overhead Cable Tricep Extension",
            type: .isolation, sets: 3, repRange: .twelveToFifteen, startWeightKg: 15,
            progressionNote: "+1.25kg when 3×15", isJointSensitive: false,
            specialProgressionRule: "Overhead position stretches the long head — the biggest tricep growth lever.",
            alternativeExercise: "Skull Crusher", muscleGroup: "Triceps",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Skull Crusher", "DB Overhead Extension", "Dip Machine"]
        ),
        ExerciseDefinition(
            id: "fb_c8_standing_calf",
            name: "Standing Calf Raise",
            type: .isolation, sets: 3, repRange: .twelveToFifteen, startWeightKg: 30,
            progressionNote: "+5kg when 3×15", isJointSensitive: false,
            specialProgressionRule: "Deep stretch at the bottom, 2s pause. The stretch is where calves grow.",
            alternativeExercise: "Seated Calf Raise", muscleGroup: "Calves",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Seated Calf Raise", "Leg Press Calf Raise", "Donkey Calf Raise"]
        ),
        ExerciseDefinition(
            id: "fb_c9_hanging_knee_raise",
            name: "Hanging Knee Raise",
            type: .isolation, sets: 3, repRange: .tenToTwelve, startWeightKg: 0,
            progressionNote: "Master 3×12 → straighten legs progressively", isJointSensitive: false,
            specialProgressionRule: "No swinging. Posterior pelvic tilt at the top — curl the pelvis, don't just lift knees.",
            alternativeExercise: "Cable Crunch", muscleGroup: "Core",
            gifURL: nil, alternativeGifURL: nil,
            alternatives: ["Cable Crunch", "Weighted Decline Sit-Up", "Ab Wheel Rollout"]
        )
    ]

    // MARK: - Session Lookup

    static func exercises(for sessionType: SessionType) -> [ExerciseDefinition] {
        switch sessionType {
        case .a: return sessionA
        case .b: return sessionB
        case .c: return sessionC
        }
    }

    static func sessionType(for date: Date) -> SessionType? {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 3: return .a
        case 5: return .b
        case 7: return .c
        default: return nil
        }
    }

    static var todaySessionType: SessionType? {
        sessionType(for: Date())
    }

    // MARK: - Meal Templates

    static let mealTemplates: [MealTemplate] = [
        MealTemplate(name: "Eggs + Oats", food: "3 eggs + 80g oats + fruit", protein: 35, calories: 420),
        MealTemplate(name: "Cottage Cheese", food: "200g cottage cheese + fruit", protein: 22, calories: 200),
        MealTemplate(name: "Chicken + Rice", food: "200g chicken + rice + veg", protein: 46, calories: 500),
        MealTemplate(name: "Banana + Whey", food: "Banana + 30g whey", protein: 25, calories: 250),
        MealTemplate(name: "Whey + Fruit", food: "40g whey + fruit", protein: 32, calories: 220),
        MealTemplate(name: "Salmon + Veg", food: "150g salmon + vegetables", protein: 35, calories: 350)
    ]

    // MARK: - Supplements (goal-dynamic stacks)

    static func supplements(for goal: TrainingGoal) -> [Supplement] {
        switch goal {
        case .hypertrophy:
            return [
                Supplement(name: "Creatine Monohydrate", dose: "5g", timing: "Daily, any time"),
                Supplement(name: "Whey Protein", dose: "30g", timing: "Post-workout"),
                Supplement(name: "Vitamin D3/K2", dose: "5,000 IU", timing: "With fat meal"),
                Supplement(name: "Magnesium Malate", dose: "300mg", timing: "Pre-sleep")
            ]
        case .strength:
            return [
                Supplement(name: "Creatine Monohydrate", dose: "5g", timing: "Daily, any time"),
                Supplement(name: "Whey Protein", dose: "30g", timing: "Post-workout"),
                Supplement(name: "Omega-3 Fish Oil", dose: "2g", timing: "With food"),
                Supplement(name: "Vitamin D3/K2", dose: "5,000 IU", timing: "With fat meal")
            ]
        case .fatLoss:
            // L-Carnitine was dropped: ISSN rates it as having no meaningful
            // fat-loss effect in people without a carnitine deficiency —
            // three well-evidenced items beat four padded with a weak one.
            return [
                Supplement(name: "Caffeine", dose: "200mg", timing: "Pre-workout"),
                Supplement(name: "Fiber (Psyllium Husk)", dose: "5g", timing: "With largest meal"),
                Supplement(name: "Vitamin D3/K2", dose: "5,000 IU", timing: "With fat meal")
            ]
        case .stayFit:
            return [
                Supplement(name: "Multivitamin", dose: "Label dose", timing: "Morning, with food"),
                Supplement(name: "Omega-3 Fish Oil", dose: "2g", timing: "With food"),
                Supplement(name: "Vitamin D3/K2", dose: "5,000 IU", timing: "With fat meal"),
                Supplement(name: "Magnesium Malate", dose: "300mg", timing: "Pre-sleep")
            ]
        case .endurance:
            // Iron was dropped from the default stack: it's a real
            // supplement worth having (endurance athletes have elevated
            // deficiency risk from foot-strike hemolysis), but ISSN/clinical
            // guidance is explicit that iron should only be supplemented
            // after bloodwork confirms deficiency — unlike everything else
            // here, iron overload is a genuine harm risk in someone who
            // isn't actually deficient, so it shouldn't be auto-seeded.
            return [
                Supplement(name: "Electrolytes", dose: "1 serving", timing: "During training"),
                Supplement(name: "Beta-Alanine", dose: "3.2g", timing: "Daily, any time"),
                Supplement(name: "Beetroot Juice (Nitrate)", dose: "~500mg nitrate", timing: "2-3h before a hard session"),
                Supplement(name: "Vitamin D3/K2", dose: "5,000 IU", timing: "With fat meal")
            ]
        }
    }

    // MARK: - Progressive Overload Logic

    static func nextSessionWeight(
        exercise: ExerciseDefinition,
        completedSets: [SetLog],
        isFlareDay: Bool
    ) -> Double {
        guard !completedSets.isEmpty else { return exercise.startWeightKg }

        let currentWeight = completedSets.first?.weightKg ?? exercise.startWeightKg
        let allSetsCompleted = completedSets.filter { $0.isCompleted }
        let targetSets = exercise.sets
        let targetReps = exercise.repRange.max

        let allHitTarget = allSetsCompleted.count >= targetSets &&
            allSetsCompleted.allSatisfy { $0.reps >= targetReps }

        var suggested = allHitTarget
            ? currentWeight + exercise.repRange.increment
            : currentWeight

        if isFlareDay {
            suggested = (suggested * 0.75).rounded(toNearest: 1.25)
        }

        return suggested
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Double Rounding Helper

extension Double {
    func rounded(toNearest value: Double) -> Double {
        guard value > 0 else { return self }
        return (self / value).rounded() * value
    }
}
