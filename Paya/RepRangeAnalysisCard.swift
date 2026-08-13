import SwiftUI

// MARK: - Rep Range Analysis Card
// Shows the distribution of completed sets across rep ranges.
// Grounded in Schoenfeld (2021) meta-analysis: 1-5 reps = strength,
// 6-12 = hypertrophy, 13-20 = endurance, 20+ = muscular endurance.
// Helps users understand if their training aligns with their goals.

struct RepRangeAnalysisCard: View {

    var sessions: [TrainingSession]

    @State private var zones: [RepZone] = []
    @State private var totalSets: Int = 0
    @State private var dominantZone: String = ""

    var body: some View {
        Group {
            if totalSets >= 10 {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "chart.pie.fill")
                            .foregroundColor(Color(hex: "8B5CF6"))
                        Text("Rep Range Distribution")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(totalSets) total sets")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 6) {
                        ForEach(zones) { zone in
                            VStack(spacing: 4) {
                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.tertiarySystemBackground))
                                        .frame(height: 60)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [zone.color.opacity(0.4), zone.color],
                                                startPoint: .top, endPoint: .bottom
                                            )
                                        )
                                        .frame(height: max(4, 60 * CGFloat(zone.percent) / 100))
                                }

                                Text(String(format: "%.0f%%", zone.percent))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(zone.color)

                                Text(zone.label)
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                Text(zone.repRange)
                                    .font(.system(size: 7))
                                    .foregroundColor(.secondary)

                                Text(zone.purpose)
                                    .font(.system(size: 6, weight: .medium))
                                    .foregroundColor(zone.color)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "F59E0B"))
                            .padding(.top, 1)
                        Text(insight)
                            .font(.system(size: 10))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("Based on Schoenfeld (2021) meta-analysis on rep ranges and training adaptations.")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private var insight: String {
        let hyp = zones.first { $0.label == "Hyp." }?.percent ?? 0
        let str = zones.first { $0.label == "Strength" }?.percent ?? 0
        let end = zones.first { $0.label == "Endur." }?.percent ?? 0

        if hyp > 60 {
            return "Strongly hypertrophy-focused — great for muscle building. Consider adding some heavy 3-5 rep sets for strength."
        } else if str > 50 {
            return "Strength-dominant training. Add some 8-12 rep sets on accessories for muscle growth."
        } else if end > 40 {
            return "High proportion of endurance work. If building muscle is the goal, shift more sets to 6-12 reps."
        } else {
            return "Well-balanced rep distribution across training zones. Good variety for overall development."
        }
    }

    private func compute() {
        let calendar = Calendar.current
        let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: Date())!
        let recent = sessions.filter { $0.isCompleted && $0.date >= fourWeeksAgo }

        var strength = 0, power = 0, hypertrophy = 0, endurance = 0
        var total = 0

        for session in recent {
            for log in session.exercises {
                for set in log.sets where set.isCompleted && set.reps > 0 {
                    total += 1
                    switch set.reps {
                    case 1...3: power += 1
                    case 4...5: strength += 1
                    case 6...12: hypertrophy += 1
                    default: endurance += 1
                    }
                }
            }
        }

        guard total >= 10 else { return }
        totalSets = total

        let t = Double(total)
        zones = [
            RepZone(label: "Power", repRange: "1-3", purpose: "Max Strength",
                    percent: Double(power) / t * 100, color: Color(hex: "DC2626")),
            RepZone(label: "Strength", repRange: "4-5", purpose: "Strength",
                    percent: Double(strength) / t * 100, color: Color(hex: "F59E0B")),
            RepZone(label: "Hyp.", repRange: "6-12", purpose: "Muscle",
                    percent: Double(hypertrophy) / t * 100, color: Color(hex: "2563EB")),
            RepZone(label: "Endur.", repRange: "13+", purpose: "Endurance",
                    percent: Double(endurance) / t * 100, color: Color(hex: "059669")),
        ]

        dominantZone = zones.max(by: { $0.percent < $1.percent })?.label ?? ""
    }
}

private struct RepZone: Identifiable {
    let label: String
    let repRange: String
    let purpose: String
    let percent: Double
    let color: Color
    var id: String { label }
}
