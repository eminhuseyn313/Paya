import Foundation

// MARK: - Personalization Inputs

enum ExperienceLevel: String, CaseIterable, Codable, Identifiable {
    case beginner, intermediate, advanced

    var id: String { rawValue }

    var tier: ProgramTier {
        switch self {
        case .beginner: return .beginner
        case .intermediate: return .intermediate
        case .advanced: return .advanced
        }
    }

    var displayName: String {
        switch self {
        case .beginner: return "New to training"
        case .intermediate: return "1–3 years consistent"
        case .advanced: return "3+ years consistent"
        }
    }

    /// Starting-weight scalar relative to the intermediate baseline the
    /// program templates were authored against.
    var weightScalar: Double {
        switch self {
        case .beginner: return 0.7
        case .intermediate: return 1.0
        case .advanced: return 1.25
        }
    }
}

enum EquipmentAccess: String, CaseIterable, Codable, Identifiable {
    case fullGym, homeDumbbells, bodyweightOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullGym: return "Full gym"
        case .homeDumbbells: return "Dumbbells at home"
        case .bodyweightOnly: return "Bodyweight only"
        }
    }

    var subtitle: String {
        switch self {
        case .fullGym: return "Machines, cables, barbells, everything"
        case .homeDumbbells: return "Dumbbells (and maybe a bench), no machines"
        case .bodyweightOnly: return "No equipment at all"
        }
    }

    var icon: String {
        switch self {
        case .fullGym: return "building.2.fill"
        case .homeDumbbells: return "dumbbell.fill"
        case .bodyweightOnly: return "figure.strengthtraining.functional"
        }
    }
}

enum DietPreference: String, CaseIterable, Codable, Identifiable {
    case omnivore, vegetarian, vegan, pescatarian

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .omnivore: return "No restrictions"
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .pescatarian: return "Pescatarian"
        }
    }

    var subtitle: String {
        switch self {
        case .omnivore: return "Eats everything"
        case .vegetarian: return "No meat or fish"
        case .vegan: return "No animal products at all"
        case .pescatarian: return "Fish, no other meat"
        }
    }
}

enum MusclePriority: String, CaseIterable, Codable, Identifiable {
    case none, chest, back, shoulders, legs, arms

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "No particular focus"
        case .chest: return "Chest"
        case .back: return "Back"
        case .shoulders: return "Shoulders"
        case .legs: return "Legs"
        case .arms: return "Arms"
        }
    }

    /// The extra pattern slot added on top of the day's normal coverage —
    /// only for hypertrophy, and only one per day, so "focus" means a
    /// bigger share of an already-sane session instead of tacking on more
    /// exercises than a real session should run.
    var bonusPattern: MovementPattern? {
        switch self {
        case .none: return nil
        case .chest: return .horizontalPush
        case .back: return .horizontalPull
        case .shoulders: return .sideDelt
        case .legs: return .squat
        case .arms: return .biceps
        }
    }
}

enum InjuryArea: String, CaseIterable, Codable, Identifiable {
    case shoulder, lowerBack, knee, wrist, elbow, hip

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shoulder: return "Shoulder"
        case .lowerBack: return "Lower back"
        case .knee: return "Knee"
        case .wrist: return "Wrist"
        case .elbow: return "Elbow"
        case .hip: return "Hip"
        }
    }

    /// Keywords used to flag a template exercise as risky for this area.
    var riskyKeywords: [String] {
        switch self {
        case .shoulder: return ["overhead", "shoulder press", "lateral raise", "dip", "upright row"]
        case .lowerBack: return ["deadlift", "good morning", "back extension", "bent-over", "row"]
        case .knee: return ["squat", "lunge", "leg press", "leg extension", "split squat", "step-up"]
        case .wrist: return ["push-up", "front squat", "curl", "press"]
        case .elbow: return ["curl", "pushdown", "extension", "close-grip"]
        case .hip: return ["hip thrust", "lunge", "split squat", "deadlift", "squat"]
        }
    }
}

// MARK: - Equipment classification

enum ExerciseEquipmentTag {
    case machine, cable, barbell, dumbbell, bodyweight, kettlebell, band

    var worksWithDumbbellsAtHome: Bool {
        self == .dumbbell || self == .bodyweight || self == .kettlebell || self == .band
    }

    var worksBodyweightOnly: Bool { self == .bodyweight }

    static func classify(_ name: String) -> ExerciseEquipmentTag {
        let n = name.lowercased()
        if n.contains("assisted pull-up") { return .machine }
        if n.contains("push-up") || n.contains("plank") || n.contains("dead bug") || n.contains("glute bridge")
            || n.contains("bodyweight") || n.contains("walking lunge") || n.contains("jumping")
            || n.contains("mountain climb") || n.contains("burpee") || n.contains("dip")
            || n.contains("hanging knee raise") || n.contains("side plank") || n.contains("inverted row")
            || n.contains("chin-up") || n.contains("nordic") || n.contains("ab wheel")
            || (n.contains("crunch") && !n.contains("cable"))
            || (n.contains("pull-up") && !n.contains("assisted")) {
            return .bodyweight
        }
        if n.contains("kettlebell") { return .kettlebell }
        if n.contains("band") { return .band }
        if n.contains("cable") || n.contains("pulldown") || n.contains("pushdown") || n.contains("face pull") {
            return .cable
        }
        if n.contains("machine") || n.contains("leg press") || n.contains("hack squat")
            || n.contains("pec deck") || n.contains("smith") || n.contains("leg curl")
            || n.contains("leg extension") || n.contains("assisted pull-up") {
            return .machine
        }
        if n.contains("barbell") || n.contains("trap bar") || (n.contains("hip thrust") && !n.contains("machine")) {
            return .barbell
        }
        if n.contains("db ") || n.contains(" db") || n.contains("dumbbell") {
            return .dumbbell
        }
        // Unclear equipment — assume it needs gym infrastructure (safe default).
        return .machine
    }
}

// MARK: - Personalization Engine

enum PersonalizationEngine {

    /// Picks the exercise variant (original name or one of its listed
    /// alternatives) that best fits the profile's equipment access.
    static func fitExerciseName(
        original: String,
        alternatives: [String],
        equipment: EquipmentAccess
    ) -> String {
        let originalTag = ExerciseEquipmentTag.classify(original)
        if fits(originalTag, equipment: equipment) { return original }

        for alt in alternatives {
            let tag = ExerciseEquipmentTag.classify(alt)
            if fits(tag, equipment: equipment) { return alt }
        }
        // Nothing fits perfectly — keep the original rather than guess wrong.
        return original
    }

    private static func fits(_ tag: ExerciseEquipmentTag, equipment: EquipmentAccess) -> Bool {
        switch equipment {
        case .fullGym: return true
        case .homeDumbbells: return tag.worksWithDumbbellsAtHome
        case .bodyweightOnly: return tag.worksBodyweightOnly
        }
    }

    /// True if any of the profile's flagged injury areas has a keyword match
    /// against this exercise name — used to prefer swapping toward an
    /// alternative, not to hard-block (the app isn't a medical device).
    static func isRisky(_ name: String, for injuries: Set<InjuryArea>) -> Bool {
        let n = name.lowercased()
        return injuries.contains { area in
            area.riskyKeywords.contains { n.contains($0) }
        }
    }

    /// Prefers an alternative that avoids the flagged injury areas, if one exists.
    static func safestExerciseName(
        original: String,
        alternatives: [String],
        injuries: Set<InjuryArea>
    ) -> String {
        guard !injuries.isEmpty, isRisky(original, for: injuries) else { return original }
        if let safe = alternatives.first(where: { !isRisky($0, for: injuries) }) {
            return safe
        }
        return original
    }

    /// Scales a template's authored starting weight to the individual —
    /// templates assume an ~85kg intermediate male lifter as baseline.
    static func personalizedStartWeight(
        templateWeightKg: Double,
        bodyWeightKg: Double,
        sexRaw: String,
        experience: ExperienceLevel
    ) -> Double {
        guard templateWeightKg > 0 else { return 0 }   // bodyweight exercises stay 0

        let bodyWeightFactor = min(1.6, max(0.55, bodyWeightKg / 85.0))
        // Miller AE, MacDougall JD, Tarnopolsky MA, Sale DG. "Gender
        // differences in strength and muscle fiber characteristics."
        // Eur J Appl Physiol Occup Physiol. 1993 — found untrained women's
        // absolute strength at roughly 52-63% of men's depending on the
        // muscle group tested. 0.65 is a single flat approximation blending
        // that range across all exercises, not a muscle-group-specific
        // figure from the paper.
        let sexFactor = sexRaw.lowercased() == "female" ? 0.65 : 1.0
        let raw = templateWeightKg * bodyWeightFactor * sexFactor * experience.weightScalar

        // Round to a realistic loadable increment.
        let increment: Double = raw < 20 ? 1.25 : 2.5
        return (raw / increment).rounded() * increment
    }
}
