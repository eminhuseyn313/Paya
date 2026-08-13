import SwiftUI

struct TrainingSplitCard: View {

    var sessions: [TrainingSession]

    @State private var splitDays: [SplitDay] = []
    @State private var detectedSplit: String = ""
    @State private var avgRestDays: Double = 0

    var body: some View {
        Group {
            if splitDays.count >= 3 {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(Color(hex: "8B5CF6"))
                        Text("Training Split")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(detectedSplit)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color(hex: "8B5CF6"))
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 4) {
                        ForEach(splitDays) { day in
                            VStack(spacing: 4) {
                                Text(day.dayLabel)
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.secondary)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(day.color.opacity(0.2))
                                    .frame(height: 32)
                                    .overlay(
                                        Text(day.muscleLabel)
                                            .font(.system(size: 7, weight: .semibold))
                                            .foregroundColor(day.color)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .padding(2)
                                    )
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    HStack(spacing: 16) {
                        splitStat(label: "Avg rest between", value: String(format: "%.1f days", avgRestDays))
                        splitStat(label: "Sessions/week", value: String(format: "%.1f", Double(splitDays.filter { !$0.isRest }.count) / max(1, Double(splitDays.count) / 7)))
                        splitStat(label: "Pattern", value: detectedSplit)
                    }

                    Text("Based on your last 4 weeks of training. The split is detected from the primary muscle groups trained each session day.")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func splitStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
    }

    private func compute() {
        let calendar = Calendar.current
        let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: Date())!
        let recent = sessions
            .filter { $0.isCompleted && $0.date >= fourWeeksAgo }
            .sorted { $0.date < $1.date }

        guard recent.count >= 3 else { return }

        var dayMuscles: [Int: [String: Int]] = [:]

        for session in recent {
            let weekday = calendar.component(.weekday, from: session.date)
            for log in session.exercises {
                let mg = log.muscleGroup.isEmpty ? "Other" : log.muscleGroup
                dayMuscles[weekday, default: [:]][mg, default: 0] += log.sets.filter(\.isCompleted).count
            }
        }

        let dayNames = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var days: [SplitDay] = []

        for wd in 1...7 {
            if let muscles = dayMuscles[wd] {
                let top = muscles.sorted { $0.value > $1.value }.prefix(2)
                let label = top.map(\.key).joined(separator: "\n")
                let primary = top.first?.key ?? ""
                days.append(SplitDay(
                    dayLabel: dayNames[wd],
                    muscleLabel: label,
                    isRest: false,
                    color: colorForMuscle(primary)
                ))
            } else {
                days.append(SplitDay(
                    dayLabel: dayNames[wd],
                    muscleLabel: "Rest",
                    isRest: true,
                    color: .secondary
                ))
            }
        }

        splitDays = days

        let trainingDayCount = days.filter { !$0.isRest }.count
        let restDayCount = days.filter(\.isRest).count
        avgRestDays = trainingDayCount > 1 ? Double(restDayCount) / Double(trainingDayCount) : 0

        let uniqueMuscles = Set(dayMuscles.values.flatMap { $0.keys })
        if trainingDayCount >= 5 {
            detectedSplit = uniqueMuscles.count > 4 ? "Bro Split" : "PPL"
        } else if trainingDayCount >= 3 {
            let hasUpperLower = uniqueMuscles.contains(where: { $0.lowercased().contains("chest") || $0.lowercased().contains("back") })
                && uniqueMuscles.contains(where: { $0.lowercased().contains("quad") || $0.lowercased().contains("glute") })
            detectedSplit = hasUpperLower ? "Upper/Lower" : "Full Body"
        } else {
            detectedSplit = "Full Body"
        }
    }

    private func colorForMuscle(_ muscle: String) -> Color {
        let m = muscle.lowercased()
        if m.contains("chest") || m.contains("tricep") { return Color(hex: "DC2626") }
        if m.contains("back") || m.contains("bicep") { return Color(hex: "2563EB") }
        if m.contains("shoulder") || m.contains("delt") { return Color(hex: "F59E0B") }
        if m.contains("quad") || m.contains("glute") || m.contains("leg") { return Color(hex: "059669") }
        if m.contains("ham") || m.contains("calv") { return Color(hex: "0891B2") }
        if m.contains("core") || m.contains("ab") { return Color(hex: "8B5CF6") }
        return Color(hex: "B45309")
    }
}

private struct SplitDay: Identifiable {
    let dayLabel: String
    let muscleLabel: String
    let isRest: Bool
    let color: Color
    var id: String { dayLabel }
}
