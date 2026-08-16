import SwiftUI
import Charts

// MARK: - Workout Density Card
// Volume per minute — the most underrated performance metric. Two sessions
// with identical volume but different durations have very different
// metabolic demands. Higher density = more efficient training, better
// conditioning, higher calorie burn. Used by advanced coaches to track
// work capacity independent of absolute load.

struct WorkoutDensityCard: View {

    @Environment(AppState.self) private var appState
    var sessions: [TrainingSession]

    @State private var data: [DensityPoint] = []
    @State private var avgDensity: Double = 0
    @State private var trend: Double? = nil
    @State private var bestSession: DensityPoint? = nil

    private var useLbs: Bool { appState.profile.prefersLbs }
    private var unit: String { useLbs ? "lbs" : "kg" }

    var body: some View {
        Group {
            if data.count >= 3 {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "gauge.with.dots.needle.33percent")
                            .foregroundColor(Pulse.critical)
                        Text("Workout Density")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if let t = trend {
                            HStack(spacing: 3) {
                                Image(systemName: t >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 9, weight: .bold))
                                Text(String(format: "%+.0f%%", t))
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(t > 0 ? Pulse.positive : Pulse.critical)
                        }
                    }

                    HStack(spacing: 16) {
                        densityStat(
                            title: "Current",
                            value: String(format: "%.0f", useLbs ? (data.last?.density ?? 0) * 2.20462 : (data.last?.density ?? 0)),
                            subtitle: "\(unit)/min"
                        )
                        densityStat(
                            title: "Average",
                            value: String(format: "%.0f", useLbs ? avgDensity * 2.20462 : avgDensity),
                            subtitle: "\(unit)/min"
                        )
                        if let best = bestSession {
                            densityStat(
                                title: "Best",
                                value: String(format: "%.0f", useLbs ? best.density * 2.20462 : best.density),
                                subtitle: "\(unit)/min"
                            )
                        }
                    }

                    Chart(data) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Density", useLbs ? point.density * 2.20462 : point.density)
                        )
                        .foregroundStyle(
                            point.density >= avgDensity
                                ? Pulse.positive.opacity(0.7)
                                : Pulse.critical.opacity(0.5)
                        )
                        .cornerRadius(3)

                        RuleMark(y: .value("Avg", useLbs ? avgDensity * 2.20462 : avgDensity))
                            .foregroundStyle(Color.secondary.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                    .frame(height: 65)
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 7)) {
                            AxisValueLabel(format: .dateTime.day().month())
                                .font(.system(size: 8))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                            AxisValueLabel()
                                .font(.system(size: 8))
                        }
                    }

                    Text("Volume ÷ duration. Higher density = more efficient sessions. Green bars are above your average.")
                        .font(.system(size: 9))
                        .foregroundColor(Pulse.textTertiary)
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func densityStat(title: String, value: String, subtitle: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(Pulse.textTertiary)
            Text(subtitle)
                .font(.system(size: 7))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    private func compute() {
        let completed = sessions
            .filter { $0.isCompleted && $0.durationMinutes > 0 }
            .sorted { $0.date < $1.date }
            .suffix(15)

        guard completed.count >= 3 else { return }

        data = completed.map { session in
            let vol = session.exercises.reduce(0.0) { total, ex in
                total + ex.sets.filter(\.isCompleted).reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
            }
            let density = vol / Double(max(1, session.durationMinutes))
            return DensityPoint(date: session.date, density: density, volume: vol, duration: session.durationMinutes)
        }

        avgDensity = data.map(\.density).reduce(0, +) / Double(data.count)
        bestSession = data.max(by: { $0.density < $1.density })

        if data.count >= 4 {
            let firstHalf = Array(data.prefix(data.count / 2))
            let secondHalf = Array(data.suffix(data.count / 2))
            let avgFirst = firstHalf.map(\.density).reduce(0, +) / Double(firstHalf.count)
            let avgSecond = secondHalf.map(\.density).reduce(0, +) / Double(secondHalf.count)
            trend = avgFirst > 0 ? ((avgSecond - avgFirst) / avgFirst) * 100 : nil
        }
    }
}

private struct DensityPoint: Identifiable {
    let id = UUID()
    let date: Date
    let density: Double
    let volume: Double
    let duration: Int
}
