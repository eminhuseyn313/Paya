import SwiftUI

// MARK: - Mindful Minutes Card
// Trailing-7-day total from HealthKit's mindfulSession data (Breathe/
// Mindfulness on Watch, or any third-party app writing to HealthKit) — a
// stress-management input the correlation builder can be pointed at
// alongside flare/recovery data.

struct MindfulMinutesCard: View {
    @State private var minutes: Double = 0
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(Pulse.ai)
                Text("Mindful Minutes")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            if isLoading {
                SwiftUI.ProgressView()
                    .padding(.vertical, 8)
            } else if minutes > 0 {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(Int(minutes))")
                        .font(.title2.bold())
                    Text("min this week")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                }
            } else {
                Text("No mindfulness sessions logged this week — Breathe/Mindfulness on your Watch, or any app that writes to Health, will show up here.")
                    .font(.caption2)
                    .foregroundColor(Pulse.textTertiary)
            }
        }
        .payaCard(padding: 14)
        .task {
            minutes = await HealthKitManager.shared.fetchWeeklyMindfulMinutes()
            isLoading = false
        }
    }
}
