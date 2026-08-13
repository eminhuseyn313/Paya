import SwiftUI
import SwiftData

struct MuscleRecoveryStatusCard: View {

    let sessions: [TrainingSession]

    private var muscleStatuses: [MuscleStatus] {
        let calendar = Calendar.current
        let now = Date()
        var lastTrained: [String: (date: Date, sets: Int)] = [:]

        for session in sessions {
            for log in session.exercises {
                let group = log.muscleGroup
                let sets = log.sets.filter(\.isCompleted).count
                guard sets > 0 else { continue }
                if let existing = lastTrained[group] {
                    if session.date > existing.date {
                        lastTrained[group] = (session.date, sets)
                    }
                } else {
                    lastTrained[group] = (session.date, sets)
                }
            }
        }

        return lastTrained.map { group, info in
            let hoursAgo = calendar.dateComponents([.hour], from: info.date, to: now).hour ?? 0
            let recoveryHours = recoveryTime(for: group, sets: info.sets)
            let pct = min(1.0, Double(hoursAgo) / Double(recoveryHours))
            return MuscleStatus(
                name: group,
                recoveryPercent: pct,
                hoursAgo: hoursAgo,
                sets: info.sets
            )
        }
        .sorted { $0.recoveryPercent < $1.recoveryPercent }
    }

    private func recoveryTime(for muscle: String, sets: Int) -> Int {
        let m = muscle.lowercased()
        let baseHours: Int
        if m.contains("quad") || m.contains("glute") || m.contains("hamstring") || m.contains("back") {
            baseHours = 72
        } else if m.contains("chest") || m.contains("shoulder") {
            baseHours = 56
        } else {
            baseHours = 48
        }
        let volumeMultiplier = sets > 12 ? 1.25 : (sets > 8 ? 1.1 : 1.0)
        return Int(Double(baseHours) * volumeMultiplier)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundColor(Color(hex: "8B5CF6"))
                Text("Muscle Recovery")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(muscleStatuses.filter { $0.recoveryPercent >= 1.0 }.count)/\(muscleStatuses.count) ready")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(hex: "059669"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "059669").opacity(0.1))
                    .clipShape(Capsule())
            }

            if muscleStatuses.isEmpty {
                Text("Complete a session to see recovery status")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(muscleStatuses) { status in
                        MuscleRecoveryRow(status: status)
                    }
                }
            }
        }
        .payaCard(padding: 14)
    }
}

private struct MuscleRecoveryRow: View {
    let status: MuscleStatus

    private var statusColor: Color {
        if status.recoveryPercent >= 1.0 { return Color(hex: "059669") }
        if status.recoveryPercent >= 0.7 { return Color(hex: "F59E0B") }
        return Color(hex: "DC2626")
    }

    private var statusLabel: String {
        if status.recoveryPercent >= 1.0 { return "Ready" }
        if status.recoveryPercent >= 0.7 { return "Almost" }
        return "Recovering"
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text(statusLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(statusColor)
            }

            Spacer()

            CircularRecoveryGauge(percent: status.recoveryPercent, color: statusColor)
                .frame(width: 26, height: 26)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(statusColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct CircularRecoveryGauge: View {
    let percent: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: percent)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(percent * 100))")
                .font(.system(size: 8, weight: .bold))
                .monospacedDigit()
        }
    }
}

private struct MuscleStatus: Identifiable {
    let name: String
    let recoveryPercent: Double
    let hoursAgo: Int
    let sets: Int
    var id: String { name }
}
