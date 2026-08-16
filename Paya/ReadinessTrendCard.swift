import SwiftUI
import SwiftData

struct ReadinessTrendCard: View {

    @Environment(\.modelContext) private var modelContext

    @State private var scores: [DayScore] = []

    private var averageScore: Int? {
        let valid = scores.compactMap(\.score)
        guard !valid.isEmpty else { return nil }
        return valid.reduce(0, +) / valid.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "heart.text.clipboard")
                    .foregroundColor(Pulse.ai)
                Text("Recovery Trend")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let avg = averageScore {
                    HStack(spacing: 4) {
                        Text("avg")
                            .font(.system(size: 9))
                            .foregroundColor(Pulse.textTertiary)
                        Text("\(avg)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(scoreColor(avg))
                    }
                }
            }

            if scores.allSatisfy({ $0.score == nil }) {
                Text("Check in daily and wear your device to build recovery trends")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(scores) { day in
                        VStack(spacing: 3) {
                            if let score = day.score {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(scoreColor(score))
                                    .frame(height: max(6, CGFloat(score) * 0.5))
                            } else {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(height: 6)
                            }
                            Text(day.label)
                                .font(.system(size: 8))
                                .foregroundColor(day.isToday ? .primary : .secondary)
                                .fontWeight(day.isToday ? .bold : .regular)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 60)

                HStack(spacing: 16) {
                    legendDot(color: Pulse.positive, label: "70+ Great")
                    legendDot(color: Pulse.nutrition, label: "40-69 OK")
                    legendDot(color: Pulse.critical, label: "<40 Low")
                }
                .font(.system(size: 8))
            }
        }
        .payaCard(padding: 14)
        .onAppear { loadScores() }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label).foregroundColor(Pulse.textTertiary)
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 70 { return Pulse.positive }
        if score >= 40 { return Pulse.nutrition }
        return Pulse.critical
    }

    private func loadScores() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let pid = ActiveProfile.id

        let weekAgo = calendar.date(byAdding: .day, value: -6, to: today)!
        let descriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate<DailyCheckIn> { $0.date >= weekAgo && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        let checkIns = (try? modelContext.fetch(descriptor)) ?? []

        scores = (0..<7).map { daysFromStart in
            let date = calendar.date(byAdding: .day, value: daysFromStart, to: weekAgo)!
            let isToday = calendar.isDateInToday(date)
            let label = isToday ? "Today" : date.formatted(.dateTime.weekday(.narrow))

            let checkIn = checkIns.first { calendar.isDate($0.date, inSameDayAs: date) }
            var score: Int? = nil
            if let ci = checkIn {
                let energyScore = ci.energy * 33
                let sorenessScore = max(0, (6 - ci.soreness) * 25)
                score = (energyScore + sorenessScore) / 2
            }

            return DayScore(label: label, score: score, isToday: isToday, daysFromStart: daysFromStart)
        }
    }
}

private struct DayScore: Identifiable {
    let label: String
    let score: Int?
    let isToday: Bool
    let daysFromStart: Int
    var id: Int { daysFromStart }
}
