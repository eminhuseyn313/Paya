import SwiftUI
import Charts

struct ExerciseSparklineCard: View {

    @Environment(AppState.self) private var appState
    var sessions: [TrainingSession]

    @State private var selectedExercise: String? = nil
    @State private var sparklines: [SparklineData] = []

    private var useLbs: Bool { appState.profile.prefersLbs }

    var body: some View {
        Group {
            if !sparklines.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "chart.xyaxis.line")
                            .foregroundColor(Pulse.hydration)
                        Text("Exercise Trends")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(sparklines) { data in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedExercise = selectedExercise == data.name ? nil : data.name
                                    }
                                } label: {
                                    Text(data.shortName)
                                        .font(.system(size: 11, weight: selectedExercise == data.name ? .bold : .medium))
                                        .foregroundColor(selectedExercise == data.name ? .white : .primary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            selectedExercise == data.name
                                                ? Pulse.hydration
                                                : Pulse.surfaceElevatedFallback
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(PulsePress())
                            }
                        }
                    }

                    if let selected = sparklines.first(where: { $0.name == selectedExercise }) ?? sparklines.first {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(selected.name)
                                    .font(.caption.weight(.semibold))
                                Spacer()
                                if let trend = selected.trend {
                                    HStack(spacing: 3) {
                                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                                            .font(.system(size: 9, weight: .bold))
                                        Text(String(format: "%+.0f%%", trend))
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .foregroundColor(trend >= 0 ? Pulse.positive : Pulse.critical)
                                }
                            }

                            Chart(selected.points) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Weight", useLbs ? point.weightKg * 2.20462 : point.weightKg)
                                )
                                .foregroundStyle(Pulse.hydration)
                                .interpolationMethod(.catmullRom)

                                AreaMark(
                                    x: .value("Date", point.date),
                                    y: .value("Weight", useLbs ? point.weightKg * 2.20462 : point.weightKg)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Pulse.hydration.opacity(0.2), .clear],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)

                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("Weight", useLbs ? point.weightKg * 2.20462 : point.weightKg)
                                )
                                .foregroundStyle(Pulse.hydration)
                                .symbolSize(12)
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

                            HStack(spacing: 12) {
                                if let first = selected.points.first, let last = selected.points.last {
                                    let startW = useLbs ? first.weightKg * 2.20462 : first.weightKg
                                    let endW = useLbs ? last.weightKg * 2.20462 : last.weightKg
                                    miniStat(
                                        label: "Start",
                                        value: String(format: "%.0f %@", startW, useLbs ? "lbs" : "kg")
                                    )
                                    miniStat(
                                        label: "Current",
                                        value: String(format: "%.0f %@", endW, useLbs ? "lbs" : "kg")
                                    )
                                    miniStat(
                                        label: "Sessions",
                                        value: "\(selected.points.count)"
                                    )
                                }
                            }
                        }
                    }
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { buildSparklines() }
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(Pulse.textTertiary)
        }
    }

    private func buildSparklines() {
        var exerciseData: [String: [(date: Date, weight: Double)]] = [:]

        for session in sessions.filter(\.isCompleted).sorted(by: { $0.date < $1.date }) {
            for log in session.exercises {
                let completedSets = log.sets.filter(\.isCompleted)
                guard !completedSets.isEmpty else { continue }
                let maxWeight = completedSets.map(\.weightKg).max() ?? 0
                guard maxWeight > 0 else { continue }
                exerciseData[log.exerciseName, default: []].append((session.date, maxWeight))
            }
        }

        sparklines = exerciseData
            .filter { $0.value.count >= 3 }
            .map { name, points in
                let sparkPoints = points.map { SparklinePoint(date: $0.date, weightKg: $0.weight) }
                var trend: Double? = nil
                if let first = points.first, let last = points.last, first.weight > 0 {
                    trend = ((last.weight - first.weight) / first.weight) * 100
                }
                let short = name.split(separator: " ").prefix(2).joined(separator: " ")
                return SparklineData(name: name, shortName: short, points: sparkPoints, trend: trend)
            }
            .sorted { ($0.points.count, $0.name) > ($1.points.count, $1.name) }

        if selectedExercise == nil {
            selectedExercise = sparklines.first?.name
        }
    }
}

private struct SparklinePoint: Identifiable {
    let id = UUID()
    let date: Date
    let weightKg: Double
}

private struct SparklineData: Identifiable {
    let name: String
    let shortName: String
    let points: [SparklinePoint]
    let trend: Double?
    var id: String { name }
}
