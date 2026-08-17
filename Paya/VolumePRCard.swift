import SwiftUI

struct VolumePRCard: View {

    @Environment(AppState.self) private var appState
    var sessions: [TrainingSession]

    @State private var volumePRs: [VolumePR] = []
    @State private var expanded = false

    private var useLbs: Bool { appState.profile.prefersLbs }

    var body: some View {
        Group {
            if !volumePRs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "chart.bar.doc.horizontal.fill")
                            .foregroundColor(Pulse.ai)
                        Text("Volume PRs")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        let recentCount = volumePRs.filter(\.isRecent).count
                        if recentCount > 0 {
                            Text("\(recentCount) NEW")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Pulse.ai)
                                .clipShape(Capsule())
                        }
                    }

                    Text("Highest single-session volume per exercise — total weight × reps across all sets.")
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)

                    let visible = expanded ? volumePRs : Array(volumePRs.prefix(5))
                    ForEach(visible) { pr in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(pr.isRecent
                                        ? Pulse.ai.opacity(0.15)
                                        : Pulse.surfaceElevatedFallback)
                                    .frame(width: 28, height: 28)
                                Image(systemName: pr.isRecent ? "star.fill" : "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(pr.isRecent ? Pulse.ai : .secondary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(pr.exerciseName)
                                        .font(.system(size: 12, weight: .semibold))
                                        .lineLimit(1)
                                    if pr.isRecent {
                                        Text("NEW")
                                            .font(.system(size: 7, weight: .heavy))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Pulse.ai)
                                            .clipShape(Capsule())
                                    }
                                }
                                Text(pr.dateLabel)
                                    .font(.system(size: 9))
                                    .foregroundColor(Pulse.textTertiary)
                            }

                            Spacer()

                            let vol = useLbs ? pr.volumeKg * 2.20462 : pr.volumeKg
                            Text(vol >= 1000
                                ? String(format: "%.1f%@", vol / 1000, useLbs ? "klbs" : "t")
                                : String(format: "%.0f %@", vol, useLbs ? "lbs" : "kg"))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(Pulse.ai)
                        }
                        .padding(.vertical, 2)
                    }

                    if volumePRs.count > 5 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                        } label: {
                            Text(expanded ? "Show less" : "Show all \(volumePRs.count)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Pulse.ai)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PulsePress())
                    }
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func compute() {
        let completed = sessions.filter(\.isCompleted)
        var bestVolume: [String: (volume: Double, date: Date)] = [:]

        for session in completed {
            for log in session.exercises {
                let vol = log.sets.filter(\.isCompleted)
                    .reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
                guard vol > 0 else { continue }
                if let existing = bestVolume[log.exerciseName] {
                    if vol > existing.volume {
                        bestVolume[log.exerciseName] = (vol, session.date)
                    }
                } else {
                    bestVolume[log.exerciseName] = (vol, session.date)
                }
            }
        }

        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        volumePRs = bestVolume
            .map { name, data in
                VolumePR(
                    exerciseName: name,
                    volumeKg: data.volume,
                    date: data.date,
                    dateLabel: formatter.string(from: data.date),
                    isRecent: data.date >= sevenDaysAgo
                )
            }
            .sorted { $0.volumeKg > $1.volumeKg }
            .prefix(15)
            .map { $0 }
    }
}

private struct VolumePR: Identifiable {
    let exerciseName: String
    let volumeKg: Double
    let date: Date
    let dateLabel: String
    let isRecent: Bool
    var id: String { exerciseName }
}
