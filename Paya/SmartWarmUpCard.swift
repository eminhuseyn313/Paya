import SwiftUI

struct SmartWarmUpCard: View {

    @Environment(AppState.self) private var appState
    var exercises: [ExerciseDefinition]
    var previousData: [String: TrainViewModel.PreviousExerciseData]

    @State private var isExpanded = false
    @State private var warmupSets: [WarmUpSet] = []

    private var useLbs: Bool { appState.profile.prefersLbs }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
            } label: {
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "F59E0B").opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: "figure.flexibility")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "F59E0B"))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Smart Warm-Up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text("\(warmupSets.count) sets · ~\(estimatedMinutes) min")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(warmupSets) { set in
                        HStack(spacing: 10) {
                            Text(set.label)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "F59E0B"))
                                .frame(width: 52, alignment: .leading)

                            Text(set.exercise)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if set.weightKg > 0 {
                                let w = useLbs ? set.weightKg * 2.20462 : set.weightKg
                                Text(String(format: "%.0f %@", w, useLbs ? "lbs" : "kg"))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                            } else {
                                Text("BW")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }

                            Text("×\(set.reps)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)

                        if set.id != warmupSets.last?.id {
                            Divider().padding(.horizontal, 10)
                        }
                    }
                }
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Text("Based on your working weights. Lighter sets prime the nervous system without fatiguing muscles.")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .payaCard(padding: 14)
        .onAppear { generateWarmUp() }
    }

    private var estimatedMinutes: Int {
        max(3, warmupSets.count)
    }

    private func generateWarmUp() {
        var sets: [WarmUpSet] = []

        let compounds = exercises.filter { $0.type == .compound && $0.measurement.showsWeightField }
        guard !compounds.isEmpty else {
            sets.append(WarmUpSet(label: "General", exercise: "5 min light cardio", weightKg: 0, reps: 0))
            warmupSets = sets
            return
        }

        sets.append(WarmUpSet(label: "General", exercise: "2-3 min light cardio / jump rope", weightKg: 0, reps: 0))

        for exercise in compounds.prefix(2) {
            let workingWeight = previousData[exercise.id]?.weightKg ?? exercise.startWeightKg
            guard workingWeight > 0 else { continue }

            sets.append(WarmUpSet(
                label: "Empty bar",
                exercise: exercise.name,
                weightKg: 20,
                reps: 10
            ))

            let fiftyPercent = (workingWeight * 0.5).rounded(to: 2.5)
            if fiftyPercent > 25 {
                sets.append(WarmUpSet(
                    label: "50%",
                    exercise: exercise.name,
                    weightKg: fiftyPercent,
                    reps: 8
                ))
            }

            let seventyPercent = (workingWeight * 0.7).rounded(to: 2.5)
            if seventyPercent > fiftyPercent + 5 {
                sets.append(WarmUpSet(
                    label: "70%",
                    exercise: exercise.name,
                    weightKg: seventyPercent,
                    reps: 5
                ))
            }

            let ninetyPercent = (workingWeight * 0.9).rounded(to: 2.5)
            if ninetyPercent > seventyPercent + 5 {
                sets.append(WarmUpSet(
                    label: "90%",
                    exercise: exercise.name,
                    weightKg: ninetyPercent,
                    reps: 2
                ))
            }
        }

        warmupSets = sets
    }
}

private struct WarmUpSet: Identifiable {
    let id = UUID()
    let label: String
    let exercise: String
    let weightKg: Double
    let reps: Int
}

private extension Double {
    func rounded(to nearest: Double) -> Double {
        (self / nearest).rounded() * nearest
    }
}
