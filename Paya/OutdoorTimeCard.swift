import SwiftUI
import SwiftData
import Charts

// MARK: - Outdoor Time Store + Card
//
// The roadmap named this gap directly: "how much time stay, how much stay
// in closed area" is a different question than daylight-minutes already
// answers. Quick-log buttons (same instant-tap pattern as water logging)
// rather than a form, since the whole point is this gets logged in the
// moment, not reconstructed later. A daily target + streak turns it into a
// habit worth keeping instead of a stat that just sits there.

enum OutdoorTimeStore {
    @MainActor
    static func todayTotal(context: ModelContext) -> Double {
        dailyTotal(for: Calendar.current.startOfDay(for: .now), context: context)
    }

    @MainActor
    static func dailyTotal(for day: Date, context: ModelContext) -> Double {
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        let descriptor = FetchDescriptor<OutdoorTimeLog>(
            predicate: #Predicate<OutdoorTimeLog> { $0.date >= start && $0.date < end && $0.profileId == pid }
        )
        return ((try? context.fetch(descriptor)) ?? []).reduce(0) { $0 + $1.minutes }
    }

    @MainActor
    static func logMinutes(_ minutes: Double, context: ModelContext) {
        let log = OutdoorTimeLog(minutes: minutes)
        log.profileId = ActiveProfile.id
        context.insert(log)
        try? context.save()
    }

    /// Consecutive days (ending today or yesterday — a day not over yet
    /// shouldn't break a streak) that met the daily target.
    @MainActor
    static func currentStreak(context: ModelContext) -> Int {
        let calendar = Calendar.current
        let target = Double(LifestyleReminderSettings.outdoorTargetMinutes)
        var streak = 0
        var day = calendar.startOfDay(for: .now)

        if dailyTotal(for: day, context: context) < target {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        while dailyTotal(for: day, context: context) >= target {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }
}

struct OutdoorTimeCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var todayMinutes: Double = 0
    @State private var streak: Int = 0
    @State private var weekData: [DayBar] = []

    private let quickAdds: [Double] = [15, 30, 60]
    private let green = Color(hex: "16A34A")
    private var targetMinutes: Double { Double(LifestyleReminderSettings.outdoorTargetMinutes) }
    private var progress: Double { min(1.0, todayMinutes / max(targetMinutes, 1)) }

    struct DayBar: Identifiable {
        let id: Date
        let label: String
        let minutes: Double
        let isToday: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "tree.fill")
                    .foregroundColor(green)
                Text("Time Outdoors")
                    .font(.subheadline.weight(.semibold))
                CardInfoButton(
                    title: "Time Outdoors",
                    explanation: "Manual outdoor time log, fed into the correlation engine. 2+ hrs/day of outdoor light significantly reduces myopia progression (Sherwin et al., Ophthalmology 2012) and anchors circadian rhythm (Czeisler et al.)."
                )
                Spacer()
                if streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill").font(.caption2)
                        Text("\(streak)").font(.caption.weight(.bold))
                    }
                    .foregroundColor(Color(hex: "D97706"))
                }
            }

            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(green.opacity(0.15), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.4), value: progress)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(todayMinutes >= 60 ? String(format: "%.1fh", todayMinutes / 60) : "\(Int(todayMinutes))m")
                            .font(.title3.bold())
                            .monospacedDigit()
                        Text("of \(Int(targetMinutes))m goal")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }

            if todayMinutes == 0 && streak == 0 {
                Text("Tap a button below after spending time outside — tracks your daily outdoor exposure for eye health and circadian rhythm.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                ForEach(quickAdds, id: \.self) { minutes in
                    Button {
                        OutdoorTimeStore.logMinutes(minutes, context: modelContext)
                        withAnimation(.spring(response: 0.25)) {
                            todayMinutes += minutes
                            loadWeek()
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        streak = OutdoorTimeStore.currentStreak(context: modelContext)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .bold))
                            Text("\(Int(minutes))m")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundColor(green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }

            if weekData.contains(where: { $0.minutes > 0 }) {
                Chart(weekData) { bar in
                    BarMark(
                        x: .value("Day", bar.label),
                        y: .value("Min", bar.minutes)
                    )
                    .foregroundStyle(bar.isToday ? green : green.opacity(0.4))
                    .cornerRadius(3)

                    if targetMinutes > 0 {
                        RuleMark(y: .value("Target", targetMinutes))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .foregroundStyle(.secondary.opacity(0.4))
                    }
                }
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 50)

                Text(weekInsight)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .payaCard(padding: 14)
        .onAppear {
            todayMinutes = OutdoorTimeStore.todayTotal(context: modelContext)
            streak = OutdoorTimeStore.currentStreak(context: modelContext)
            loadWeek()
        }
    }

    private func loadWeek() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        weekData = (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let mins = OutdoorTimeStore.dailyTotal(for: day, context: modelContext)
            return DayBar(
                id: day,
                label: offset == 0 ? "Today" : formatter.string(from: day),
                minutes: mins,
                isToday: offset == 0
            )
        }
    }

    private var weekInsight: String {
        let daysWithData = weekData.filter { $0.minutes > 0 }
        guard !daysWithData.isEmpty else { return "No outdoor time logged this week yet." }
        let avg = daysWithData.reduce(0.0) { $0 + $1.minutes } / Double(daysWithData.count)
        let metTarget = weekData.filter { $0.minutes >= targetMinutes }.count
        if avg >= targetMinutes {
            return "Averaging \(Int(avg))m/day — hitting your target \(metTarget)/7 days."
        } else {
            return "Averaging \(Int(avg))m/day — \(Int(targetMinutes - avg))m short of your daily goal."
        }
    }
}
