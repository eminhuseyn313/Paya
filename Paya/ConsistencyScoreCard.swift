import SwiftUI

struct ConsistencyScoreCard: View {

    var sessions: [TrainingSession]
    var plannedPerWeek: Int

    @State private var score: Int = 0
    @State private var weekData: [WeekBar] = []
    /// Weeks of real history the score is based on (capped at 8).
    @State private var weeksOfHistory: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(scoreColor)
                Text("Consistency")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                ZStack {
                    Circle()
                        .stroke(scoreColor.opacity(0.2), lineWidth: 3)
                        .frame(width: 36, height: 36)
                    Circle()
                        .trim(from: 0, to: Double(score) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(-90))
                    Text(weeksOfHistory == 0 || plannedPerWeek == 0 ? "—" : "\(score)")
                        .font(.pulse(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(scoreColor)
                }
            }

            Text(scoreMessage)
                .font(.caption)
                .foregroundColor(Pulse.textTertiary)

            if weeksOfHistory > 0 && weeksOfHistory < 4 {
                Text("Early estimate · \(weeksOfHistory) week\(weeksOfHistory == 1 ? "" : "s") of history")
                    .font(.pulse(size: 10, weight: .medium))
                    .foregroundColor(Pulse.textTertiary)
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(weekData) { week in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(week.isCurrent ? scoreColor : scoreColor.opacity(0.3))
                            // Was uncapped — a week with MORE sessions than
                            // the target (a good thing, and common) grew the
                            // bar past the row's fixed 40pt height, pushing
                            // its date label down into the legend row below.
                            // Capped at the same 30pt the formula targets for
                            // a fully-met week; overachieving just fills the
                            // full bar instead of overflowing it.
                            .frame(height: min(30, max(4, CGFloat(week.sessions) / CGFloat(max(1, plannedPerWeek)) * 30)))

                        Text(week.label)
                            .font(.pulse(size: 7))
                            .foregroundColor(week.isCurrent ? .primary : .secondary)
                            .fontWeight(week.isCurrent ? .bold : .regular)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 40)

            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(scoreColor).frame(width: 5, height: 5)
                    Text("Target: \(plannedPerWeek)/week")
                        .font(.pulse(size: 9))
                        .foregroundColor(Pulse.textTertiary)
                }
                HStack(spacing: 4) {
                    let avg = weekData.isEmpty ? 0 : weekData.map(\.sessions).reduce(0, +) / max(1, weekData.count)
                    Circle().fill(scoreColor.opacity(0.4)).frame(width: 5, height: 5)
                    Text("Avg: \(avg)/week")
                        .font(.pulse(size: 9))
                        .foregroundColor(Pulse.textTertiary)
                }
            }
        }
        .payaCard(padding: 14)
        .onAppear { compute() }
    }

    private var scoreColor: Color {
        if score >= 80 { return Pulse.positive }
        if score >= 50 { return Pulse.warning }
        return Pulse.critical
    }

    private var scoreMessage: String {
        if weeksOfHistory == 0 { return "Log a workout to see your consistency." }
        if score >= 90 { return "Elite consistency. You're building a real habit." }
        if score >= 75 { return "Strong consistency. Keep showing up." }
        if score >= 50 { return "Decent, but there's room to improve." }
        if score >= 25 { return "Getting started. Even 2 sessions/week builds a streak." }
        return "Start training this week to build your score."
    }

    private func compute() {
        let calendar = Calendar.current
        let now = Date()
        let completed = sessions.filter(\.isCompleted)

        // Only weeks since the first logged session count — weeks before the
        // user started aren't "missed", they're outside the data.
        guard let firstDate = completed.map(\.date).min() else {
            weekData = []; weeksOfHistory = 0; score = 0; return
        }
        let firstWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: firstDate)) ?? firstDate
        let nowWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let weeksSinceFirst = (calendar.dateComponents([.weekOfYear], from: firstWeek, to: nowWeek).weekOfYear ?? 0) + 1
        let span = max(1, min(8, weeksSinceFirst))
        weeksOfHistory = span

        var weeks: [WeekBar] = []
        for i in (0..<span).reversed() {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: now)!
            let ws = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart))!
            let we = calendar.date(byAdding: .day, value: 7, to: ws)!
            let count = completed.filter { $0.date >= ws && $0.date < we }.count
            let label = ws.formatted(.dateTime.month(.defaultDigits).day())
            weeks.append(WeekBar(label: label, sessions: count, isCurrent: i == 0))
        }
        weekData = weeks

        guard plannedPerWeek > 0, !weeks.isEmpty else { score = 0; return }
        let hitWeeks = weeks.filter { $0.sessions >= plannedPerWeek }.count
        let totalRatio = Double(hitWeeks) / Double(weeks.count)

        let recentBoost: Double = weeks.suffix(3).allSatisfy({ $0.sessions >= plannedPerWeek }) ? 0.1 : 0

        score = min(100, Int((totalRatio + recentBoost) * 100))
    }
}

private struct WeekBar: Identifiable {
    let label: String
    let sessions: Int
    let isCurrent: Bool
    var id: String { label }
}
