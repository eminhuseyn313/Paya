import ActivityKit
import Foundation

// MARK: - Live Activity contract
// Mirrors PayaSessionActivityAttributes in the main Paya app target — same
// cross-target duplication convention already used for the widget snapshot
// (see RecoveryWidget.swift's PayaWidgetSnapshot comment).

struct PayaSessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var setLabel: String
        var exerciseProgress: String
        var restEndDate: Date?
        var restTotalSeconds: Int?
        /// Current set's weight — shown in the notification so the user can
        /// verify what they entered without unlocking.
        var weightKg: Double?
        /// Current set's rep count.
        var reps: Int?
        /// Exercise measurement type (e.g. "weightedReps", "bodyweightReps",
        /// "timed") — determines whether to show the weight field.
        var measurementRaw: String?
    }

    var sessionLabel: String
    var colorHex: String
}
