import Foundation

// MARK: - Exercise Measurement
//
// Not every exercise is logged the same way: a barbell bench press is
// weight × reps, a push-up is reps only (no meaningful weight to enter),
// and a plank is a duration held, not reps at all. Before this, every
// exercise in the app — generated, hand-authored, or displayed in a
// session — got the same weight+reps input regardless of what kind of
// movement it actually is, so a plank showed an editable "0.0 kg" weight
// field that meant nothing, and its rep range (e.g. 30-45) was silently
// reused to mean seconds with no UI indication of that.
//
// This infers the right measurement from the exercise's own name and
// starting weight — no schema change, no new stored field anywhere, so it
// works retroactively across the entire existing exercise catalogue,
// generated programs, and already-installed custom sessions.
enum ExerciseMeasurement: String {
    case weightedReps       // barbell/dumbbell/machine/cable — weight + reps
    case bodyweightReps     // push-up, pull-up, bodyweight squat — reps only, no weight
    case timed              // plank, wall sit, dead hang — duration held, not reps

    /// Exercises logged as time-under-tension rather than reps. Matched on
    /// name since that's reliable across every layer (pool entries,
    /// hand-authored templates, installed custom sessions) without needing
    /// a stored field anywhere.
    private static let timedKeywords = ["plank", "wall sit", "dead hang", "farmer's walk", "farmers walk"]

    static func infer(name: String, startWeightKg: Double) -> ExerciseMeasurement {
        let n = name.lowercased()
        if timedKeywords.contains(where: { n.contains($0) }) { return .timed }
        return startWeightKg > 0 ? .weightedReps : .bodyweightReps
    }

    var showsWeightField: Bool { self == .weightedReps }

    var secondaryUnitLabel: String {
        switch self {
        case .weightedReps: return "reps"
        case .bodyweightReps: return "reps"
        case .timed: return "sec"
        }
    }
}

// MARK: - Assisted Exercise Detection
//
// Assisted exercises (assisted pull-up, assisted dip, gravitron, etc.)
// have INVERTED weight logic: the weight entered is the assistance
// provided — less weight means HARDER, not easier. Progressive overload
// means REDUCING the weight over time, the exact opposite of standard
// exercises.
//
// This matters for:
// - Progression suggestions (suggest lower weight when all sets hit target)
// - PR detection (a lower e1RM is actually better)
// - Volume calculations (assistance weight shouldn't count as load)
// - UI labels ("Assistance" instead of "Weight")

enum AssistedExerciseDetector {

    private static let assistedKeywords = [
        "assisted pull-up", "assisted pull up", "assisted pullup",
        "assisted dip", "assisted chin-up", "assisted chin up",
        "gravitron", "band-assisted", "band assisted",
        "machine-assisted", "machine assisted",
    ]

    /// True when the exercise uses inverted weight logic (less = harder).
    static func isAssisted(name: String) -> Bool {
        let n = name.lowercased()
        return assistedKeywords.contains(where: { n.contains($0) })
    }

    /// For assisted exercises, "progressive overload" means reducing
    /// assistance weight. Returns a negative increment (e.g. −2.5 kg).
    static func progressionIncrement(for repRange: RepRange) -> Double {
        return -repRange.increment
    }
}
