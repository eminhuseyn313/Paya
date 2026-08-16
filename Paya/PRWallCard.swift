import SwiftUI

struct PRWallCard: View {

    let sessions: [TrainingSession]
    @State private var expanded = false

    private var prs: [ExercisePR] {
        var bestE1RM: [String: (weight: Double, reps: Int, e1rm: Double, date: Date)] = [:]

        for session in sessions {
            for log in session.exercises {
                for set in log.sets where set.isCompleted && set.weightKg > 0 && set.reps > 0 {
                    let e1rm = set.weightKg * (1 + Double(set.reps) / 30.0)
                    let key = log.exerciseName
                    if let existing = bestE1RM[key] {
                        if e1rm > existing.e1rm {
                            bestE1RM[key] = (set.weightKg, set.reps, e1rm, session.date)
                        }
                    } else {
                        bestE1RM[key] = (set.weightKg, set.reps, e1rm, session.date)
                    }
                }
            }
        }

        return bestE1RM.map { name, data in
            ExercisePR(
                name: name,
                weight: data.weight,
                reps: data.reps,
                e1rm: data.e1rm,
                date: data.date
            )
        }
        .sorted { $0.e1rm > $1.e1rm }
    }

    private var displayPRs: [ExercisePR] {
        expanded ? prs : Array(prs.prefix(5))
    }

    private func isRecent(_ date: Date) -> Bool {
        Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 999 <= 7
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(Pulse.nutrition)
                Text("Personal Records")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(prs.count) lifts")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Pulse.textTertiary)
            }

            if prs.isEmpty {
                Text("Log weighted sets to build your PR wall")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ForEach(displayPRs) { pr in
                    PRRow(pr: pr, isRecent: isRecent(pr.date))
                }

                if prs.count > 5 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                    } label: {
                        Text(expanded ? "Show less" : "Show all \(prs.count) PRs")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Pulse.nutrition)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                }
            }
        }
        .payaCard(padding: 14)
    }
}

private struct PRRow: View {
    @Environment(AppState.self) private var appState
    let pr: ExercisePR
    let isRecent: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(pr.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if isRecent {
                        Text("NEW")
                            .font(.system(size: 7, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Pulse.positive)
                            .clipShape(Capsule())
                    }
                }
                Text(pr.date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(size: 9))
                    .foregroundColor(Pulse.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                let displayWeight = appState.profile.prefersLbs ? pr.weight * 2.20462 : pr.weight
                let unit = appState.profile.prefersLbs ? "lbs" : "kg"
                Text("\(String(format: "%.0f", displayWeight)) \(unit) × \(pr.reps)")
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
                let displayE1RM = appState.profile.prefersLbs ? pr.e1rm * 2.20462 : pr.e1rm
                Text("e1RM \(String(format: "%.0f", displayE1RM))")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Pulse.hydration)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ExercisePR: Identifiable {
    let name: String
    let weight: Double
    let reps: Int
    let e1rm: Double
    let date: Date
    var id: String { name }
}
