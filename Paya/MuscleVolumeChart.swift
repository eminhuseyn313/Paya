import SwiftUI
import Charts

struct MuscleVolumeChart: View {

    @Environment(AppState.self) private var appState
    var sessions: [TrainingSession]

    @State private var data: [MuscleVolume] = []

    private var useLbs: Bool { appState.profile.prefersLbs }

    var body: some View {
        Group {
            if !data.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundColor(Color(hex: "8B5CF6"))
                        Text("Volume by Muscle (4 wk)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }

                    Chart(data) { item in
                        BarMark(
                            x: .value("Volume", useLbs ? item.volumeKg * 2.20462 : item.volumeKg),
                            y: .value("Muscle", item.muscle)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "8B5CF6"), Color(hex: "2563EB")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .cornerRadius(4)
                    }
                    .frame(height: CGFloat(data.count) * 28 + 10)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) {
                            AxisValueLabel()
                                .font(.system(size: 8))
                        }
                    }
                    .chartYAxis {
                        AxisMarks {
                            AxisValueLabel()
                                .font(.system(size: 9))
                        }
                    }

                    HStack(spacing: 12) {
                        let totalVol = data.reduce(0.0) { $0 + $1.volumeKg }
                        let displayTotal = useLbs ? totalVol * 2.20462 : totalVol
                        miniStat(label: "Total", value: displayTotal >= 1000
                            ? String(format: "%.1f%@", displayTotal / 1000, useLbs ? "klbs" : "t")
                            : String(format: "%.0f %@", displayTotal, useLbs ? "lbs" : "kg"))
                        miniStat(label: "Top muscle", value: data.first?.muscle ?? "—")
                        miniStat(label: "Groups", value: "\(data.count)")
                    }
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
    }

    private func compute() {
        let calendar = Calendar.current
        let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: Date())!
        let recent = sessions.filter { $0.isCompleted && $0.date >= fourWeeksAgo }

        var muscleVolume: [String: Double] = [:]
        for session in recent {
            for log in session.exercises {
                let group = log.muscleGroup
                guard !group.isEmpty else { continue }
                let vol = log.sets.filter(\.isCompleted)
                    .reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
                muscleVolume[group, default: 0] += vol
            }
        }

        data = muscleVolume
            .map { MuscleVolume(muscle: $0.key, volumeKg: $0.value) }
            .sorted { $0.volumeKg > $1.volumeKg }
            .prefix(10)
            .reversed()
            .map { $0 }
    }
}

private struct MuscleVolume: Identifiable {
    let muscle: String
    let volumeKg: Double
    var id: String { muscle }
}
