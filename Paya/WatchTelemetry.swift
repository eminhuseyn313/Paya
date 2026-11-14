import Foundation

// MARK: - Watch telemetry
// A small on-device log of sets logged from the Apple Watch: what the
// watch's auto-detection suggested vs what the user actually logged, and the
// heart-rate recovery measured during the preceding rest. Powers the
// "Apple Watch" report so detection accuracy can be judged on real lifts.
// Stored locally only (capped), wiped on sign-out with the rest of local data.

struct WatchSetEvent: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var exerciseName: String
    var loggedReps: Int
    var detectedReps: Int?     // nil when auto-detect made no suggestion
    var hrRecovery: Int?       // bpm drop from the previous set's peak by the time this set started
}

enum WatchTelemetryStore {
    static let key = "paya_watch_set_events"
    private static let cap = 600

    static func all() -> [WatchSetEvent] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let events = try? JSONDecoder().decode([WatchSetEvent].self, from: data) else { return [] }
        return events
    }

    static func append(_ event: WatchSetEvent) {
        var events = all()
        events.append(event)
        if events.count > cap { events.removeFirst(events.count - cap) }
        if let data = try? JSONEncoder().encode(events) { UserDefaults.standard.set(data, forKey: key) }
        UserDefaults.standard.set(computeRepOffset(events), forKey: offsetKey)
    }

    // MARK: Personal calibration
    // If auto-detect is consistently off in the same direction for THIS user
    // (e.g. always counts one rep too many), shift its suggestions by that
    // amount. Needs ≥15 detected sets, a mean error of at least 0.6 rep, and the
    // error to lean the same way in ≥60 % of sets; capped at ±2. Always
    // computed from the raw detector output, so it can't compound on itself.
    static let offsetKey = "paya_watch_rep_offset"
    static let minSamples = 15

    static var repOffset: Int { UserDefaults.standard.integer(forKey: offsetKey) }

    static func calibrationSamples() -> Int { all().filter { $0.detectedReps != nil }.count }

    static func computeRepOffset(_ events: [WatchSetEvent]) -> Int {
        let errors = events.compactMap { e in e.detectedReps.map { $0 - e.loggedReps } }.suffix(60)
        guard errors.count >= minSamples else { return 0 }
        let mean = Double(errors.reduce(0, +)) / Double(errors.count)
        guard abs(mean) >= 0.6 else { return 0 }
        let sameSign = errors.filter { mean > 0 ? $0 > 0 : $0 < 0 }.count
        guard Double(sameSign) / Double(errors.count) >= 0.6 else { return 0 }
        return max(-2, min(2, -Int(mean.rounded())))
    }

    static func recent(days: Int) -> [WatchSetEvent] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .distantPast
        return all().filter { $0.date >= cutoff }
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
