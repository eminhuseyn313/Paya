import WidgetKit
import SwiftUI

// MARK: - Readiness Complication
//
// Glanceable readiness score right on the watch face — no app open. The
// watch app has never had a complication despite the whole app existing;
// this was the single most-requested "watchOS-native" gap (see Whoop/Oura,
// which both lead with exactly this). Reads from an App Group snapshot the
// watch app writes on every WatchConnectivity update from the phone — see
// ComplicationSnapshotWriter.swift in the watch app target.

// Mirrors ComplicationSnapshotWriter.WatchComplicationSnapshot in the watch
// app target. Duplicated rather than shared across targets — same call as
// PayaWidgets' RecoveryWidget.swift made for the phone widget: this
// project's file-system-synchronized target groups make cross-target file
// membership more fragile than a small, deliberately-duplicated contract.
struct WatchComplicationSnapshot: Codable {
    var readinessScore: Int?
    var readinessBand: String?
    var sessionLabel: String?
    var waterMl: Int
    var waterTargetMl: Int
    var updatedAt: Date
}

struct ReadinessEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchComplicationSnapshot?
}

struct ReadinessProvider: TimelineProvider {
    static let appGroupId = "group.Paya.Paya.shared"
    static let snapshotKey = "watch_complication_snapshot"

    func placeholder(in context: Context) -> ReadinessEntry {
        ReadinessEntry(date: .now, snapshot: WatchComplicationSnapshot(
            readinessScore: 78, readinessBand: "Steady", sessionLabel: "Push Day",
            waterMl: 1200, waterTargetMl: 2500, updatedAt: .now
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadinessEntry) -> Void) {
        completion(ReadinessEntry(date: .now, snapshot: loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadinessEntry>) -> Void) {
        let entry = ReadinessEntry(date: .now, snapshot: loadSnapshot())
        // The watch app pushes a fresh snapshot + WidgetCenter reload on
        // every WatchConnectivity update, so this scheduled refresh is a
        // backstop for when the phone hasn't been reachable in a while —
        // not the primary update path.
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadSnapshot() -> WatchComplicationSnapshot? {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId),
              let data = defaults.data(forKey: Self.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WatchComplicationSnapshot.self, from: data)
    }
}

// MARK: - Views

private func bandColor(_ band: String?) -> Color {
    switch band?.lowercased() {
    case "primed":  return .green
    case "steady":  return .mint
    case "caution": return .orange
    case "recover": return .red
    default:        return .gray
    }
}

struct ReadinessComplicationView: View {
    var entry: ReadinessEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if let snapshot = entry.snapshot, let score = snapshot.readinessScore {
            switch family {
            case .accessoryCircular:
                circular(score: score, band: snapshot.readinessBand)
            case .accessoryRectangular:
                rectangular(snapshot: snapshot, score: score)
            case .accessoryInline:
                Text("Readiness \(score)\(snapshot.sessionLabel.map { " · \($0)" } ?? "")")
            case .accessoryCorner:
                Text("\(score)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(bandColor(snapshot.readinessBand))
                    .widgetLabel {
                        Gauge(value: Double(score), in: 0...100) { }
                            .tint(bandColor(snapshot.readinessBand))
                    }
            @unknown default:
                Text("\(score)")
            }
        } else {
            Text("—")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func circular(score: Int, band: String?) -> some View {
        Gauge(value: Double(score), in: 0...100) {
            Image(systemName: "bolt.heart.fill")
        } currentValueLabel: {
            Text("\(score)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
        .tint(bandColor(band))
    }

    private func rectangular(snapshot: WatchComplicationSnapshot, score: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("READINESS")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(score)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                if let band = snapshot.readinessBand {
                    Text(band)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(bandColor(band))
                }
            }
            if let label = snapshot.sessionLabel {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

struct ReadinessComplication: Widget {
    let kind: String = "PayaReadinessComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadinessProvider()) { entry in
            ReadinessComplicationView(entry: entry)
        }
        .configurationDisplayName("Readiness")
        .description("Your recovery-baseline readiness score, right on your watch face.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
