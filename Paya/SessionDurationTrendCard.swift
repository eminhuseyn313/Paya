import SwiftUI
import Charts

struct SessionDurationTrendCard: View {

    var sessions: [TrainingSession]

    @State private var data: [DurationPoint] = []
    @State private var avgDuration: Int = 0
    @State private var trend: Double? = nil

    var body: some View {
        Group {
            if data.count >= 3 {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .foregroundColor(Color(hex: "0891B2"))
                        Text("Session Duration")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if let t = trend {
                            HStack(spacing: 3) {
                                Image(systemName: t >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 9, weight: .bold))
                                Text(String(format: "%+.0f%%", t))
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(abs(t) < 15 ? Color(hex: "059669") : Color(hex: "F59E0B"))
                        }
                    }

                    Chart(data) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Minutes", point.minutes)
                        )
                        .foregroundStyle(Color(hex: "0891B2"))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Minutes", point.minutes)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "0891B2").opacity(0.2), .clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Minutes", point.minutes)
                        )
                        .foregroundStyle(Color(hex: "0891B2"))
                        .symbolSize(14)

                        RuleMark(y: .value("Avg", avgDuration))
                            .foregroundStyle(Color.secondary.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                    .frame(height: 70)
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

                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: "0891B2")).frame(width: 5, height: 5)
                            Text("Avg: \(avgDuration) min")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(width: 12, height: 1)
                            Text("Average line")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func compute() {
        let completed = sessions
            .filter { $0.isCompleted && $0.durationMinutes > 0 }
            .sorted { $0.date < $1.date }
            .suffix(20)

        guard completed.count >= 3 else { return }

        data = completed.map { DurationPoint(date: $0.date, minutes: $0.durationMinutes) }
        avgDuration = completed.map(\.durationMinutes).reduce(0, +) / completed.count

        if let first = completed.first, let last = completed.last, first.durationMinutes > 0 {
            trend = Double(last.durationMinutes - first.durationMinutes) / Double(first.durationMinutes) * 100
        }
    }
}

private struct DurationPoint: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Int
}
