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
    }

    var sessionLabel: String
    var colorHex: String
}
