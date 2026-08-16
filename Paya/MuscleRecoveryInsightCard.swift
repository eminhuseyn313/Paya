import SwiftUI
import SwiftData

// MARK: - Muscle Recovery Insight Card

struct MuscleRecoveryInsightCard: View {
    var sessions: [TrainingSession]

    @Environment(\.modelContext) private var modelContext

    private var insight: MuscleRecoveryInsightEngine.Insight? {
        MuscleRecoveryInsightEngine.generate(sessions: sessions, context: modelContext)
    }

    var body: some View {
        if let insight {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "pills.circle.fill")
                        .foregroundColor(Pulse.ai)
                    Text("Recovery Focus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Pulse.textPrimary)
                    CardInfoButton(
                        title: "Recovery Focus",
                        explanation: "Cross-references this week's hardest-loaded muscle group (from Weekly Volume vs. Landmarks) against your actual active supplement stack — not a claim that any supplement targets a specific muscle, just a reminder of which general recovery levers (protein timing, magnesium, sleep) matter most given how much you loaded this week."
                    )
                    Spacer()
                }
                Text(insight.text)
                    .font(.caption)
                    .foregroundColor(Pulse.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .payaCard(padding: 14)
        }
    }
}
