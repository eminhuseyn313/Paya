import SwiftUI
import SwiftData
import Charts

struct NutritionTrendCard: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var dataPoints: [DayPoint] = []

    struct DayPoint: Identifiable {
        let id = UUID()
        let date: Date
        let calories: Double
        let protein: Double
        let calorieTarget: Double
        let proteinTarget: Double
        let dayLabel: String
    }

    @State private var metric: Metric = .calories
    enum Metric: String, CaseIterable {
        case calories = "Calories"
        case protein = "Protein"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(Color(hex: "2563EB"))
                Text("Nutrition Trend")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Picker("Metric", selection: $metric) {
                    ForEach(Metric.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            if dataPoints.isEmpty {
                Text("Log meals to see your trend here.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                Chart {
                    ForEach(dataPoints) { point in
                        let value = metric == .calories ? point.calories : point.protein
                        let target = metric == .calories ? point.calorieTarget : point.proteinTarget

                        BarMark(
                            x: .value("Day", point.dayLabel),
                            y: .value(metric.rawValue, value)
                        )
                        .foregroundStyle(
                            value >= target * 0.9
                                ? Color(hex: "059669").gradient
                                : Color(hex: "F59E0B").gradient
                        )
                        .cornerRadius(4)

                        RuleMark(y: .value("Target", target))
                            .foregroundStyle(Color(hex: "DC2626").opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(metric == .calories ? "\(Int(v))" : "\(Int(v))g")
                                    .font(.system(size: 9))
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .frame(height: 140)

                HStack(spacing: 12) {
                    legendDot(color: Color(hex: "059669"), label: "On target")
                    legendDot(color: Color(hex: "F59E0B"), label: "Below target")
                    legendDot(color: Color(hex: "DC2626"), label: "Target line", isDashed: true)
                }
                .font(.system(size: 9))
                .foregroundColor(.secondary)

                if let avg = averageValue {
                    Text("7-day avg: \(metric == .calories ? "\(Int(avg)) kcal" : "\(Int(avg))g protein")")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .payaCard(padding: 14)
        .onAppear { loadData() }
    }

    private var averageValue: Double? {
        guard !dataPoints.isEmpty else { return nil }
        let values = dataPoints.map { metric == .calories ? $0.calories : $0.protein }
        let nonZero = values.filter { $0 > 0 }
        guard !nonZero.isEmpty else { return nil }
        return nonZero.reduce(0, +) / Double(nonZero.count)
    }

    private func legendDot(color: Color, label: String, isDashed: Bool = false) -> some View {
        HStack(spacing: 3) {
            if isDashed {
                Rectangle()
                    .fill(color)
                    .frame(width: 12, height: 1.5)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            Text(label)
        }
    }

    private func loadData() {
        let calendar = Calendar.current
        let pid = ActiveProfile.id
        let profile = appState.profile
        var points: [DayPoint] = []
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE"

        for dayOffset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { continue }

            let desc = FetchDescriptor<NutritionLog>(
                predicate: #Predicate<NutritionLog> { $0.profileId == pid && $0.date >= start && $0.date < end }
            )
            let log = try? modelContext.fetch(desc).first

            points.append(DayPoint(
                date: date,
                calories: log?.totalCalories ?? 0,
                protein: log?.totalProtein ?? 0,
                calorieTarget: log?.calorieTarget ?? profile.trainingDayCalories,
                proteinTarget: log?.proteinTarget ?? profile.proteinTargetG,
                dayLabel: dayFormatter.string(from: date)
            ))
        }
        dataPoints = points
    }
}
