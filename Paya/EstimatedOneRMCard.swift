import SwiftUI
import Charts

struct EstimatedOneRMCard: View {

    @Environment(AppState.self) private var appState
    var sessions: [TrainingSession]

    @State private var exercises: [E1RMExercise] = []
    @State private var selectedIndex: Int = 0

    private var useLbs: Bool { appState.profile.prefersLbs }

    var body: some View {
        Group {
            if !exercises.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(Color(hex: "F59E0B"))
                        Text("Estimated 1RM Tracker")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(exercises.indices, id: \.self) { i in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) { selectedIndex = i }
                                } label: {
                                    Text(exercises[i].name)
                                        .font(.system(size: 10, weight: .semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(selectedIndex == i
                                            ? Color(hex: "F59E0B").opacity(0.2)
                                            : Color(.tertiarySystemBackground))
                                        .foregroundColor(selectedIndex == i
                                            ? Color(hex: "F59E0B")
                                            : .secondary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if selectedIndex < exercises.count {
                        let ex = exercises[selectedIndex]

                        HStack(spacing: 16) {
                            VStack(spacing: 2) {
                                let current = useLbs ? ex.currentE1RM * 2.20462 : ex.currentE1RM
                                Text(String(format: "%.0f", current))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                Text(useLbs ? "lbs" : "kg")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }

                            if let change = ex.changePercent {
                                VStack(spacing: 2) {
                                    HStack(spacing: 2) {
                                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                                            .font(.system(size: 9, weight: .bold))
                                        Text(String(format: "%+.1f%%", change))
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                    }
                                    .foregroundColor(change >= 0 ? Color(hex: "059669") : Color(hex: "DC2626"))
                                    Text("trend")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(ex.dataPoints.count) sessions")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                if let best = ex.allTimeBest {
                                    let bestDisplay = useLbs ? best * 2.20462 : best
                                    Text(String(format: "Best: %.0f %@", bestDisplay, useLbs ? "lbs" : "kg"))
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(Color(hex: "F59E0B"))
                                }
                            }
                        }

                        if ex.dataPoints.count >= 2 {
                            Chart(ex.dataPoints) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("e1RM", useLbs ? point.e1rm * 2.20462 : point.e1rm)
                                )
                                .foregroundStyle(Color(hex: "F59E0B"))
                                .interpolationMethod(.catmullRom)

                                AreaMark(
                                    x: .value("Date", point.date),
                                    y: .value("e1RM", useLbs ? point.e1rm * 2.20462 : point.e1rm)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "F59E0B").opacity(0.2), .clear],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)

                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("e1RM", useLbs ? point.e1rm * 2.20462 : point.e1rm)
                                )
                                .foregroundStyle(Color(hex: "F59E0B"))
                                .symbolSize(16)
                            }
                            .frame(height: 80)
                            .chartYScale(domain: .automatic(includesZero: false))
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day, count: 14)) {
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
                        }
                    }

                    Text("Epley formula: weight × (1 + reps ÷ 30). Tracks your strength ceiling over time.")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func compute() {
        let completed = sessions.filter(\.isCompleted).sorted { $0.date < $1.date }
        var exerciseData: [String: [(date: Date, e1rm: Double)]] = [:]

        for session in completed {
            for log in session.exercises {
                let best = log.sets.filter(\.isCompleted)
                    .map { set -> Double in
                        guard set.reps > 0 else { return set.weightKg }
                        return set.weightKg * (1 + Double(set.reps) / 30.0)
                    }
                    .max() ?? 0
                guard best > 0 else { continue }
                exerciseData[log.exerciseName, default: []].append((session.date, best))
            }
        }

        exercises = exerciseData
            .filter { $0.value.count >= 2 }
            .map { name, points in
                let sorted = points.sorted { $0.date < $1.date }
                let current = sorted.last?.e1rm ?? 0
                let first = sorted.first?.e1rm ?? 0
                let change = first > 0 ? ((current - first) / first) * 100 : nil
                let best = sorted.map(\.e1rm).max()

                return E1RMExercise(
                    name: name,
                    currentE1RM: current,
                    changePercent: change,
                    allTimeBest: best,
                    dataPoints: sorted.suffix(20).map {
                        E1RMPoint(date: $0.date, e1rm: $0.e1rm)
                    }
                )
            }
            .sorted { $0.currentE1RM > $1.currentE1RM }
            .prefix(10)
            .map { $0 }

        selectedIndex = 0
    }
}

private struct E1RMExercise: Identifiable {
    let name: String
    let currentE1RM: Double
    let changePercent: Double?
    let allTimeBest: Double?
    let dataPoints: [E1RMPoint]
    var id: String { name }
}

private struct E1RMPoint: Identifiable {
    let id = UUID()
    let date: Date
    let e1rm: Double
}
