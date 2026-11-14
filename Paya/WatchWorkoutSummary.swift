import SwiftUI

// MARK: - What the watch recorded
// When a workout ends on the watch it sends a short summary (duration, average
// heart rate, calories). The phone keeps the last few and shows the matching one
// on the post-workout screen, so the watch's measurements are visible where you
// actually review the session.

struct WatchWorkoutSummary: Codable, Identifiable {
    var id = UUID()
    var kind: String
    var start: Date
    var end: Date
    var durationSec: Double
    var avgHR: Int?
    var activeKcal: Int
    var totalKcal: Int
}

extension Notification.Name {
    static let watchWorkoutSummaryStored = Notification.Name("paya.watchWorkoutSummaryStored")
}

enum WatchWorkoutSummaryStore {
    private static let key = "paya_watch_workout_summaries"
    private static let cap = 30

    static func all() -> [WatchWorkoutSummary] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([WatchWorkoutSummary].self, from: data) else { return [] }
        return items
    }

    static func add(from message: [String: Any]) {
        guard let start = message["start"] as? Date, let end = message["end"] as? Date else { return }
        let item = WatchWorkoutSummary(
            kind: message["kind"] as? String ?? "other",
            start: start, end: end,
            durationSec: message["durationSec"] as? Double ?? end.timeIntervalSince(start),
            avgHR: message["avgHR"] as? Int,
            activeKcal: message["activeKcal"] as? Int ?? 0,
            totalKcal: message["totalKcal"] as? Int ?? 0
        )
        var items = all()
        items.removeAll { abs($0.start.timeIntervalSince(start)) < 5 }   // de-dupe retries
        items.append(item)
        if items.count > cap { items.removeFirst(items.count - cap) }
        if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: key) }
        NotificationCenter.default.post(name: .watchWorkoutSummaryStored, object: nil)
    }

    /// The watch workout that overlaps this Paya session (starts within 20 min of it).
    static func match(sessionStart: Date, durationMinutes: Int) -> WatchWorkoutSummary? {
        let end = sessionStart.addingTimeInterval(Double(max(durationMinutes, 1)) * 60)
        return all().last { s in
            abs(s.start.timeIntervalSince(sessionStart)) < 20 * 60
                || (s.start <= end && s.end >= sessionStart)
        }
    }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}

struct WatchRecordedCard: View {
    let sessionStart: Date
    let durationMinutes: Int
    @State private var summary: WatchWorkoutSummary?

    var body: some View {
        Group {
            if let s = summary {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "applewatch").foregroundColor(Pulse.recovery)
                        Text("Recorded by your Apple Watch")
                            .font(.pulse(size: 13, weight: .bold))
                            .foregroundColor(Pulse.textPrimary)
                        Spacer()
                    }
                    HStack(spacing: 0) {
                        stat(clock(s.durationSec), "Time", Pulse.warning)
                        stat(s.avgHR.map(String.init) ?? "—", "Avg BPM", Pulse.vitals)
                        stat("\(s.activeKcal)", "Active cal", Pulse.energy)
                        stat("\(s.totalKcal)", "Total cal", Pulse.energy)
                    }
                    Text("Calories and heart rate are Apple Watch estimates and are saved to Apple Health.")
                        .font(.pulse(size: 11))
                        .foregroundColor(Pulse.textTertiary)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: Pulse.Radius.md).fill(Pulse.surfaceFallback))
            }
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: .watchWorkoutSummaryStored)) { _ in refresh() }
    }

    private func refresh() {
        summary = WatchWorkoutSummaryStore.match(sessionStart: sessionStart, durationMinutes: durationMinutes)
    }

    private func clock(_ t: Double) -> String {
        let s = max(0, Int(t))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
                         : String(format: "%d:%02d", s / 60, s % 60)
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.pulse(size: 20, weight: .bold, design: .rounded)).foregroundColor(color).monospacedDigit()
            Text(label).font(.pulse(size: 11)).foregroundColor(Pulse.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
