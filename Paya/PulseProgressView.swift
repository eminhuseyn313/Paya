import SwiftUI
import SwiftData
import Charts

// MARK: - Pulse Progress View
//
// Design personality: REFLECTIVE · MOTIVATING · JOURNEY
//
// This is the mirror. When you look here, you should feel a sense of
// accomplishment and direction — not drown in spreadsheets.
//
// Benchmark: Strava (year in review, celebrations), Oura (trend insights),
// fitness coaching products (visual progress journeys)
//
// Key transformation:
// 1. Hero: Journey summary — total sessions, streak, volume milestone
// 2. Section picker becomes visual tabs with accent icons
// 3. Collapsible groups get Pulse dark styling
// 4. Stats row becomes animated metric orbs
// 5. Dark canvas with positive/green ambient glow (achievement energy)
// 6. Each section leads with its most impressive metric

private enum PulseProgressSection: String, CaseIterable, Identifiable {
    case strength = "Strength"
    case body = "Body"
    case load = "Load"
    case consistency = "Consistency"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .strength: return "trophy.fill"
        case .body: return "figure.stand"
        case .load: return "chart.bar.fill"
        case .consistency: return "flame.fill"
        }
    }

    var color: Color {
        switch self {
        case .strength: return Pulse.nutrition
        case .body: return Pulse.ai
        case .load: return Pulse.energy
        case .consistency: return Pulse.positive
        }
    }
}

struct PulseProgressView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = ProgressViewModel()
    @State private var bodySignals: [WellnessCorrelationEngine.Insight] = []
    @State private var showBodyTracking = false
    @State private var section: PulseProgressSection = .strength
    @State private var hasAppeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                progressBackground

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        if viewModel.totalSessionCount == 0 {
                            // Empty state for brand-new users
                            PulseEmptyState(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Your journey starts here",
                                message: "Complete your first session to unlock strength tracking, personal records, and progress analytics.",
                                accentColor: Pulse.positive
                            )
                        } else {
                            // ━━━ Hero: Journey Stats ━━━
                            journeyHero

                            // ━━━ Section Picker ━━━
                            progressSectionPicker

                            // ━━━ Content ━━━
                            switch section {
                            case .strength:
                                strengthSection
                            case .body:
                                bodySection
                            case .load:
                                loadSection
                            case .consistency:
                                consistencySection
                            }
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Progress")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.textPrimary)
                }
            }
        }
        .onAppear {
            viewModel.loadAll(context: modelContext)
            Task { bodySignals = await WellnessCorrelationEngine.analyzeToday(context: modelContext) }
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) { hasAppeared = true }
        }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in
            viewModel.loadAll(context: modelContext)
            Task { bodySignals = await WellnessCorrelationEngine.analyzeToday(context: modelContext) }
        }
        .sheet(isPresented: $showBodyTracking) { BodyTrackingView() }
    }

    // MARK: - Background

    private var progressBackground: some View {
        ZStack {
            Pulse.canvasFallback.ignoresSafeArea()
            Circle()
                .fill(Pulse.positive.opacity(0.04))
                .frame(width: 350, height: 350)
                .blur(radius: 80)
                .offset(x: -60, y: -180)
            Circle()
                .fill(Pulse.nutrition.opacity(0.03))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: 140, y: 250)
        }
    }

    // MARK: - Journey Hero

    private var journeyHero: some View {
        VStack(spacing: 16) {
            // Main stats
            HStack(spacing: 0) {
                journeyStat(
                    value: "\(viewModel.totalSessionCount)",
                    label: "Sessions",
                    color: Pulse.energy
                )
                journeyStat(
                    value: "\(viewModel.currentStreak)w",
                    label: "Streak",
                    color: Pulse.positive
                )
                journeyStat(
                    value: totalVolumeFormatted,
                    label: "Total Volume",
                    color: Pulse.nutrition
                )
            }

            // Weight journey (if data exists)
            if viewModel.totalWeightChange != 0 {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.totalWeightChange > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Pulse.recovery)
                    Text(String(format: "%+.1f kg total", viewModel.totalWeightChange))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Pulse.textSecondary)
                    if viewModel.weeklyWeightChange != 0 {
                        Text("·")
                            .foregroundColor(Pulse.textTertiary)
                        Text(String(format: "%+.1f kg/week", viewModel.weeklyWeightChange))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Pulse.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Pulse.recovery.opacity(0.08))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .pulseSurface(padding: 20)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 15)
    }

    private func journeyStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var totalVolumeFormatted: String {
        let total = viewModel.allSessions.reduce(0.0) { sessionTotal, session in
            sessionTotal + session.exercises.reduce(0.0) { exTotal, ex in
                exTotal + ex.sets.reduce(0.0) { setTotal, set in
                    setTotal + set.weightKg * Double(set.reps)
                }
            }
        }
        if total >= 1_000_000 { return String(format: "%.1fM", total / 1_000_000) }
        if total >= 1000 { return String(format: "%.0fk", total / 1000) }
        return String(format: "%.0f", total)
    }

    // MARK: - Section Picker

    private var progressSectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PulseProgressSection.allCases) { s in
                    Button {
                        withAnimation(Pulse.Motion.standard) { section = s }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: s.icon)
                                .font(.system(size: 11, weight: .bold))
                            Text(s.rawValue)
                                .font(.system(size: 13, weight: section == s ? .bold : .medium))
                        }
                        .foregroundColor(section == s ? s.color : Pulse.textTertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(section == s ? s.color.opacity(0.12) : Pulse.surfaceFallback)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(section == s ? s.color.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Strength Section

    @ViewBuilder
    private var strengthSection: some View {
        TrophyCaseCard()
        StrengthStandardsCard(sessions: viewModel.allSessions)

        PulseCollapsible(title: "Personal records", icon: "trophy.fill", color: Pulse.nutrition) {
            PersonalBestTimelineCard()
            PRWallCard(sessions: viewModel.allSessions)
            PRTimelineCard(sessions: viewModel.allSessions)
            RecentPRsCard(sessions: viewModel.allSessions)
            VolumePRCard(sessions: viewModel.allSessions)
            VolumeLandmarkCard(sessions: viewModel.allSessions)
        }

        PulseCollapsible(title: "Strength analysis", icon: "chart.line.uptrend.xyaxis", color: Pulse.hydration) {
            StrengthRadarCard(sessions: viewModel.allSessions)
            StrengthToWeightCard(sessions: viewModel.allSessions)
            EstimatedOneRMCard(sessions: viewModel.allSessions)
            ExerciseSparklineCard(sessions: viewModel.allSessions)
            ProgressiveOverloadCard(sessions: viewModel.allSessions)
            ExerciseAlternativesCard(sessions: viewModel.allSessions)
            ExerciseProgressionCard(sessions: viewModel.allSessions)
        }

        PulseCollapsible(title: "Muscle & recovery", icon: "figure.strengthtraining.traditional", color: Pulse.positive) {
            WeeklyBodyMapCard(sessions: viewModel.allSessions)
            MuscleRecoveryInsightCard(sessions: viewModel.allSessions)
            if !PlateauEngine.detect(sessions: viewModel.allSessions).isEmpty {
                PlateauCard(sessions: viewModel.allSessions)
            }
        }
    }

    // MARK: - Body Section

    @ViewBuilder
    private var bodySection: some View {
        ProgressWeightChart(vm: viewModel)
        BodyCompositionCard()
        BodyRecompCard()
        VO2MaxCard()

        if !bodySignals.isEmpty {
            BodySignalsCard(insights: bodySignals)
        }

        Button { showBodyTracking = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Pulse.ai.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "ruler.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Pulse.ai)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Body Tracking")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Pulse.textPrimary)
                    Text("Measurements & progress photos")
                        .font(.system(size: 11))
                        .foregroundColor(Pulse.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Pulse.textTertiary)
            }
            .pulseSurfaceGlow(color: Pulse.ai, padding: 14)
        }
        .buttonStyle(PulsePress())
    }

    // MARK: - Load Section

    @ViewBuilder
    private var loadSection: some View {
        WorkoutIntensityScoreCard(sessions: viewModel.allSessions)
        ACWRCard()

        PulseCollapsible(title: "Volume & periodization", icon: "chart.bar.fill", color: Pulse.ai) {
            PeriodizationCard(sessions: viewModel.allSessions)
            WeeklyVolumeTrendCard(sessions: viewModel.allSessions)
            RepRangeAnalysisCard(sessions: viewModel.allSessions)
            WorkoutDensityCard(sessions: viewModel.allSessions)
            MuscleVolumeChart(sessions: viewModel.allSessions)
            WeeklyLoadCard(sessions: viewModel.allSessions)
        }

        PulseCollapsible(title: "Fatigue & recovery", icon: "battery.75percent", color: Pulse.warning) {
            FatigueIndexCard(sessions: viewModel.allSessions)
            MuscleFreshnessMap(sessions: viewModel.allSessions)
            MuscleBalanceCard(sessions: viewModel.allSessions)
            RestTimeAnalyticsCard(sessions: viewModel.allSessions)
        }

        PulseCollapsible(title: "Heart rate & biometrics", icon: "heart.fill", color: Pulse.vitals) {
            HRZoneDistributionCard(sessions: viewModel.allSessions)
            PersonalHRZoneCard()
            TrimpTimelineCard(sessions: viewModel.allSessions)
            HRRecoveryCard(sessions: viewModel.allSessions)
        }

        PulseCollapsible(title: "Session trends", icon: "clock.fill", color: Pulse.recovery) {
            RPETrendCard(sessions: viewModel.allSessions)
            MoodPerformanceCard()
            SessionDurationTrendCard(sessions: viewModel.allSessions)
            SessionBaselinesCard(sessions: viewModel.allSessions)
            FeltVsMeasuredCard(sessions: viewModel.allSessions)
        }
    }

    // MARK: - Consistency Section

    @ViewBuilder
    private var consistencySection: some View {
        WeeklySummaryShareCard()
        ConsistencyScoreCard(sessions: viewModel.allSessions, plannedPerWeek: 3)

        PulseCollapsible(title: "Training patterns", icon: "calendar", color: Pulse.hydration) {
            TrainingTimeAnalysisCard()
                .requiresPro()
            ExercisePreferenceCard()
                .requiresPro()
            TrainingSplitCard(sessions: viewModel.allSessions)
            TrainingFrequencyCard()
        }

        PulseCollapsible(title: "History & milestones", icon: "star.fill", color: Pulse.nutrition) {
            WorkoutMilestonesCard(sessions: viewModel.allSessions)
            TrainingHeatmapCard()
            WeeklyVolumeChart(vm: viewModel)
            TrainingCalendarV2()
        }

        PulseCollapsible(title: "Insights", icon: "lightbulb.fill", color: Pulse.positive) {
            SessionHistoryCardV2()
            CorrelationInsightsCard()
        }
    }
}
