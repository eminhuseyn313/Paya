import Foundation

// MARK: - Cable Variant Tracker
//
// Cable machines are the single most variable equipment in a gym — the
// same exercise name ("cable curl", "tricep pushdown") can be performed
// with different attachments (rope, straight bar, V-bar, EZ bar,
// D-handle) and at different pulley heights (high, mid, low). These
// variants meaningfully change the movement: a rope pushdown and a
// straight-bar pushdown hit different portions of the tricep, and the
// EMG activation patterns differ (Kholinne et al., Orthop J Sports Med,
// 2018). Tracking which variant the user performed lets progressive
// overload comparisons stay apples-to-apples — a PR on rope pushdowns
// shouldn't compare against straight-bar pushdown history.

// MARK: - Cable Attachment

enum CableAttachment: String, CaseIterable, Identifiable {
    case rope          = "rope"
    case straightBar   = "straight_bar"
    case ezBar         = "ez_bar"
    case vBar          = "v_bar"
    case dHandle       = "d_handle"
    case wideGripBar   = "wide_grip_bar"
    case ankleStrap    = "ankle_strap"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rope:        return "Rope"
        case .straightBar: return "Straight Bar"
        case .ezBar:       return "EZ Bar"
        case .vBar:        return "V-Bar"
        case .dHandle:     return "D-Handle"
        case .wideGripBar: return "Wide Grip Bar"
        case .ankleStrap:  return "Ankle Strap"
        }
    }

    var icon: String {
        switch self {
        case .rope:        return "line.3.crossed.swirl.circle"
        case .straightBar: return "minus"
        case .ezBar:       return "wave.3.right"
        case .vBar:        return "chevron.down"
        case .dHandle:     return "hand.raised.fill"
        case .wideGripBar: return "arrow.left.and.right"
        case .ankleStrap:  return "figure.walk"
        }
    }

    /// Default attachment for exercises whose name implies a specific one.
    static func infer(from exerciseName: String) -> CableAttachment? {
        let lower = exerciseName.lowercased()
        if lower.contains("rope")       { return .rope }
        if lower.contains("v-bar") || lower.contains("v bar") { return .vBar }
        if lower.contains("ez bar") || lower.contains("ez-bar") { return .ezBar }
        if lower.contains("d-handle") || lower.contains("single arm") || lower.contains("one arm") { return .dHandle }
        return nil
    }
}

// MARK: - Cable Position

enum CablePosition: String, CaseIterable, Identifiable {
    case high = "high"
    case mid  = "mid"
    case low  = "low"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .high: return "High"
        case .mid:  return "Mid"
        case .low:  return "Low"
        }
    }

    var icon: String {
        switch self {
        case .high: return "arrow.up"
        case .mid:  return "arrow.left.and.right"
        case .low:  return "arrow.down"
        }
    }

    /// Default position for exercises whose name implies it.
    static func infer(from exerciseName: String) -> CablePosition? {
        let lower = exerciseName.lowercased()
        // Pushdowns / crossovers are typically high cable
        if lower.contains("pushdown") || lower.contains("push down") { return .high }
        if lower.contains("crossover") { return .high }
        if lower.contains("face pull") { return .high }
        // Curls from low, rows from low/mid
        if lower.contains("curl") && lower.contains("cable") { return .low }
        if lower.contains("upright row") { return .low }
        // Cable lateral raise is usually low
        if lower.contains("lateral raise") { return .low }
        return nil
    }
}

// MARK: - Cable Exercise Detection

enum CableExerciseDetector {

    /// Keywords that indicate a cable exercise. Covers the common naming
    /// patterns in the exercise library and user-entered custom exercises.
    private static let cableKeywords: [String] = [
        "cable",
        "pushdown", "push down",
        "rope pushdown", "rope extension",
        "cable fly", "cable crossover",
        "face pull",
        "lat pulldown",   // technically a cable machine
    ]

    /// Returns true if the exercise is (or is likely) a cable machine exercise.
    static func isCableExercise(name: String) -> Bool {
        let lower = name.lowercased()
        return cableKeywords.contains { lower.contains($0) }
    }
}
