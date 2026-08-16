import SwiftUI
import Charts

struct RPETrendCard: View {

    var sessions: [TrainingSession]

    @State private var data: [RPEPoint] = []
    @State private var avgRPE: Double = 0
    @State private var trend: Double? = nil

    var body: some View {
        Group {
            if data.count >= 3 {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(Pulse.critical)
                        Text("RPE Trend")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if let t = trend {
                            HStack(spacing: 3) {
                                Image(systemName: t >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 9, weight: .bold))
                                Text(String(format: "%+.1f", t))
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(t > 0.5 ? Pulse.critical : Pulse.positive)
                        }
                    }

                    Chart(data) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("RPE", point.rpe)
                        )
                        .foregroundStyle(
                            point.rpe >= 9 ? Pulse.critical :
                            point.rpe >= 7 ? Pulse.nutrition :
                            Pulse.positive
                        )
                        .cornerRadius(3)

                        RuleMark(y: .value("Avg", avgRPE))
                            .foregroundStyle(Color.secondary.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                    .frame(height: 70)
                    .chartYScale(domain: 1...10)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day, count: 7)) {
                            AxisValueLabel(format: .dateTime.day().month())
                                .font(.system(size: 8))
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: [4, 6, 8, 10]) {
                            AxisValueLabel()
                                .font(.system(size: 8))
                        }
                    }

                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Circle().fill(Pulse.critical).frame(width: 5, height: 5)
                            Text(String(format: "Avg: %.1f RPE", avgRPE))
                                .font(.system(size: 9))
                                .foregroundColor(Pulse.textTertiary)
                        }
                        HStack(spacing: 4) {
                            Circle().fill(Pulse.positive).frame(width: 5, height: 5)
                            Text("\(data.count) rated sessions")
                                .font(.system(size: 9))
                                .foregroundColor(Pulse.textTertiary)
                        }
                    }

                    Text("Session RPE from your post-workout reflection. Sustained RPE > 9 increases injury risk.")
                        .font(.system(size: 9))
                        .foregroundColor(Pulse.textTertiary)
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func compute() {
        let rated = sessions
            .filter { $0.isCompleted && $0.subjectiveRPE != nil }
            .sorted { $0.date < $1.date }
            .suffix(20)

        guard rated.count >= 3 else { return }

        data = rated.map { RPEPoint(date: $0.date, rpe: Double($0.subjectiveRPE ?? 0)) }
        avgRPE = data.map(\.rpe).reduce(0, +) / Double(data.count)

        if data.count >= 4 {
            let firstHalf = Array(data.prefix(data.count / 2))
            let secondHalf = Array(data.suffix(data.count / 2))
            let avgFirst = firstHalf.map(\.rpe).reduce(0, +) / Double(firstHalf.count)
            let avgSecond = secondHalf.map(\.rpe).reduce(0, +) / Double(secondHalf.count)
            trend = avgSecond - avgFirst
        }
    }
}

private struct RPEPoint: Identifiable {
    let id = UUID()
    let date: Date
    let rpe: Double
}
