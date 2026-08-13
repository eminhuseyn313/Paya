import SwiftUI
import Charts

struct RestTimeAnalyticsCard: View {

    var sessions: [TrainingSession]

    @State private var exerciseRests: [ExerciseRestData] = []
    @State private var overallAvg: Int = 0

    var body: some View {
        Group {
            if !exerciseRests.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(Color(hex: "2563EB"))
                        Text("Rest Time Analytics")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("Avg \(overallAvg)s")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "2563EB"))
                    }

                    Chart(exerciseRests.prefix(8)) { item in
                        BarMark(
                            x: .value("Rest", item.avgRestSeconds),
                            y: .value("Exercise", item.name)
                        )
                        .foregroundStyle(
                            item.avgRestSeconds > 180 ? Color(hex: "DC2626") :
                            item.avgRestSeconds > 120 ? Color(hex: "F59E0B") :
                            Color(hex: "2563EB")
                        )
                        .cornerRadius(4)
                        .annotation(position: .trailing, spacing: 4) {
                            Text("\(item.avgRestSeconds)s")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(height: CGFloat(min(exerciseRests.count, 8)) * 28 + 10)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) {
                            AxisValueLabel()
                                .font(.system(size: 8))
                        }
                    }
                    .chartYAxis {
                        AxisMarks {
                            AxisValueLabel()
                                .font(.system(size: 9))
                        }
                    }

                    HStack(spacing: 12) {
                        restLegend(color: Color(hex: "2563EB"), label: "< 2 min")
                        restLegend(color: Color(hex: "F59E0B"), label: "2-3 min")
                        restLegend(color: Color(hex: "DC2626"), label: "> 3 min")
                    }

                    Text("Average rest between sets per exercise over your last 10 sessions. Compounds typically need 2-3 min, isolations 60-90s.")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func restLegend(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
    }

    private func compute() {
        let recent = sessions
            .filter(\.isCompleted)
            .sorted { $0.date > $1.date }
            .prefix(10)

        var exerciseRestTimes: [String: [Int]] = [:]

        for session in recent {
            let duration = session.durationMinutes
            let exerciseCount = session.exercises.count
            guard duration > 0, exerciseCount > 0 else { continue }

            for log in session.exercises {
                let setCount = log.sets.filter(\.isCompleted).count
                guard setCount > 1 else { continue }

                let totalExerciseTime = (duration * 60) / max(1, exerciseCount)
                let setTime = 30
                let restPerSet = max(30, (totalExerciseTime - setCount * setTime) / max(1, setCount - 1))

                exerciseRestTimes[log.exerciseName, default: []].append(restPerSet)
            }
        }

        exerciseRests = exerciseRestTimes
            .filter { $0.value.count >= 2 }
            .map { name, rests in
                let avg = rests.reduce(0, +) / rests.count
                return ExerciseRestData(name: name, avgRestSeconds: avg)
            }
            .sorted { $0.avgRestSeconds > $1.avgRestSeconds }

        if !exerciseRests.isEmpty {
            overallAvg = exerciseRests.map(\.avgRestSeconds).reduce(0, +) / exerciseRests.count
        }
    }
}

private struct ExerciseRestData: Identifiable {
    let name: String
    let avgRestSeconds: Int
    var id: String { name }
}
