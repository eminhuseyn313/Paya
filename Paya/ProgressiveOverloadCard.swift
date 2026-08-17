import SwiftUI

struct ProgressiveOverloadCard: View {

    @Environment(AppState.self) private var appState
    var sessions: [TrainingSession]

    @State private var exercises: [OverloadItem] = []

    private var useLbs: Bool { appState.profile.prefersLbs }

    var body: some View {
        Group {
            if !exercises.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "arrow.up.forward.circle.fill")
                            .foregroundColor(Pulse.positive)
                        Text("Progressive Overload")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }

                    Text("Exercises where you've increased weight or reps over the last 4 sessions.")
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)

                    ForEach(exercises) { item in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(item.isProgressing ? Pulse.positive.opacity(0.12) : Pulse.nutrition.opacity(0.12))
                                    .frame(width: 28, height: 28)
                                Image(systemName: item.isProgressing ? "arrow.up" : "minus")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(item.isProgressing ? Pulse.positive : Pulse.nutrition)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    let startW = useLbs ? item.startWeight * 2.20462 : item.startWeight
                                    let endW = useLbs ? item.endWeight * 2.20462 : item.endWeight
                                    Text(String(format: "%.0f→%.0f %@", startW, endW, useLbs ? "lbs" : "kg"))
                                        .font(.system(size: 10, design: .rounded))
                                        .foregroundColor(Pulse.textTertiary)
                                    if item.repsChange != 0 {
                                        Text(item.repsChange > 0 ? "+\(item.repsChange) reps" : "\(item.repsChange) reps")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(item.repsChange > 0 ? Pulse.positive : Pulse.critical)
                                    }
                                }
                            }

                            Spacer()

                            if item.isProgressing {
                                Text(String(format: "+%.0f%%", item.changePercent))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(Pulse.positive)
                            } else {
                                Text("Plateau")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Pulse.nutrition)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func compute() {
        var exerciseHistory: [String: [(weight: Double, reps: Int, date: Date)]] = [:]

        for session in sessions.filter(\.isCompleted).sorted(by: { $0.date < $1.date }) {
            for log in session.exercises {
                let completed = log.sets.filter(\.isCompleted)
                guard !completed.isEmpty else { continue }
                let maxWeight = completed.map(\.weightKg).max() ?? 0
                let avgReps = completed.map(\.reps).reduce(0, +) / max(1, completed.count)
                guard maxWeight > 0 else { continue }
                exerciseHistory[log.exerciseName, default: []].append((maxWeight, avgReps, session.date))
            }
        }

        exercises = exerciseHistory.compactMap { name, history in
            guard history.count >= 2 else { return nil }
            let recent = history.suffix(4)
            guard let first = recent.first, let last = recent.last else { return nil }

            let weightChange = last.weight - first.weight
            let repsChange = last.reps - first.reps
            let changePercent = first.weight > 0 ? (weightChange / first.weight) * 100 : 0
            let isProgressing = weightChange > 0 || (weightChange == 0 && repsChange > 0)

            return OverloadItem(
                name: name,
                startWeight: first.weight,
                endWeight: last.weight,
                repsChange: repsChange,
                changePercent: changePercent,
                isProgressing: isProgressing
            )
        }
        .sorted { $0.changePercent > $1.changePercent }
        .prefix(8)
        .map { $0 }
    }
}

private struct OverloadItem: Identifiable {
    let name: String
    let startWeight: Double
    let endWeight: Double
    let repsChange: Int
    let changePercent: Double
    let isProgressing: Bool
    var id: String { name }
}
