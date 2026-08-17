import SwiftUI

struct WorkoutMilestonesCard: View {

    var sessions: [TrainingSession]

    @State private var milestones: [Milestone] = []
    @State private var nextMilestone: Milestone? = nil

    var body: some View {
        Group {
            if !milestones.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "star.circle.fill")
                            .foregroundColor(Pulse.nutrition)
                        Text("Milestones")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }

                    ForEach(milestones) { ms in
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(ms.isAchieved
                                        ? Pulse.nutrition.opacity(0.15)
                                        : Pulse.surfaceElevatedFallback)
                                    .frame(width: 32, height: 32)
                                Text(ms.emoji)
                                    .font(.system(size: 16))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(ms.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(ms.isAchieved ? .primary : .secondary)
                                Text(ms.subtitle)
                                    .font(.system(size: 9))
                                    .foregroundColor(Pulse.textTertiary)
                            }

                            Spacer()

                            if ms.isAchieved {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Pulse.positive)
                                    .font(.system(size: 16))
                            } else {
                                Text(ms.progressLabel)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(Pulse.nutrition)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    if let next = nextMilestone, !next.isAchieved {
                        HStack(spacing: 6) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Pulse.surfaceElevatedFallback)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Pulse.nutrition)
                                        .frame(width: geo.size.width * next.progress)
                                }
                            }
                            .frame(height: 6)
                            Text(String(format: "%.0f%%", next.progress * 100))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Pulse.nutrition)
                                .frame(width: 30)
                        }
                    }
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func compute() {
        let completed = sessions.filter(\.isCompleted)
        let count = completed.count

        let totalVolume = completed.reduce(0.0) { total, session in
            total + session.exercises.reduce(0.0) { t, ex in
                t + ex.sets.filter(\.isCompleted).reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
            }
        }

        let calendar = Calendar.current
        var weekStreak = 0
        var checkWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!
        while true {
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: checkWeek))!
            let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
            let hasSession = completed.contains { $0.date >= weekStart && $0.date < weekEnd }
            if hasSession {
                weekStreak += 1
                checkWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: checkWeek)!
            } else {
                break
            }
        }

        let defs: [(target: Int, emoji: String, title: String, type: MilestoneType)] = [
            (10, "🔟", "10 Sessions", .sessions),
            (25, "💪", "25 Sessions", .sessions),
            (50, "🔥", "50 Sessions", .sessions),
            (100, "💯", "Century Club", .sessions),
            (250, "⚡", "250 Sessions", .sessions),
            (4, "📅", "4-Week Streak", .weekStreak),
            (8, "🏆", "8-Week Streak", .weekStreak),
            (12, "👑", "12-Week Streak", .weekStreak),
            (50000, "🏋️", "50t Volume Club", .volume),
            (100000, "💎", "100t Volume Club", .volume),
        ]

        var all: [Milestone] = []
        for def in defs {
            let current: Double
            let target = Double(def.target)
            switch def.type {
            case .sessions: current = Double(count)
            case .weekStreak: current = Double(weekStreak)
            case .volume: current = totalVolume
            }
            let achieved = current >= target
            let prog = min(1, current / target)

            all.append(Milestone(
                emoji: def.emoji,
                title: def.title,
                subtitle: def.type.subtitle(target: def.target),
                isAchieved: achieved,
                progress: prog,
                progressLabel: "\(Int(current))/\(def.target)"
            ))
        }

        let achieved = all.filter(\.isAchieved).suffix(3)
        let upcoming = all.filter { !$0.isAchieved }.prefix(2)
        milestones = Array(achieved) + Array(upcoming)
        nextMilestone = upcoming.first
    }
}

private enum MilestoneType {
    case sessions, weekStreak, volume

    func subtitle(target: Int) -> String {
        switch self {
        case .sessions: return "Complete \(target) training sessions"
        case .weekStreak: return "Train consistently for \(target) weeks"
        case .volume: return "Lift \(target >= 1000 ? "\(target/1000)t" : "\(target)kg") total volume"
        }
    }
}

private struct Milestone: Identifiable {
    let emoji: String
    let title: String
    let subtitle: String
    let isAchieved: Bool
    let progress: CGFloat
    let progressLabel: String
    var id: String { title }
}
