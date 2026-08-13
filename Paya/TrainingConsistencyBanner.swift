import SwiftUI
import SwiftData

// MARK: - Training Consistency Banner
// Compact dashboard banner showing the user's current training streak,
// weekly adherence rate, and a motivational nudge. Research shows that
// consistency is the #1 predictor of long-term results (Steele et al. 2017),
// making this arguably more important than any single workout metric.

struct TrainingConsistencyBanner: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var currentStreak: Int = 0
    @State private var adherenceRate: Int = 0
    @State private var weekDots: [Bool] = []
    @State private var longestStreak: Int = 0

    var body: some View {
        Group {
            if currentStreak > 0 || adherenceRate > 0 {
                HStack(spacing: 12) {
                    // Streak flame
                    VStack(spacing: 2) {
                        ZStack {
                            Circle()
                                .fill(streakColor.opacity(0.15))
                                .frame(width: 44, height: 44)
                            VStack(spacing: 0) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(streakColor)
                                Text("\(currentStreak)")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundColor(streakColor)
                            }
                        }
                        Text("week streak")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        // Adherence bar
                        HStack(spacing: 3) {
                            Text("\(adherenceRate)%")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Text("adherence · 8 weeks")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        // Week dots (last 8 weeks)
                        HStack(spacing: 3) {
                            ForEach(0..<weekDots.count, id: \.self) { i in
                                Circle()
                                    .fill(weekDots[i] ? Color(hex: "059669") : Color(hex: "DC2626").opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }

                        if longestStreak > currentStreak {
                            Text("Best: \(longestStreak) weeks")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .payaCard(padding: 12)
            }
        }
        .onAppear { compute() }
    }

    private var streakColor: Color {
        if currentStreak >= 8 { return Color(hex: "059669") }
        if currentStreak >= 4 { return Color(hex: "F59E0B") }
        return Color(hex: "DC2626")
    }

    private func compute() {
        let calendar = Calendar.current
        let pid = ActiveProfile.id
        let eightWeeksAgo = calendar.date(byAdding: .day, value: -56, to: Date())!

        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> {
                $0.profileId == pid && $0.isCompleted && $0.date >= eightWeeksAgo
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let sessions = try? modelContext.fetch(descriptor), !sessions.isEmpty else { return }

        let targetPerWeek = max(1, appState.profile.trainingDays.isEmpty ? 3 : appState.profile.trainingDays.count)

        // Build weekly session counts
        var weeklyHits: [Bool] = []
        for weekOffset in (0..<8).reversed() {
            let weekStart = calendar.date(byAdding: .day, value: -(weekOffset * 7 + 6), to: calendar.startOfDay(for: Date()))!
            let weekEnd = calendar.date(byAdding: .day, value: -(weekOffset * 7), to: calendar.startOfDay(for: Date()))!
            let count = sessions.filter { $0.date >= weekStart && $0.date <= weekEnd }.count
            // Hit if trained at least 75% of target
            weeklyHits.append(count >= max(1, Int(ceil(Double(targetPerWeek) * 0.75))))
        }

        weekDots = weeklyHits

        // Current streak (from most recent week backward)
        var streak = 0
        for hit in weeklyHits.reversed() {
            if hit { streak += 1 } else { break }
        }
        currentStreak = streak

        // Longest streak
        var longest = 0
        var running = 0
        for hit in weeklyHits {
            if hit { running += 1; longest = max(longest, running) }
            else { running = 0 }
        }
        longestStreak = longest

        // Adherence rate
        let hitCount = weeklyHits.filter { $0 }.count
        adherenceRate = Int(Double(hitCount) / Double(weeklyHits.count) * 100)
    }
}
