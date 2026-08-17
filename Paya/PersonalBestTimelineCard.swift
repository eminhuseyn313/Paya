import SwiftUI
import SwiftData

// MARK: - Personal Best Timeline Card
// Shows a chronological feed of all-time personal bests across exercises.
// Each PR is a milestone in the user's lifting journey — most fitness apps
// show PRs in isolation per exercise; this card creates a unified timeline
// that tells the full progression story. Inspired by Strava's "trophy case"
// and Whoop's strain timeline.

struct PersonalBestTimelineCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var prs: [PREvent] = []
    @State private var showAll = false

    private var useLbs: Bool { appState.profile.prefersLbs }
    private func convert(_ kg: Double) -> Double {
        useLbs ? kg * 2.20462 : kg
    }
    private var unit: String { useLbs ? "lbs" : "kg" }

    var body: some View {
        Group {
            if prs.count >= 3 {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(Pulse.nutrition)
                        Text("PR timeline")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(prs.count) records")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Pulse.nutrition)
                    }

                    let displayPRs = showAll ? prs : Array(prs.prefix(5))

                    // Timeline
                    ForEach(Array(displayPRs.enumerated()), id: \.element.id) { index, pr in
                        HStack(alignment: .top, spacing: 10) {
                            // Timeline line + dot
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(pr.isRecent ? Pulse.nutrition : Pulse.nutrition.opacity(0.4))
                                    .frame(width: 10, height: 10)
                                if index < displayPRs.count - 1 {
                                    Rectangle()
                                        .fill(Pulse.nutrition.opacity(0.2))
                                        .frame(width: 2)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            .frame(width: 10)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(pr.exerciseName)
                                        .font(.system(size: 12, weight: .bold))
                                        .lineLimit(1)
                                    if pr.isRecent {
                                        Text("NEW")
                                            .font(.system(size: 7, weight: .black))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Pulse.nutrition)
                                            .clipShape(Capsule())
                                    }
                                }

                                HStack(spacing: 8) {
                                    Text(String(format: "%.0f %@ × %d", convert(pr.weightKg), unit, pr.reps))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(Pulse.textPrimary)

                                    Text("e1RM \(String(format: "%.0f", convert(pr.e1rm)))")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Pulse.hydration)

                                    Spacer()

                                    Text(pr.dateLabel)
                                        .font(.system(size: 9))
                                        .foregroundColor(Pulse.textTertiary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    if prs.count > 5 {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showAll.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(showAll ? "Show less" : "Show all \(prs.count) PRs")
                                    .font(.system(size: 11, weight: .semibold))
                                Image(systemName: showAll ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(Pulse.nutrition)
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
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> {
                $0.profileId == pid && $0.isCompleted
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        guard let sessions = try? modelContext.fetch(descriptor) else { return }

        // Track best e1RM per exercise over time
        var bestE1RM: [String: Double] = [:]
        var events: [PREvent] = []
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"

        for session in sessions {
            for log in session.exercises {
                for set in log.sets where set.isCompleted && set.weightKg > 0 && set.reps > 0 {
                    let e1rm = set.weightKg * (1 + Double(set.reps) / 30.0)
                    let key = log.exerciseName

                    if let currentBest = bestE1RM[key] {
                        if e1rm > currentBest * 1.01 { // 1% threshold to avoid noise
                            bestE1RM[key] = e1rm
                            events.append(PREvent(
                                exerciseName: key,
                                weightKg: set.weightKg,
                                reps: set.reps,
                                e1rm: e1rm,
                                date: session.date,
                                dateLabel: dateFormatter.string(from: session.date),
                                isRecent: session.date >= sevenDaysAgo
                            ))
                        }
                    } else {
                        bestE1RM[key] = e1rm
                        // Don't count the very first log as a PR
                    }
                }
            }
        }

        // Sort newest first, take all
        prs = events.sorted { $0.date > $1.date }
    }
}

private struct PREvent: Identifiable {
    let id = UUID()
    let exerciseName: String
    let weightKg: Double
    let reps: Int
    let e1rm: Double
    let date: Date
    let dateLabel: String
    let isRecent: Bool
}
