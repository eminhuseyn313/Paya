import SwiftUI

struct LastSessionCard: View {

    @Environment(AppState.self) private var appState
    let session: TrainingSession

    private var exerciseCount: Int {
        session.exercises.filter { ex in
            ex.sets.contains(where: \.isCompleted)
        }.count
    }

    private var totalSets: Int {
        session.exercises.flatMap(\.sets).filter(\.isCompleted).count
    }

    private var totalVolume: Double {
        var vol: Double = 0
        for log in session.exercises {
            for set in log.sets where set.isCompleted {
                vol += set.weightKg * Double(set.reps)
            }
        }
        return vol
    }

    private var topExercises: [String] {
        session.exercises
            .filter { $0.sets.contains(where: \.isCompleted) }
            .sorted { $0.orderIndex < $1.orderIndex }
            .prefix(3)
            .map(\.exerciseName)
    }

    private var daysAgo: String {
        let days = Calendar.current.dateComponents([.day], from: session.date, to: Date()).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        default: return "\(days) days ago"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Pulse.positive)
                Text("Last Session")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(daysAgo)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Pulse.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Pulse.surfaceElevatedFallback)
                    .clipShape(Capsule())
            }

            HStack(spacing: 16) {
                miniMetric(value: "\(session.durationMinutes)", unit: "min", icon: "clock.fill", color: "2563EB")
                miniMetric(value: "\(exerciseCount)", unit: "exercises", icon: "list.bullet", color: "8B5CF6")
                miniMetric(value: "\(totalSets)", unit: "sets", icon: "checkmark", color: "059669")
                if totalVolume > 0 {
                    let displayVol = appState.profile.prefersLbs ? totalVolume * 2.20462 : totalVolume
                    let unit = appState.profile.prefersLbs ? "lbs" : "kg"
                    miniMetric(
                        value: displayVol >= 1000 ? String(format: "%.1f", displayVol / 1000) : "\(Int(displayVol))",
                        unit: displayVol >= 1000 ? (appState.profile.prefersLbs ? "klbs" : "tonnes") : unit,
                        icon: "scalemass.fill",
                        color: "0891B2"
                    )
                }
            }

            if !topExercises.isEmpty {
                HStack(spacing: 6) {
                    ForEach(topExercises, id: \.self) { name in
                        Text(name)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Pulse.textTertiary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Pulse.surfaceElevatedFallback)
                            .clipShape(Capsule())
                            .lineLimit(1)
                    }
                }
            }
        }
        .payaCard(padding: 14)
    }

    private func miniMetric(value: String, unit: String, icon: String, color: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                    .foregroundColor(Color(hex: color))
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            Text(unit)
                .font(.system(size: 8))
                .foregroundColor(Pulse.textTertiary)
        }
    }
}
