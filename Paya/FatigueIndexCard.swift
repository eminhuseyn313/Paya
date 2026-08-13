import SwiftUI

struct FatigueIndexCard: View {

    var sessions: [TrainingSession]

    @State private var fatigueScore: Int = 0
    @State private var trend: FatigueTrend = .stable
    @State private var factors: [FatigueFactor] = []

    var body: some View {
        Group {
            if fatigueScore > 0 {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "battery.75percent")
                            .foregroundColor(fatigueColor)
                        Text("Fatigue Index")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(fatigueLabel)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(fatigueColor)
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .stroke(Color(.tertiarySystemBackground), lineWidth: 6)
                                .frame(width: 56, height: 56)
                            Circle()
                                .trim(from: 0, to: CGFloat(fatigueScore) / 100)
                                .stroke(fatigueColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                                .frame(width: 56, height: 56)
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 0) {
                                Text("\(fatigueScore)")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                Text("/100")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(factors) { factor in
                                HStack(spacing: 6) {
                                    Image(systemName: factor.icon)
                                        .font(.system(size: 10))
                                        .foregroundColor(factor.color)
                                        .frame(width: 14)
                                    Text(factor.text)
                                        .font(.system(size: 10))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: trend.icon)
                            .font(.system(size: 9, weight: .bold))
                        Text(trend.message)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(trend.color)

                    Text("Accumulated training stress from volume, frequency, and RPE over the past 7 days. Above 70 suggests a deload may help.")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private var fatigueColor: Color {
        if fatigueScore >= 70 { return Color(hex: "DC2626") }
        if fatigueScore >= 45 { return Color(hex: "F59E0B") }
        return Color(hex: "059669")
    }

    private var fatigueLabel: String {
        if fatigueScore >= 70 { return "High" }
        if fatigueScore >= 45 { return "Moderate" }
        return "Low"
    }

    private func compute() {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: Date())!

        let thisWeek = sessions.filter { $0.isCompleted && $0.date >= sevenDaysAgo }
        let lastWeek = sessions.filter { $0.isCompleted && $0.date >= fourteenDaysAgo && $0.date < sevenDaysAgo }

        guard !thisWeek.isEmpty else { return }

        var score: Double = 0
        var factorList: [FatigueFactor] = []

        let sessionCount = thisWeek.count
        let frequencyScore = min(30, Double(sessionCount) * 6)
        score += frequencyScore
        if sessionCount >= 5 {
            factorList.append(FatigueFactor(icon: "calendar", text: "\(sessionCount) sessions this week", color: Color(hex: "DC2626")))
        } else if sessionCount >= 3 {
            factorList.append(FatigueFactor(icon: "calendar", text: "\(sessionCount) sessions this week", color: Color(hex: "F59E0B")))
        }

        let totalVolume = thisWeek.reduce(0.0) { total, session in
            total + session.exercises.reduce(0.0) { t, ex in
                t + ex.sets.filter(\.isCompleted).reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
            }
        }
        let volumeScore = min(30, totalVolume / 1000)
        score += volumeScore
        if totalVolume > 10000 {
            factorList.append(FatigueFactor(icon: "scalemass.fill", text: String(format: "%.0f kg total volume", totalVolume), color: Color(hex: "F59E0B")))
        }

        let rpes = thisWeek.compactMap(\.subjectiveRPE)
        if !rpes.isEmpty {
            let avgRPE = Double(rpes.reduce(0, +)) / Double(rpes.count)
            let rpeScore = max(0, (avgRPE - 6) * 10)
            score += rpeScore
            if avgRPE >= 8.5 {
                factorList.append(FatigueFactor(icon: "flame.fill", text: String(format: "Avg RPE %.1f (high)", avgRPE), color: Color(hex: "DC2626")))
            } else if avgRPE >= 7 {
                factorList.append(FatigueFactor(icon: "flame", text: String(format: "Avg RPE %.1f", avgRPE), color: Color(hex: "F59E0B")))
            }
        }

        let consecutiveDays = countConsecutiveTrainingDays(sessions: thisWeek)
        if consecutiveDays >= 3 {
            score += Double(consecutiveDays) * 3
            factorList.append(FatigueFactor(icon: "arrow.right.arrow.left", text: "\(consecutiveDays) consecutive training days", color: Color(hex: "DC2626")))
        }

        fatigueScore = min(100, Int(score))
        factors = Array(factorList.prefix(4))

        let lastWeekScore = computeScore(for: lastWeek)
        if fatigueScore > lastWeekScore + 15 {
            trend = .rising
        } else if fatigueScore < lastWeekScore - 15 {
            trend = .dropping
        } else {
            trend = .stable
        }
    }

    private func computeScore(for weekSessions: [TrainingSession]) -> Int {
        let count = weekSessions.count
        let vol = weekSessions.reduce(0.0) { total, session in
            total + session.exercises.reduce(0.0) { t, ex in
                t + ex.sets.filter(\.isCompleted).reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
            }
        }
        return min(100, Int(Double(count) * 6 + vol / 1000))
    }

    private func countConsecutiveTrainingDays(sessions: [TrainingSession]) -> Int {
        let calendar = Calendar.current
        let dates = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        var maxStreak = 0
        var current = 0
        for dayOffset in (0..<7).reversed() {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: Date()))!
            if dates.contains(day) {
                current += 1
                maxStreak = max(maxStreak, current)
            } else {
                current = 0
            }
        }
        return maxStreak
    }
}

private struct FatigueFactor: Identifiable {
    let icon: String
    let text: String
    let color: Color
    var id: String { text }
}

private enum FatigueTrend {
    case rising, stable, dropping

    var icon: String {
        switch self {
        case .rising: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .dropping: return "arrow.down.right"
        }
    }

    var message: String {
        switch self {
        case .rising: return "Fatigue rising vs last week — consider lighter sessions"
        case .stable: return "Fatigue stable — manageable training load"
        case .dropping: return "Fatigue dropping — good recovery trend"
        }
    }

    var color: Color {
        switch self {
        case .rising: return Color(hex: "DC2626")
        case .stable: return Color(hex: "F59E0B")
        case .dropping: return Color(hex: "059669")
        }
    }
}
