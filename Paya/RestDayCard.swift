import SwiftUI

struct RestDayCard: View {

    var readinessScore: Int?
    var lastSessionDaysAgo: Int?

    private var activities: [RecoveryActivity] {
        var list: [RecoveryActivity] = []

        if let score = readinessScore, score < 60 {
            list.append(RecoveryActivity(
                icon: "bed.double.fill",
                title: "Prioritize sleep",
                detail: "Your readiness is low — aim for 8+ hours tonight",
                colorHex: "8B5CF6"
            ))
        }

        list.append(RecoveryActivity(
            icon: "figure.walk",
            title: "Light walk",
            detail: "20-30 min at a conversational pace — boosts recovery without adding fatigue",
            colorHex: "059669"
        ))

        list.append(RecoveryActivity(
            icon: "figure.flexibility",
            title: "Stretch & mobility",
            detail: "10 min focusing on hips, shoulders, and thoracic spine",
            colorHex: "2563EB"
        ))

        if let days = lastSessionDaysAgo, days >= 2 {
            list.append(RecoveryActivity(
                icon: "drop.fill",
                title: "Hydration focus",
                detail: "\(days) days since your last session — stay ahead on water for tomorrow",
                colorHex: "0891B2"
            ))
        }

        list.append(RecoveryActivity(
            icon: "fork.knife",
            title: "Hit your protein",
            detail: "Rest days need the same protein as training days — muscles rebuild now",
            colorHex: "F59E0B"
        ))

        return list
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .foregroundColor(Pulse.positive)
                Text("Recovery Day")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Active rest")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(Pulse.positive)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Pulse.positive.opacity(0.12))
                    .clipShape(Capsule())
            }

            ForEach(activities.prefix(3), id: \.title) { activity in
                HStack(spacing: 10) {
                    Image(systemName: activity.icon)
                        .font(.caption)
                        .foregroundColor(Color(hex: activity.colorHex))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(activity.title)
                            .font(.caption.weight(.semibold))
                        Text(activity.detail)
                            .font(.caption2)
                            .foregroundColor(Pulse.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .payaCard(padding: 14)
    }
}

private struct RecoveryActivity {
    let icon: String
    let title: String
    let detail: String
    let colorHex: String
}
