import SwiftUI
import SwiftData

// MARK: - Momentum Card
//
// Dashboard card showing habit streak progress. Unlike Duolingo
// streaks that punish with resets, Paya's momentum system awards
// permanent badges at 21 and 66 days. Missing a day resets the
// active counter but never revokes earned badges.

struct MomentumCard: View {

    @Environment(\.modelContext) private var modelContext
    @State private var streaks: [MomentumStreak] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(Pulse.nutrition)
                    .font(.system(size: 12))
                Text("Momentum")
                    .font(.subheadline.weight(.semibold))
                Spacer()

                let activeCount = streaks.filter { $0.currentStreak > 0 }.count
                if activeCount > 0 {
                    Text("\(activeCount) active")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Pulse.positive)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Pulse.positive.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            ForEach(streaks) { streak in
                streakRow(streak)
            }

            // Milestone legend
            HStack(spacing: 12) {
                legendItem(icon: "checkmark.seal.fill", label: "21d — Habit formed", color: "F59E0B")
                legendItem(icon: "star.circle.fill", label: "66d — Automatic", color: "8B5CF6")
            }
            .padding(.top, 2)

            HStack(spacing: 4) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 8))
                Text("66-day threshold from Lally et al. (2010), European Journal of Social Psychology")
                    .font(.system(size: 9))
            }
            .foregroundColor(Pulse.textTertiary)
        }
        .payaCard(padding: 14)
        .onAppear {
            streaks = MomentumEngine.computeStreaks(context: modelContext)
            MomentumEngine.grantBadges(context: modelContext)
        }
    }

    @ViewBuilder
    private func streakRow(_ streak: MomentumStreak) -> some View {
        HStack(spacing: 10) {
            // Icon with today-done indicator
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(Color(hex: streak.habit.colorHex).opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: streak.habit.icon)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: streak.habit.colorHex))
                }
                if streak.todayDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Pulse.positive)
                        .background(Circle().fill(.background).frame(width: 13, height: 13))
                        .offset(x: 2, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(streak.habit.label)
                        .font(.caption.weight(.semibold))
                    if streak.hasPermanentBadge {
                        Image(systemName: "star.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Pulse.ai)
                    } else if streak.hasFormedHabit {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Pulse.nutrition)
                    }
                }

                // Streak text
                if streak.currentStreak > 0 {
                    Text("\(streak.currentStreak)-day streak")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: streak.habit.colorHex))
                } else {
                    Text(streak.todayDone ? "Started today" : "Not active")
                        .font(.system(size: 10))
                        .foregroundColor(Pulse.textTertiary)
                }
            }

            Spacer()

            // Progress to next milestone
            let target = streak.currentStreak < 21 ? 21 : 66
            let progress = min(1.0, Double(streak.currentStreak) / Double(target))

            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .stroke(Color(.tertiarySystemFill), lineWidth: 3)
                        .frame(width: 28, height: 28)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            Color(hex: streak.habit.colorHex),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                    Text("\(streak.currentStreak)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                }
                Text("/\(target)d")
                    .font(.system(size: 8))
                    .foregroundColor(Pulse.textTertiary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func legendItem(icon: String, label: String, color: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(Color(hex: color))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Pulse.textTertiary)
        }
    }
}
