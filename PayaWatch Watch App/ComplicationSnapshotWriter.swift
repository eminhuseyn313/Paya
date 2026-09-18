import Foundation
import WidgetKit

// MARK: - Complication Snapshot Writer
//
// Watch complications run in a separate process (a WidgetKit extension) —
// they can't read WatchConnectivityManager's in-memory @Observable state
// directly. Same pattern as WidgetSnapshotWriter on the phone side: whenever
// the watch app receives fresh data from the phone, mirror the pieces a
// complication needs into an App Group UserDefaults suite, then ask
// WidgetKit to refresh. The complication's own TimelineProvider reads from
// that suite — see PayaWatchComplications/ReadinessComplication.swift.

struct WatchComplicationSnapshot: Codable {
    var readinessScore: Int?
    var readinessBand: String?
    /// The active/next session's label, pushed from the phone's
    /// TrainingDayStore — empty on a rest day.
    var sessionLabel: String?
    var waterMl: Int
    var waterTargetMl: Int
    var updatedAt: Date
}

enum ComplicationSnapshotWriter {
    static let appGroupId = "group.Paya.Paya.shared"
    static let snapshotKey = "watch_complication_snapshot"

    static func write(
        readinessScore: Int?,
        readinessBand: String?,
        sessionLabel: String?,
        waterMl: Int,
        waterTargetMl: Int
    ) {
        let snapshot = WatchComplicationSnapshot(
            readinessScore: readinessScore,
            readinessBand: readinessBand,
            sessionLabel: sessionLabel,
            waterMl: waterMl,
            waterTargetMl: waterTargetMl,
            updatedAt: .now
        )
        guard let defaults = UserDefaults(suiteName: appGroupId),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
