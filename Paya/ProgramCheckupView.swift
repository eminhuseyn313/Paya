import SwiftUI
import SwiftData

// MARK: - Program Check-Up
//
// An on-demand "analyze everything" report, not another passive card in
// an already-long pre-session scroll (see this session's own "wall of
// cards" lessons — a fresh always-visible card was exactly the wrong
// answer here). Opened from the Train tab's toolbar menu.
//
// Consolidates two engines that already existed but were never shown
// together in one place:
//   - SmartProgramEngine: plateau detection + "ready to increase weight"
//     (was only ever wired to SmartProgramCard, which lived on
//     DashboardView/InsightsHubView — dead code, unreachable from any
//     live tab. This is that same engine, finally surfaced.)
//   - ProgramGapEngine: RP volume-landmark gaps across the WHOLE program,
//     not just today's day (ProgramGapCard only shows today's day).
// No new analysis logic — this is a presentation layer over what the app
// already computes, run on demand instead of scattered/orphaned.

struct ProgramCheckupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var recommendations: [SmartRecommendation] = []
    @State private var gaps: [ProgramGapEngine.Gap] = []
    @State private var isLoading = true
    @State private var addedGapIds: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text("Analyzing your program…")
                                .font(.subheadline)
                                .foregroundColor(Pulse.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    } else if recommendations.isEmpty && visibleGaps.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 34))
                                .foregroundColor(Pulse.positive)
                            Text("Nothing to flag right now")
                                .font(.headline)
                            Text("No plateaus, no exercises ready to progress, and every muscle group is in range. Check back after a few more sessions.")
                                .font(.subheadline)
                                .foregroundColor(Pulse.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                        .padding(.horizontal, 24)
                    } else {
                        if !readyRecs.isEmpty {
                            section(title: "Ready to progress", icon: "arrow.up.circle.fill", color: Pulse.positive) {
                                ForEach(readyRecs) { recommendationRow($0) }
                            }
                        }
                        if !plateauRecs.isEmpty {
                            section(title: "Plateaus", icon: "arrow.triangle.2.circlepath", color: Pulse.critical) {
                                ForEach(plateauRecs) { recommendationRow($0) }
                            }
                        }
                        if !visibleGaps.isEmpty {
                            section(title: "Volume gaps", icon: "chart.bar.doc.horizontal.fill", color: Pulse.ai) {
                                ForEach(visibleGaps) { gapRow($0) }
                            }
                        }

                        Text("Ready-to-progress and plateau checks use your last 4 weeks of logged sets, grounded in Helms et al. (2015) and Schoenfeld & Grgic (2018). Volume gaps use Renaissance Periodization's published hypertrophy landmarks (see Progress tab for the full breakdown). All on-device — nothing here calls out to an AI service.")
                            .font(.system(size: 9.5))
                            .foregroundColor(Pulse.textTertiary)
                            .padding(.top, 4)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Program Check-Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    private var readyRecs: [SmartRecommendation] {
        recommendations.filter { $0.type == .weightIncrease }
    }
    private var plateauRecs: [SmartRecommendation] {
        recommendations.filter { $0.type == .exerciseSwap || $0.type == .repRangeShift }
    }
    private var visibleGaps: [ProgramGapEngine.Gap] {
        gaps.filter { !addedGapIds.contains($0.id + $0.targetDayCode) }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(color)
                Text(title).font(.subheadline.weight(.bold))
            }
            content()
        }
    }

    private func recommendationRow(_ rec: SmartRecommendation) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: rec.icon)
                .font(.system(size: 15))
                .foregroundColor(rec.color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(rec.title).font(.system(size: 13, weight: .bold)).foregroundColor(Pulse.textPrimary)
                Text(rec.detail).font(.system(size: 11)).foregroundColor(Pulse.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rec.color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func gapRow(_ gap: ProgramGapEngine.Gap) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(gap.reason)
                .font(.system(size: 12))
                .foregroundColor(Pulse.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(gap.recommendedExercise.name).font(.system(size: 13, weight: .semibold))
                    Text("Add to \(gap.targetDayName)").font(.system(size: 10)).foregroundColor(Pulse.textTertiary)
                }
                Spacer()
                Button {
                    ProgramGapEngine.addToProgram(gap, context: modelContext)
                    addedGapIds.insert(gap.id + gap.targetDayCode)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } label: {
                    Text("Add").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Pulse.ai).clipShape(Capsule())
                }
            }
        }
        .padding(10)
        .background(Pulse.surfaceFallback)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func load() async {
        let allExercises = CustomSessionStore.allExercisesAcrossDays(context: modelContext)
        recommendations = SmartProgramEngine.generateRecommendations(
            context: modelContext,
            exercises: allExercises,
            appState: appState
        )
        if let profile = ProfileStore.current(context: modelContext) {
            gaps = ProgramGapEngine.analyze(context: modelContext, profile: profile)
        }
        isLoading = false
    }
}
