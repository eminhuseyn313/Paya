import SwiftUI

// MARK: - Apple Watch report
// Shows how the watch is actually performing for this user: sets logged from
// the wrist, how often auto-detected reps matched what they logged, and heart-
// rate recovery between sets. Honest by construction: empty until there is
// real watch data, and small samples are flagged.

struct WatchReportCard: View {
    private var events: [WatchSetEvent] { WatchTelemetryStore.recent(days: 30) }

    private var detected: [WatchSetEvent] { events.filter { $0.detectedReps != nil } }
    private var exact: Int { detected.filter { $0.detectedReps == $0.loggedReps }.count }
    private var within1: Int { detected.filter { abs(($0.detectedReps ?? 0) - $0.loggedReps) <= 1 }.count }

    private var recoveries: [WatchSetEvent] { events.filter { ($0.hrRecovery ?? 0) > 0 } }
    private var avgRecovery: Int? {
        guard !recoveries.isEmpty else { return nil }
        return Int((Double(recoveries.compactMap(\.hrRecovery).reduce(0, +)) / Double(recoveries.count)).rounded())
    }

    private var recoveryByExercise: [(name: String, avg: Int, n: Int)] {
        Dictionary(grouping: recoveries, by: \.exerciseName)
            .compactMap { name, evs -> (String, Int, Int)? in
                guard evs.count >= 3 else { return nil }
                let avg = Double(evs.compactMap(\.hrRecovery).reduce(0, +)) / Double(evs.count)
                return (name, Int(avg.rounded()), evs.count)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(4)
            .map { (name: $0.0, avg: $0.1, n: $0.2) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "applewatch").foregroundColor(Pulse.recovery)
                Text("Apple Watch · last 30 days")
                    .font(.pulse(size: 13, weight: .bold))
                    .foregroundColor(Pulse.textPrimary)
                Spacer()
            }

            if events.isEmpty {
                Text("No sets logged from your watch yet. Log a few during a Paya session and this fills in with how well auto-detect and heart-rate recovery are working for you.")
                    .font(.pulse(size: 12))
                    .foregroundColor(Pulse.textSecondary)
            } else {
                row("Sets logged from watch", "\(events.count)")

                if detected.isEmpty {
                    row("Auto-detect suggestions", "none yet")
                } else {
                    row("Auto-detect suggestions", "\(detected.count)")
                    row("Rep count exactly right", "\(Int((Double(exact) / Double(detected.count) * 100).rounded()))%")
                    row("Within ±1 rep", "\(Int((Double(within1) / Double(detected.count) * 100).rounded()))%")
                    if WatchTelemetryStore.repOffset != 0 {
                        let o = WatchTelemetryStore.repOffset
                        row("Personal calibration", "\(o > 0 ? "+" : "")\(o) rep")
                        Text("Auto-detect was consistently off in one direction for you, so its suggestions are shifted. Based on your last logged sets.")
                            .font(.pulse(size: 11)).foregroundColor(Pulse.textTertiary)
                    } else if WatchTelemetryStore.calibrationSamples() < WatchTelemetryStore.minSamples {
                        Text("Calibrating: after \(WatchTelemetryStore.minSamples) detected sets Paya checks whether auto-detect is consistently off for you and corrects it.")
                            .font(.pulse(size: 11)).foregroundColor(Pulse.textTertiary)
                    }
                    if detected.count < 10 {
                        Text("Small sample (\(detected.count)) — treat these percentages as rough.")
                            .font(.pulse(size: 11)).foregroundColor(Pulse.textTertiary)
                    }
                }

                if let avg = avgRecovery {
                    row("Avg heart-rate drop in rest", "−\(avg) bpm")
                    ForEach(recoveryByExercise, id: \.name) { item in
                        HStack {
                            Text(item.name).font(.pulse(size: 12)).foregroundColor(Pulse.textSecondary).lineLimit(1)
                            Spacer()
                            Text("−\(item.avg) bpm · \(item.n) sets")
                                .font(.pulse(size: 12, weight: .semibold)).foregroundColor(Pulse.textPrimary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Pulse.Radius.md).fill(Pulse.surface))
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.pulse(size: 12)).foregroundColor(Pulse.textSecondary)
            Spacer()
            Text(value).font(.pulse(size: 13, weight: .bold)).foregroundColor(Pulse.textPrimary)
        }
    }
}
