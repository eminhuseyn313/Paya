import SwiftUI

struct SessionComparisonBanner: View {

    @Environment(AppState.self) private var appState
    var vm: TrainViewModel
    var ticker: Int

    private var useLbs: Bool { appState.profile.prefersLbs }

    private var currentVolume: Double { vm.totalSessionVolume }

    private var previousVolume: Double { vm.previousSessionVolume }

    private var volumeDelta: Double {
        guard previousVolume > 0 else { return 0 }
        return currentVolume - previousVolume
    }

    private var volumePercent: Double {
        guard previousVolume > 0 else { return 0 }
        return (volumeDelta / previousVolume) * 100
    }

    private func displayVol(_ kg: Double) -> String {
        let val = useLbs ? kg * 2.20462 : kg
        if abs(val) >= 1000 {
            return String(format: "%.1f%@", val / 1000, useLbs ? "klbs" : "t")
        }
        return String(format: "%.0f %@", val, useLbs ? "lbs" : "kg")
    }

    private var completedExerciseCount: Int {
        vm.exerciseStates.values.filter(\.allSetsCompleted).count
    }

    private var totalExerciseCount: Int {
        vm.effectiveExercises.count
    }

    private var setsAhead: Int {
        let current = vm.totalCompletedSets
        let prevSetsAtThisPoint = min(current, vm.exerciseStates.values.reduce(0) { $0 + $1.sets.count })
        return current - prevSetsAtThisPoint + (currentVolume > previousVolume ? 1 : 0)
    }

    var body: some View {
        Group {
            if previousVolume > 0 && vm.totalCompletedSets >= 1 {
                HStack(spacing: 12) {

                    ZStack {
                        Circle()
                            .fill(volumeDelta >= 0
                                  ? Pulse.positive.opacity(0.12)
                                  : Pulse.nutrition.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: volumeDelta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(volumeDelta >= 0 ? Pulse.positive : Pulse.nutrition)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("vs last session")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Pulse.textTertiary)
                        HStack(spacing: 6) {
                            Text(volumeDelta >= 0 ? "+\(displayVol(abs(volumeDelta)))" : "-\(displayVol(abs(volumeDelta)))")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(volumeDelta >= 0 ? Pulse.positive : Pulse.nutrition)
                            if abs(volumePercent) >= 1 {
                                Text(String(format: "%+.0f%%", volumePercent))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Pulse.textTertiary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Pulse.surfaceElevatedFallback)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(completedExerciseCount)/\(totalExerciseCount)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Pulse.textPrimary)
                        Text("exercises")
                            .font(.system(size: 9))
                            .foregroundColor(Pulse.textTertiary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}
