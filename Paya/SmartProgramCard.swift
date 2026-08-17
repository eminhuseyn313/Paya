import SwiftUI
import SwiftData

// MARK: - Smart Program Card
// Dashboard-facing card that shows the top adaptive recommendations
// from SmartProgramEngine. Gives users actionable next-week adjustments
// based on their actual training data — the #2 most-requested feature
// across fitness app users (AI-powered adaptive programming).
// Unlike FitBod/Dr. Muscle which require subscriptions, this runs
// entirely on-device with zero API calls.

struct SmartProgramCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var recommendations: [SmartRecommendation] = []
    @State private var isExpanded = false
    @State private var isLoading = true

    var body: some View {
        Group {
            if !recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    // Header
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(Pulse.ai)
                        Text("Smart program")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("AI-free, on-device")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(Pulse.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Pulse.surfaceElevatedFallback)
                            .clipShape(Capsule())
                    }

                    // Top recommendation always visible
                    if let top = recommendations.first {
                        recommendationRow(top, isTop: true)
                    }

                    // Expandable additional recommendations
                    if recommendations.count > 1 {
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                isExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isExpanded
                                    ? "Show less"
                                    : "\(recommendations.count - 1) more recommendation\(recommendations.count - 1 > 1 ? "s" : "")")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Pulse.ai)
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Pulse.ai)
                            }
                        }
                        .buttonStyle(PulsePress())

                        if isExpanded {
                            ForEach(recommendations.dropFirst()) { rec in
                                recommendationRow(rec, isTop: false)
                            }
                        }
                    }

                    Text("Based on your last 4 weeks of training data. Grounded in Helms et al. (2015) and Schoenfeld & Grgic (2018) evidence-based programming recommendations.")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .payaCard(padding: 14)
            } else if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Analyzing training data…")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func recommendationRow(_ rec: SmartRecommendation, isTop: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: rec.icon)
                .font(.system(size: isTop ? 16 : 13))
                .foregroundColor(rec.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(rec.title)
                    .font(.system(size: isTop ? 13 : 12, weight: .bold))
                    .foregroundColor(Pulse.textPrimary)
                Text(rec.detail)
                    .font(.system(size: isTop ? 11 : 10))
                    .foregroundColor(Pulse.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rec.color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func compute() {
        // Fetch exercises for all days
        let allExercises = CustomSessionStore.allExercisesAcrossDays(context: modelContext)

        recommendations = SmartProgramEngine.generateRecommendations(
            context: modelContext,
            exercises: allExercises,
            appState: appState
        )
        isLoading = false
    }
}
