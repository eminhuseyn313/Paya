import SwiftUI
import Charts

struct WeeklyVolumeTrendCard: View {

    @Environment(AppState.self) private var appState
    let sessions: [TrainingSession]

    @State private var metric: VolumeMetric = .volume

    enum VolumeMetric: String, CaseIterable {
        case volume = "Volume"
        case sessions = "Sessions"
        case sets = "Sets"
    }

    private var weeklyData: [WeekPoint] {
        let calendar = Calendar.current
        let now = Date()

        return (0..<8).reversed().compactMap { weeksAgo -> WeekPoint? in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: now) else { return nil }
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart))!
            guard let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) else { return nil }

            let weekSessions = sessions.filter { $0.date >= startOfWeek && $0.date < endOfWeek }

            let value: Double
            switch metric {
            case .volume:
                var vol: Double = 0
                for s in weekSessions {
                    for ex in s.exercises {
                        for set in ex.sets where set.isCompleted {
                            vol += set.weightKg * Double(set.reps)
                        }
                    }
                }
                value = appState.profile.prefersLbs ? vol * 2.20462 : vol
            case .sessions:
                value = Double(weekSessions.count)
            case .sets:
                value = Double(weekSessions.reduce(0) { total, s in
                    total + s.exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
                })
            }

            let label = weeksAgo == 0 ? "This" : weeksAgo == 1 ? "Last" : "\(weeksAgo)w"
            return WeekPoint(label: label, value: value, weeksAgo: weeksAgo)
        }
    }

    private var trend: Double? {
        let data = weeklyData.filter { $0.value > 0 }
        guard data.count >= 2,
              let previous = data.dropLast().last,
              let current = data.last,
              previous.value > 0 else { return nil }
        return ((current.value - previous.value) / previous.value) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(Pulse.hydration)
                Text("Weekly Trends")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let trend {
                    HStack(spacing: 3) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(String(format: "%+.0f%%", trend))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(trend >= 0 ? Pulse.positive : Pulse.critical)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((trend >= 0 ? Pulse.positive : Pulse.critical).opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            Picker("", selection: $metric) {
                ForEach(VolumeMetric.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            Chart(weeklyData) { point in
                BarMark(
                    x: .value("Week", point.label),
                    y: .value(metric.rawValue, point.value)
                )
                .foregroundStyle(
                    point.weeksAgo == 0
                        ? Pulse.hydration
                        : Pulse.hydration.opacity(0.35)
                )
                .cornerRadius(4)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(formatAxisValue(v))
                                .font(.system(size: 9))
                                .foregroundColor(Pulse.textTertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                        .font(.system(size: 9))
                }
            }
            .frame(height: 140)

            if metric == .volume {
                HStack {
                    Text("Total: \(formatVolume(weeklyData.last?.value ?? 0))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Pulse.textTertiary)
                    Spacer()
                    Text("8-week avg: \(formatVolume(weeklyData.map(\.value).reduce(0, +) / max(1, Double(weeklyData.filter { $0.value > 0 }.count))))")
                        .font(.system(size: 10))
                        .foregroundColor(Pulse.textTertiary)
                }
            }
        }
        .payaCard(padding: 14)
    }

    private func formatAxisValue(_ v: Double) -> String {
        if v >= 1000 { return String(format: "%.0fk", v / 1000) }
        return String(format: "%.0f", v)
    }

    private func formatVolume(_ v: Double) -> String {
        let unit = appState.profile.prefersLbs ? "lbs" : "kg"
        if v >= 1000 { return String(format: "%.1fk %@", v / 1000, unit) }
        return String(format: "%.0f %@", v, unit)
    }
}

private struct WeekPoint: Identifiable {
    let label: String
    let value: Double
    let weeksAgo: Int
    var id: String { label }
}
