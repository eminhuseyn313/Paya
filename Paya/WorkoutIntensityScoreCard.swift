import SwiftUI
import SwiftData

struct WorkoutIntensityScoreCard: View {

    let sessions: [TrainingSession]

    private var recentScores: [IntensityPoint] {
        let sorted = sessions
            .filter(\.isCompleted)
            .sorted { $0.date > $1.date }
            .prefix(10)

        return sorted.reversed().enumerated().map { index, session in
            let score = computeScore(session)
            let label = relativeDay(session.date)
            return IntensityPoint(label: label, score: score, date: session.date, index: index)
        }
    }

    private func computeScore(_ session: TrainingSession) -> Double {
        var score: Double = 0

        let totalVolume = session.exercises.reduce(0.0) { total, ex in
            total + ex.sets.filter(\.isCompleted).reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
        }
        let totalSets = session.exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }

        // Volume component (0-40 points)
        score += min(40, totalVolume / 250)

        // Duration component (0-20 points)
        score += min(20, Double(session.durationMinutes) / 4.5)

        // Sets component (0-20 points)
        score += min(20, Double(totalSets) * 1.2)

        // TRIMP/strain component if available (0-20 points)
        if let trimp = session.sessionTrimpScore, trimp > 0 {
            score += min(20, trimp / 10)
        } else {
            // Without HR data, distribute remaining points by exercise count
            let exerciseCount = session.exercises.filter { $0.sets.contains(where: \.isCompleted) }.count
            score += min(20, Double(exerciseCount) * 3)
        }

        return min(100, score)
    }

    private func relativeDay(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Yest."
        default: return date.formatted(.dateTime.weekday(.abbreviated))
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 75 { return Pulse.critical }
        if score >= 50 { return Pulse.nutrition }
        if score >= 25 { return Pulse.positive }
        return Pulse.hydration
    }

    private func scoreLabel(_ score: Double) -> String {
        if score >= 75 { return "Overreaching" }
        if score >= 50 { return "Optimal" }
        if score >= 25 { return "Light" }
        return "Recovery"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bolt.heart.fill")
                    .foregroundColor(Pulse.nutrition)
                Text("Session Intensity")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let latest = recentScores.last {
                    Text(scoreLabel(latest.score))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(scoreColor(latest.score))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(scoreColor(latest.score).opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if recentScores.isEmpty {
                Text("Complete sessions to see intensity trends")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(recentScores) { point in
                        VStack(spacing: 4) {
                            Text(String(format: "%.0f", point.score))
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(scoreColor(point.score))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [scoreColor(point.score).opacity(0.6), scoreColor(point.score)],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(height: max(8, CGFloat(point.score) * 0.8))

                            Text(point.label)
                                .font(.system(size: 7))
                                .foregroundColor(Pulse.textTertiary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 100)

                HStack(spacing: 16) {
                    IntensityLegend(color: Pulse.hydration, label: "0–24 Recovery")
                    IntensityLegend(color: Pulse.positive, label: "25–49 Light")
                    IntensityLegend(color: Pulse.nutrition, label: "50–74 Optimal")
                    IntensityLegend(color: Pulse.critical, label: "75+ Hard")
                }
                .font(.system(size: 8))
            }
        }
        .payaCard(padding: 14)
    }
}

private struct IntensityLegend: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label).foregroundColor(Pulse.textTertiary)
        }
    }
}

private struct IntensityPoint: Identifiable {
    let label: String
    let score: Double
    let date: Date
    let index: Int
    var id: Int { index }
}
