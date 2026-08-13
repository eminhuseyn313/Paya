import SwiftUI

struct PRTimelineCard: View {

    @Environment(AppState.self) private var appState
    var sessions: [TrainingSession]

    @State private var events: [PREvent] = []
    @State private var showAll = false

    private var useLbs: Bool { appState.profile.prefersLbs }

    private var displayEvents: [PREvent] {
        showAll ? events : Array(events.prefix(5))
    }

    var body: some View {
        Group {
            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(Color(hex: "B45309"))
                        Text("PR Timeline")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(events.count) PRs")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "B45309"))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color(hex: "B45309").opacity(0.12))
                            .clipShape(Capsule())
                    }

                    ForEach(Array(displayEvents.enumerated()), id: \.element.id) { index, event in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(event.isRecent ? Color(hex: "059669") : Color(hex: "B45309"))
                                    .frame(width: 10, height: 10)
                                if index < displayEvents.count - 1 {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(width: 1.5)
                                        .frame(maxHeight: .infinity)
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(event.exerciseName)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                    if event.isRecent {
                                        Text("NEW")
                                            .font(.system(size: 7, weight: .black))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color(hex: "059669"))
                                            .clipShape(Capsule())
                                    }
                                    Spacer()
                                    Text(event.date.formatted(.dateTime.month(.abbreviated).day()))
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                HStack(spacing: 8) {
                                    let w = useLbs ? event.weightKg * 2.20462 : event.weightKg
                                    Text(String(format: "%.0f %@ × %d", w, useLbs ? "lbs" : "kg", event.reps))
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundColor(Color(hex: "B45309"))
                                    let e1rm = useLbs ? event.e1RM * 2.20462 : event.e1RM
                                    Text(String(format: "e1RM %.0f", e1rm))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    }

                    if events.count > 5 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showAll.toggle() }
                        } label: {
                            HStack {
                                Text(showAll ? "Show less" : "Show \(events.count - 5) more")
                                    .font(.caption.weight(.medium))
                                Image(systemName: showAll ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(Color(hex: "B45309"))
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { buildTimeline() }
    }

    private func buildTimeline() {
        let calendar = Calendar.current
        let now = Date()
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        var bestByExercise: [String: (weight: Double, reps: Int, e1rm: Double, date: Date)] = [:]

        for session in sessions.filter(\.isCompleted).sorted(by: { $0.date < $1.date }) {
            for log in session.exercises {
                for set in log.sets where set.isCompleted && set.weightKg > 0 {
                    let e1rm = set.weightKg * (1 + Double(set.reps) / 30.0)
                    if let existing = bestByExercise[log.exerciseName] {
                        if e1rm > existing.e1rm {
                            bestByExercise[log.exerciseName] = (set.weightKg, set.reps, e1rm, session.date)
                        }
                    } else {
                        bestByExercise[log.exerciseName] = (set.weightKg, set.reps, e1rm, session.date)
                    }
                }
            }
        }

        events = bestByExercise.map { name, data in
            PREvent(
                exerciseName: name,
                weightKg: data.weight,
                reps: data.reps,
                e1RM: data.e1rm,
                date: data.date,
                isRecent: data.date >= sevenDaysAgo
            )
        }
        .sorted { $0.date > $1.date }
    }
}

private struct PREvent: Identifiable {
    let id = UUID()
    let exerciseName: String
    let weightKg: Double
    let reps: Int
    let e1RM: Double
    let date: Date
    let isRecent: Bool
}
