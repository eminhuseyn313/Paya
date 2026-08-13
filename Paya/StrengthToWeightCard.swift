import SwiftUI

// MARK: - Strength-to-Bodyweight Ratio
// The most meaningful measure of functional strength. A 100kg squat at 60kg
// bodyweight (1.67x) is more impressive than 120kg at 100kg (1.2x).
// Powerlifting, CrossFit, and calisthenics all use this as THE metric.
// Wilks/DOTS coefficients normalize for bodyweight in competition scoring.

struct StrengthToWeightCard: View {

    @Environment(AppState.self) private var appState
    var sessions: [TrainingSession]

    @State private var ratios: [LiftRatio] = []

    private var useLbs: Bool { appState.profile.prefersLbs }
    private var bw: Double {
        let w = appState.profile.currentWeightKg
        return w > 0 ? w : 75
    }

    private let keyLifts: [(name: String, elite: Double, advanced: Double, intermediate: Double)] = [
        ("Bench Press", 1.5, 1.25, 1.0),
        ("Squat", 2.0, 1.75, 1.25),
        ("Deadlift", 2.5, 2.0, 1.5),
        ("Overhead Press", 1.0, 0.8, 0.6),
        ("Barbell Row", 1.25, 1.0, 0.75),
    ]

    var body: some View {
        Group {
            if !ratios.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "person.fill.badge.plus")
                            .foregroundColor(Color(hex: "2563EB"))
                        Text("Strength : Bodyweight")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        let bwDisplay = useLbs ? bw * 2.20462 : bw
                        Text(String(format: "@ %.0f %@", bwDisplay, useLbs ? "lbs" : "kg"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }

                    ForEach(ratios) { ratio in
                        VStack(spacing: 4) {
                            HStack {
                                Text(ratio.liftName)
                                    .font(.system(size: 11, weight: .semibold))
                                Spacer()
                                Text(String(format: "%.2fx BW", ratio.ratio))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(ratio.levelColor)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    // Background track
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(.tertiarySystemBackground))

                                    // Progress fill
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            LinearGradient(
                                                colors: [ratio.levelColor.opacity(0.5), ratio.levelColor],
                                                startPoint: .leading, endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(4, geo.size.width * CGFloat(min(1, ratio.ratio / ratio.eliteRatio))))

                                    // Level markers
                                    ForEach([ratio.intermediateRatio, ratio.advancedRatio, ratio.eliteRatio], id: \.self) { marker in
                                        Rectangle()
                                            .fill(Color.secondary.opacity(0.3))
                                            .frame(width: 1, height: 10)
                                            .offset(x: geo.size.width * CGFloat(marker / ratio.eliteRatio) - 0.5)
                                    }
                                }
                            }
                            .frame(height: 10)

                            HStack {
                                let e1rmDisplay = useLbs ? ratio.e1rm * 2.20462 : ratio.e1rm
                                Text(String(format: "e1RM: %.0f %@", e1rmDisplay, useLbs ? "lbs" : "kg"))
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(ratio.levelLabel)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(ratio.levelColor)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    HStack(spacing: 12) {
                        levelLegend(color: Color(hex: "059669"), label: "Intermediate")
                        levelLegend(color: Color(hex: "2563EB"), label: "Advanced")
                        levelLegend(color: Color(hex: "8B5CF6"), label: "Elite")
                    }

                    Text("Ratios based on population-normed strength standards. e1RM via Epley formula.")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func levelLegend(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label).font(.system(size: 8)).foregroundColor(.secondary)
        }
    }

    private func compute() {
        let completed = sessions.filter(\.isCompleted)
        guard !completed.isEmpty else { return }

        ratios = keyLifts.compactMap { lift in
            var bestE1RM: Double = 0

            for session in completed {
                for log in session.exercises {
                    let name = log.exerciseName.lowercased()
                    let liftLower = lift.name.lowercased()
                    guard name.contains(liftLower) ||
                          (liftLower == "barbell row" && name.contains("row") && name.contains("barbell")) ||
                          (liftLower == "overhead press" && (name.contains("ohp") || name.contains("military") || name.contains("shoulder press")))
                    else { continue }

                    let best = log.sets.filter(\.isCompleted)
                        .map { $0.weightKg * (1 + Double($0.reps) / 30.0) }
                        .max() ?? 0
                    bestE1RM = max(bestE1RM, best)
                }
            }

            guard bestE1RM > 0 else { return nil }

            let ratio = bestE1RM / bw
            let levelLabel: String
            let levelColor: Color
            if ratio >= lift.elite {
                levelLabel = "Elite"
                levelColor = Color(hex: "8B5CF6")
            } else if ratio >= lift.advanced {
                levelLabel = "Advanced"
                levelColor = Color(hex: "2563EB")
            } else if ratio >= lift.intermediate {
                levelLabel = "Intermediate"
                levelColor = Color(hex: "059669")
            } else {
                levelLabel = "Beginner"
                levelColor = Color(hex: "F59E0B")
            }

            return LiftRatio(
                liftName: lift.name,
                e1rm: bestE1RM,
                ratio: ratio,
                eliteRatio: lift.elite,
                advancedRatio: lift.advanced,
                intermediateRatio: lift.intermediate,
                levelLabel: levelLabel,
                levelColor: levelColor
            )
        }
    }
}

private struct LiftRatio: Identifiable {
    let liftName: String
    let e1rm: Double
    let ratio: Double
    let eliteRatio: Double
    let advancedRatio: Double
    let intermediateRatio: Double
    let levelLabel: String
    let levelColor: Color
    var id: String { liftName }
}
