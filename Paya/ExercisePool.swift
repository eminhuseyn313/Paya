import Foundation

// MARK: - Movement Pattern Taxonomy
//
// The static ProgramTemplates catalog hand-authored ~20 fixed day-by-day
// plans. That caps hypertrophy plans at whatever exercise count someone
// typed in at 2am, and forces every user of a given goal/tier onto the same
// exercises regardless of equipment or injuries. This pool is the
// generative alternative: real exercises tagged by movement pattern,
// equipment, joint sensitivity, and minimum experience level, so
// ProgramAssembler can build a genuinely personalized day rather than
// pattern-match a pre-written one.

enum MovementPattern: String, CaseIterable {
    case squat, lunge, hinge, hipThrust
    case horizontalPush, verticalPush
    case horizontalPull, verticalPull
    case sideDelt, rearDelt, biceps, triceps
    case calves, core, cardioFinisher
    case hipStability   // hip/glute activation — see ProgramAssembler's female-profile ACL-injury-prevention note
}

struct PoolExercise {
    let name: String
    let pattern: MovementPattern
    let muscleGroup: String
    let minLevel: ExperienceLevel      // exercises below this are hidden from that experience level
    let jointSensitive: Bool
    let startWeightKg: Double          // authored against the same ~85kg intermediate baseline as ProgramTemplates
    let note: String
    let alternatives: [String]         // for further equipment/injury substitution inside ProgramInstaller

    init(_ name: String, _ pattern: MovementPattern, _ muscleGroup: String, minLevel: ExperienceLevel = .beginner, jointSensitive: Bool = false, startWeightKg: Double = 0, note: String = "", alternatives: [String] = []) {
        self.name = name
        self.pattern = pattern
        self.muscleGroup = muscleGroup
        self.minLevel = minLevel
        self.jointSensitive = jointSensitive
        self.startWeightKg = startWeightKg
        self.note = note
        self.alternatives = alternatives
    }

    var equipmentTag: ExerciseEquipmentTag { ExerciseEquipmentTag.classify(name) }
    var measurement: ExerciseMeasurement { .infer(name: name, startWeightKg: startWeightKg) }
}

enum ExercisePool {

    /// All entries usable by a lifter of `level` or below that requirement —
    /// i.e. a beginner sees only minLevel == .beginner, an advanced lifter
    /// sees everything.
    static func candidates(for pattern: MovementPattern, level: ExperienceLevel) -> [PoolExercise] {
        byPattern[pattern, default: []].filter { levelRank($0.minLevel) <= levelRank(level) }
    }

    private static func levelRank(_ level: ExperienceLevel) -> Int {
        switch level {
        case .beginner: return 0
        case .intermediate: return 1
        case .advanced: return 2
        }
    }

    static let byPattern: [MovementPattern: [PoolExercise]] = {
        var map: [MovementPattern: [PoolExercise]] = [:]
        for ex in all { map[ex.pattern, default: []].append(ex) }
        return map
    }()

    static let all: [PoolExercise] = [
        // MARK: Squat (knee-dominant, bilateral)
        PoolExercise("Goblet Squat", .squat, "Quads", startWeightKg: 16, alternatives: ["Bodyweight Squat", "Leg Press"]),
        PoolExercise("Leg Press", .squat, "Quads", startWeightKg: 70, alternatives: ["Goblet Squat", "Hack Squat"]),
        PoolExercise("Hack Squat", .squat, "Quads", minLevel: .intermediate, startWeightKg: 60, alternatives: ["Leg Press"]),
        PoolExercise("Barbell Back Squat", .squat, "Quads", minLevel: .intermediate, jointSensitive: true, startWeightKg: 40, note: "RPE 8", alternatives: ["Hack Squat", "Leg Press"]),
        PoolExercise("Front Squat", .squat, "Quads", minLevel: .advanced, jointSensitive: true, startWeightKg: 30, note: "More upright torso than back squat — higher vastus medialis activation and less lumbar loading at heavy weights", alternatives: ["Barbell Back Squat"]),
        PoolExercise("Leg Extension", .squat, "Quads", minLevel: .intermediate, startWeightKg: 30, note: "Isolation finisher", alternatives: ["Sissy Squat"]),
        PoolExercise("Bodyweight Squat", .squat, "Quads", alternatives: ["Goblet Squat"]),

        // MARK: Lunge (knee-dominant, unilateral)
        PoolExercise("Walking Lunge", .lunge, "Quads", startWeightKg: 6, note: "Per leg", alternatives: ["Step-Up", "Bulgarian Split Squat"]),
        PoolExercise("Bulgarian Split Squat", .lunge, "Quads", minLevel: .intermediate, startWeightKg: 8, note: "Per leg", alternatives: ["Walking Lunge", "Step-Up"]),
        PoolExercise("Step-Up", .lunge, "Quads", startWeightKg: 6, note: "Per leg", alternatives: ["Walking Lunge"]),
        PoolExercise("Reverse Lunge", .lunge, "Quads", startWeightKg: 8, note: "Per leg", alternatives: ["Walking Lunge"]),

        // MARK: Hinge (hip-dominant, bilateral)
        // Romanian deadlift and Nordic curl are deliberately both present and
        // both prioritized: Romanian deadlift shows lower erector-spinae-to-
        // hamstring activation than other deadlift variants (more hamstring-
        // dominant, more spine-sparing — Martin-Fuentes et al. 2020, PLOS
        // ONE). Nordic curl and prone-lying leg curl are complementary, not
        // redundant — Nordic preferentially biases the semitendinosus, prone
        // curl the biceps femoris (Sahinis/Amiridis/Enoka/Kellis 2025, J
        // Sports Sciences meta-analysis) — so both sub-regions of the
        // hamstring get direct coverage across a program rather than one
        // exercise standing in for the whole muscle group.
        PoolExercise("Romanian Deadlift", .hinge, "Hamstrings", startWeightKg: 30, alternatives: ["Glute Bridge", "45° Back Extension"]),
        PoolExercise("Nordic Hamstring Curl", .hinge, "Hamstrings", minLevel: .intermediate, jointSensitive: true, startWeightKg: 0, note: "Eccentric-only — semitendinosus-biased, the sub-region prone leg curls under-train", alternatives: ["Lying Leg Curl", "Romanian Deadlift"]),
        PoolExercise("Seated Leg Curl", .hinge, "Hamstrings", startWeightKg: 30, alternatives: ["Lying Leg Curl"]),
        PoolExercise("Lying Leg Curl", .hinge, "Hamstrings", startWeightKg: 30, note: "Biceps femoris-biased — complements Nordic curl's semitendinosus bias", alternatives: ["Seated Leg Curl"]),
        PoolExercise("45° Back Extension", .hinge, "Hamstrings", startWeightKg: 0, alternatives: ["Romanian Deadlift"]),
        PoolExercise("Trap Bar Deadlift", .hinge, "Hamstrings", minLevel: .intermediate, jointSensitive: true, startWeightKg: 40, note: "More quad-biased, less erector-spinae loading than a conventional deadlift — a joint-friendlier hinge for a bad lower back", alternatives: ["Romanian Deadlift", "Barbell Deadlift"]),
        PoolExercise("Barbell Deadlift", .hinge, "Hamstrings", minLevel: .advanced, jointSensitive: true, startWeightKg: 50, note: "RPE 8", alternatives: ["Romanian Deadlift", "Trap Bar Deadlift"]),
        PoolExercise("Good Morning", .hinge, "Hamstrings", minLevel: .advanced, jointSensitive: true, startWeightKg: 20, alternatives: ["Romanian Deadlift"]),
        PoolExercise("Single-Leg RDL (bodyweight)", .hinge, "Hamstrings", startWeightKg: 0, note: "Per leg — balance-limited before it needs load", alternatives: ["Romanian Deadlift"]),

        // MARK: Hip thrust (glute-dominant)
        PoolExercise("Glute Bridge", .hipThrust, "Glutes", startWeightKg: 0, alternatives: ["Hip Thrust"]),
        PoolExercise("Hip Thrust", .hipThrust, "Glutes", minLevel: .intermediate, startWeightKg: 30, alternatives: ["Glute Bridge"]),
        PoolExercise("Barbell Hip Thrust", .hipThrust, "Glutes", minLevel: .intermediate, startWeightKg: 40, note: "1s squeeze at top", alternatives: ["Hip Thrust", "Glute Bridge"]),

        // MARK: Horizontal push (chest)
        PoolExercise("Push-Up", .horizontalPush, "Chest", jointSensitive: true, startWeightKg: 0, alternatives: ["Machine Chest Press"]),
        PoolExercise("Machine Chest Press", .horizontalPush, "Chest", jointSensitive: true, startWeightKg: 25, alternatives: ["Push-Up", "DB Bench Press"]),
        PoolExercise("DB Bench Press", .horizontalPush, "Chest", minLevel: .intermediate, jointSensitive: true, startWeightKg: 20, note: "RPE 8, tucked elbows", alternatives: ["Machine Chest Press"]),
        PoolExercise("Incline DB Press", .horizontalPush, "Chest", jointSensitive: true, startWeightKg: 12, note: "30° incline", alternatives: ["Machine Incline Press"]),
        PoolExercise("Machine Incline Press", .horizontalPush, "Chest", jointSensitive: true, startWeightKg: 22, alternatives: ["Incline DB Press"]),
        PoolExercise("Cable Fly", .horizontalPush, "Chest", minLevel: .intermediate, jointSensitive: true, startWeightKg: 12, note: "Stretch focus, isolation", alternatives: ["Pec Deck"]),
        PoolExercise("Pec Deck", .horizontalPush, "Chest", jointSensitive: true, startWeightKg: 20, note: "Fixed path keeps tension on the chest without needing stabilizer strength — a good low-fatigue isolation finisher", alternatives: ["Cable Fly"]),
        PoolExercise("Barbell Bench Press", .horizontalPush, "Chest", minLevel: .advanced, jointSensitive: true, startWeightKg: 30, alternatives: ["DB Bench Press"]),

        // MARK: Vertical push (shoulders)
        PoolExercise("Seated DB Shoulder Press", .verticalPush, "Shoulders", jointSensitive: true, startWeightKg: 12, alternatives: ["Machine Shoulder Press"]),
        PoolExercise("Machine Shoulder Press", .verticalPush, "Shoulders", jointSensitive: true, startWeightKg: 20, alternatives: ["Seated DB Shoulder Press"]),
        PoolExercise("DB Arnold Press", .verticalPush, "Shoulders", minLevel: .intermediate, jointSensitive: true, startWeightKg: 10, note: "Rotating path recruits all three delt heads, not just the front", alternatives: ["Seated DB Shoulder Press"]),
        PoolExercise("Overhead Barbell Press", .verticalPush, "Shoulders", minLevel: .advanced, jointSensitive: true, startWeightKg: 20, alternatives: ["Seated DB Shoulder Press"]),
        PoolExercise("Pike Push-Up", .verticalPush, "Shoulders", minLevel: .intermediate, jointSensitive: true, startWeightKg: 0, note: "Feet elevated to add load without equipment", alternatives: ["Seated DB Shoulder Press"]),

        // MARK: Horizontal pull (back)
        PoolExercise("Seated Cable Row", .horizontalPull, "Back", startWeightKg: 30, alternatives: ["Chest-Supported Row"]),
        PoolExercise("Chest-Supported Row", .horizontalPull, "Back", startWeightKg: 18, alternatives: ["Seated Cable Row"]),
        PoolExercise("One-Arm DB Row", .horizontalPull, "Back", startWeightKg: 16, note: "Per arm", alternatives: ["Seated Cable Row"]),
        PoolExercise("Machine Row", .horizontalPull, "Back", startWeightKg: 30, alternatives: ["Seated Cable Row", "Seated Row Machine"]),
        PoolExercise("Seated Row Machine", .horizontalPull, "Back", startWeightKg: 30, alternatives: ["Machine Row", "Seated Cable Row"]),
        PoolExercise("Barbell Row", .horizontalPull, "Back", minLevel: .advanced, jointSensitive: true, startWeightKg: 30, alternatives: ["Chest-Supported Row"]),
        PoolExercise("Band Row", .horizontalPull, "Back", startWeightKg: 0, alternatives: ["Seated Cable Row"]),
        PoolExercise("Inverted Row (table or bar)", .horizontalPull, "Back", startWeightKg: 0, note: "Feet elevated to add load without equipment", alternatives: ["Seated Cable Row"]),

        // MARK: Vertical pull (back/lats)
        PoolExercise("Lat Pulldown", .verticalPull, "Back", startWeightKg: 35, alternatives: ["Assisted Pull-Up"]),
        PoolExercise("Assisted Pull-Up", .verticalPull, "Back", startWeightKg: 0, alternatives: ["Lat Pulldown"]),
        PoolExercise("Neutral-Grip Pulldown", .verticalPull, "Back", startWeightKg: 35, alternatives: ["Lat Pulldown"]),
        PoolExercise("Pull-Up", .verticalPull, "Back", minLevel: .advanced, startWeightKg: 0, alternatives: ["Lat Pulldown", "Assisted Pull-Up"]),
        PoolExercise("Negative Pull-Up", .verticalPull, "Back", startWeightKg: 0, note: "Jump to top, lower slowly — builds toward a full rep", alternatives: ["Lat Pulldown", "Assisted Pull-Up"]),

        // MARK: Side delts
        PoolExercise("DB Lateral Raise", .sideDelt, "Side Delts", jointSensitive: true, startWeightKg: 5, note: "Thumbs level or slightly down, not rotated up — an externally-rotated grip shifts the work toward the front delt instead", alternatives: ["Cable Lateral Raise", "Band Lateral Raise"]),
        PoolExercise("Cable Lateral Raise", .sideDelt, "Side Delts", jointSensitive: true, startWeightKg: 6, alternatives: ["DB Lateral Raise"]),
        PoolExercise("Machine Lateral Raise", .sideDelt, "Side Delts", jointSensitive: true, startWeightKg: 10, note: "Fixed path — easier to isolate the side delt without swinging momentum into the lift", alternatives: ["DB Lateral Raise"]),
        PoolExercise("Band Lateral Raise", .sideDelt, "Side Delts", startWeightKg: 0, alternatives: ["DB Lateral Raise"]),

        // MARK: Rear delts
        PoolExercise("Face Pulls", .rearDelt, "Rear Delts", startWeightKg: 14, alternatives: ["Cable Rope Face Pull", "Band Pull-Apart", "Reverse Pec Deck"]),
        PoolExercise("Cable Rope Face Pull", .rearDelt, "Rear Delts", startWeightKg: 14, alternatives: ["Face Pulls", "Reverse Pec Deck"]),
        PoolExercise("Reverse Pec Deck", .rearDelt, "Rear Delts", startWeightKg: 20, alternatives: ["Face Pulls", "Rear Delt / Mid-Back Machine"]),
        PoolExercise("Band Pull-Apart", .rearDelt, "Rear Delts", startWeightKg: 0, alternatives: ["Face Pulls"]),
        PoolExercise("Prone Y-Raise (bodyweight)", .rearDelt, "Rear Delts", startWeightKg: 0, note: "Face down, thumbs up, squeeze shoulder blades", alternatives: ["Face Pulls"]),

        // MARK: Biceps
        PoolExercise("EZ Bar Curl", .biceps, "Biceps", startWeightKg: 18, alternatives: ["DB Curl", "Cable Curl"]),
        PoolExercise("DB Curl", .biceps, "Biceps", startWeightKg: 8, alternatives: ["EZ Bar Curl"]),
        PoolExercise("Hammer Curl", .biceps, "Biceps", startWeightKg: 8, alternatives: ["DB Curl"]),
        PoolExercise("Cable Curl", .biceps, "Biceps", startWeightKg: 15, alternatives: ["EZ Bar Curl"]),
        PoolExercise("DB Preacher Curl", .biceps, "Biceps", minLevel: .intermediate, startWeightKg: 8, note: "Fixed arm position isolates the biceps and removes momentum — strong stretch-position stimulus", alternatives: ["DB Curl", "EZ Bar Curl"]),
        PoolExercise("Chin-Up", .biceps, "Biceps", minLevel: .intermediate, startWeightKg: 0, note: "Supinated grip — the most biceps-biased bodyweight pull variation", alternatives: ["DB Curl", "Negative Chin-Up"]),
        PoolExercise("Negative Chin-Up", .biceps, "Biceps", startWeightKg: 0, note: "Jump to chin over bar, lower slowly — builds toward a full chin-up", alternatives: ["DB Curl", "Chin-Up"]),

        // MARK: Triceps
        PoolExercise("Rope Pushdown", .triceps, "Triceps", startWeightKg: 18, alternatives: ["Overhead Cable Extension", "Dips"]),
        PoolExercise("Overhead Cable Extension", .triceps, "Triceps", startWeightKg: 15, note: "Long-head stretch", alternatives: ["Rope Pushdown"]),
        PoolExercise("EZ Bar Skull Crusher", .triceps, "Triceps", minLevel: .intermediate, jointSensitive: true, startWeightKg: 15, note: "Deep elbow flexion under load — strong long-head stretch stimulus", alternatives: ["Overhead Cable Extension", "Close-Grip Barbell Bench Press"]),
        PoolExercise("Close-Grip Barbell Bench Press", .triceps, "Triceps", minLevel: .advanced, jointSensitive: true, startWeightKg: 30, note: "Hands just inside shoulder width, elbows tucked — a genuine compound triceps builder, not just an isolation exercise", alternatives: ["Dips", "EZ Bar Skull Crusher"]),
        PoolExercise("Dips", .triceps, "Triceps", minLevel: .intermediate, jointSensitive: true, startWeightKg: 0, alternatives: ["Rope Pushdown"]),

        // MARK: Calves
        PoolExercise("Standing Calf Raise", .calves, "Calves", startWeightKg: 30, alternatives: ["Seated Calf Raise"]),
        PoolExercise("Seated Calf Raise", .calves, "Calves", startWeightKg: 25, alternatives: ["Standing Calf Raise"]),
        PoolExercise("Single-Leg Calf Raise (bodyweight)", .calves, "Calves", startWeightKg: 0, note: "Per leg — off a step for full range", alternatives: ["Standing Calf Raise"]),

        // MARK: Core
        PoolExercise("Plank", .core, "Core", startWeightKg: 0, note: "Seconds", alternatives: ["Dead Bug", "Side Plank"]),
        PoolExercise("Dead Bug", .core, "Core", startWeightKg: 0, note: "Per side", alternatives: ["Plank"]),
        PoolExercise("Hanging Knee Raise", .core, "Core", startWeightKg: 0, alternatives: ["Cable Crunch"]),
        PoolExercise("Crunch", .core, "Core", startWeightKg: 0, note: "The plain crunch outperforms fancier-looking core moves (ab wheel, side plank, weighted plank) on direct rectus abdominis EMG — simple isn't the same as ineffective here", alternatives: ["Cable Crunch"]),
        PoolExercise("Cable Crunch", .core, "Core", startWeightKg: 25, note: "Loaded crunch pattern — same high rectus abdominis activation as a bodyweight crunch, progressively overloadable", alternatives: ["Crunch", "Hanging Knee Raise"]),
        PoolExercise("Ab Wheel Rollout", .core, "Core", minLevel: .intermediate, jointSensitive: true, startWeightKg: 0, note: "Trains anti-extension core stability under load — a different quality than crunch-pattern flexion work, not a higher-activation substitute for it", alternatives: ["Plank", "Dead Bug"]),
        PoolExercise("Side Plank", .core, "Core", startWeightKg: 0, note: "Seconds per side", alternatives: ["Plank"]),

        // MARK: Hip stability / glute activation — neuromuscular
        // injury-prevention work (Hewett/Myer ACL-injury-prevention
        // research), not an aesthetic or strength pattern. See
        // ProgramAssembler for where/why this gets inserted.
        PoolExercise("Banded Lateral Walk", .hipStability, "Glutes", startWeightKg: 0, note: "Band above knees, stay low", alternatives: ["Clamshell", "Monster Walk"]),
        PoolExercise("Clamshell", .hipStability, "Glutes", startWeightKg: 0, note: "Per side", alternatives: ["Banded Lateral Walk"]),
        PoolExercise("Monster Walk", .hipStability, "Glutes", startWeightKg: 0, note: "Band above ankles", alternatives: ["Banded Lateral Walk"]),

        // MARK: Cardio finisher (fat loss / endurance)
        PoolExercise("Mountain Climbers", .cardioFinisher, "Cardio", startWeightKg: 0, note: "Finisher — steady pace", alternatives: ["Jumping Jacks"]),
        PoolExercise("Battle Rope (or fast punches)", .cardioFinisher, "Cardio", startWeightKg: 0, note: "Finisher — seconds", alternatives: ["Jumping Jacks"]),
        PoolExercise("Kettlebell Swing (or fast squats)", .cardioFinisher, "Cardio", startWeightKg: 12, note: "Finisher", alternatives: ["Bodyweight Squat"]),
        PoolExercise("Jump Rope (or step-ups)", .cardioFinisher, "Cardio", startWeightKg: 0, note: "Finisher — seconds", alternatives: ["Step-Up"])
    ]
}
