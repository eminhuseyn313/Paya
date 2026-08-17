import SwiftUI

// MARK: - Muscle Freshness Map
// Visual body-map style display showing each muscle group's freshness
// status based on when it was last trained and estimated recovery time.
// Green = fresh (ready), amber = recovering, red = fatigued.
// Like Whoop's recovery indicator but per muscle group.

struct MuscleFreshnessMap: View {

    var sessions: [TrainingSession]

    @State private var muscles: [MuscleFreshness] = []

    var body: some View {
        Group {
            if !muscles.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "figure.stand")
                            .foregroundColor(Pulse.positive)
                        Text("Muscle Freshness")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        let fresh = muscles.filter { $0.status == .fresh }.count
                        Text("\(fresh)/\(muscles.count) ready")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Pulse.positive)
                    }

                    // Body map grid - 2 columns
                    let leftMuscles = muscles.filter { $0.side == .left || $0.side == .center }
                    let rightMuscles = muscles.filter { $0.side == .right }

                    HStack(alignment: .top, spacing: 8) {
                        VStack(spacing: 4) {
                            ForEach(leftMuscles) { muscle in
                                muscleRow(muscle)
                            }
                        }
                        VStack(spacing: 4) {
                            ForEach(rightMuscles) { muscle in
                                muscleRow(muscle)
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        statusLegend(color: Pulse.positive, label: "Fresh")
                        statusLegend(color: Pulse.nutrition, label: "Recovering")
                        statusLegend(color: Pulse.critical, label: "Fatigued")
                        statusLegend(color: Pulse.surfaceElevatedFallback, label: "Unknown")
                    }

                    Text("Recovery estimates: large muscles 72h, medium 56h, small 48h. Adjusted by volume.")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func muscleRow(_ muscle: MuscleFreshness) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(muscle.statusColor)
                .frame(width: 10, height: 10)

            Text(muscle.name)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)

            Spacer()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Pulse.surfaceElevatedFallback)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(muscle.statusColor.opacity(0.6))
                        .frame(width: geo.size.width * CGFloat(muscle.recoveryPercent))
                }
            }
            .frame(width: 40, height: 6)

            Text(muscle.hoursLabel)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(Pulse.textTertiary)
                .frame(width: 28, alignment: .trailing)
        }
    }

    private func statusLegend(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label).font(.system(size: 7)).foregroundColor(Pulse.textTertiary)
        }
    }

    private func compute() {
        let now = Date()
        let completed = sessions.filter(\.isCompleted)

        let muscleGroups: [(name: String, side: MuscleSide, recoveryHours: Double)] = [
            ("Chest", .left, 72),
            ("Back", .left, 72),
            ("Shoulders", .left, 56),
            ("Biceps", .left, 48),
            ("Triceps", .left, 48),
            ("Core", .left, 48),
            ("Quads", .right, 72),
            ("Hamstrings", .right, 72),
            ("Glutes", .right, 72),
            ("Calves", .right, 48),
            ("Forearms", .right, 48),
            ("Traps", .right, 56),
        ]

        muscles = muscleGroups.map { group in
            var lastTrained: Date? = nil
            var totalSets = 0

            for session in completed {
                for log in session.exercises {
                    let mg = log.muscleGroup.lowercased()
                    let target = group.name.lowercased()
                    guard mg.contains(target) ||
                          (target == "chest" && mg.contains("pec")) ||
                          (target == "back" && (mg.contains("lat") || mg.contains("back"))) ||
                          (target == "shoulders" && (mg.contains("delt") || mg.contains("shoulder"))) ||
                          (target == "core" && (mg.contains("ab") || mg.contains("core"))) ||
                          (target == "quads" && (mg.contains("quad") || mg.contains("leg"))) ||
                          (target == "glutes" && mg.contains("glute"))
                    else { continue }

                    let completedSets = log.sets.filter(\.isCompleted).count
                    if completedSets > 0 {
                        if lastTrained == nil || session.date > lastTrained! {
                            lastTrained = session.date
                            totalSets = completedSets
                        }
                    }
                }
            }

            let baseRecovery = group.recoveryHours
            let volumeMultiplier = totalSets > 6 ? 1.2 : 1.0
            let adjustedRecovery = baseRecovery * volumeMultiplier

            let hoursSinceTraining: Double
            let recoveryPercent: Double
            let status: MuscleStatus

            if let last = lastTrained {
                hoursSinceTraining = now.timeIntervalSince(last) / 3600
                recoveryPercent = min(1, hoursSinceTraining / adjustedRecovery)

                if recoveryPercent >= 1 {
                    status = .fresh
                } else if recoveryPercent >= 0.6 {
                    status = .recovering
                } else {
                    status = .fatigued
                }
            } else {
                hoursSinceTraining = -1
                recoveryPercent = 1
                status = .unknown
            }

            let hoursLabel: String
            if hoursSinceTraining < 0 {
                hoursLabel = "—"
            } else if hoursSinceTraining < 24 {
                hoursLabel = String(format: "%.0fh", hoursSinceTraining)
            } else {
                hoursLabel = String(format: "%.0fd", hoursSinceTraining / 24)
            }

            return MuscleFreshness(
                name: group.name,
                side: group.side,
                status: status,
                statusColor: status.color,
                recoveryPercent: recoveryPercent,
                hoursLabel: hoursLabel
            )
        }
    }
}

private enum MuscleStatus {
    case fresh, recovering, fatigued, unknown
    var color: Color {
        switch self {
        case .fresh: return Pulse.positive
        case .recovering: return Pulse.nutrition
        case .fatigued: return Pulse.critical
        case .unknown: return Pulse.surfaceElevatedFallback
        }
    }
}

private enum MuscleSide {
    case left, right, center
}

private struct MuscleFreshness: Identifiable {
    let name: String
    let side: MuscleSide
    let status: MuscleStatus
    let statusColor: Color
    let recoveryPercent: Double
    let hoursLabel: String
    var id: String { name }
}
