import SwiftUI

struct ConsistencyScoreCard: View {

    var sessions: [TrainingSession]
    var plannedPerWeek: Int

    @State private var score: Int = 0
    @State private var weekData: [WeekBar] = []

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
                    Text("\(score)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(scoreColor)
                }
            }

            Text(scoreMessage)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(weekData) { week in
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(week.isCurrent ? scoreColor : scoreColor.opacity(0.3))
                            .frame(height: max(4, CGFloat(week.sessions) / CGFloat(max(1, plannedPerWeek)) * 30))

                        Text(week.label)
                            .font(.system(size: 7))
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
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    let avg = weekData.isEmpty ? 0 : weekData.map(\.sessions).reduce(0, +) / max(1, weekData.count)
                    Circle().fill(scoreColor.opacity(0.4)).frame(width: 5, height: 5)
                    Text("Avg: \(avg)/week")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .payaCard(padding: 14)
        .onAppear { compute() }
    }

    private var scoreColor: Color {
        if score >= 80 { return Color(hex: "059669") }
        if score >= 50 { return Color(hex: "F59E0B") }
        return Color(hex: "DC2626")
    }

    private var scoreMessage: String {
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

        var weeks: [WeekBar] = []
        for i in (0..<8).reversed() {
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
