import SwiftUI
import SwiftData
import Charts

// MARK: - Trends Tab (v2 Redesign)
//
// Merges Progress tab + InsightsHub into a single retrospective analytics tab.
// Five pill sections: Training · Body · Nutrition · Health · AI
//
// Design principles:
// 1. All retrospective analysis in one place
// 2. Each section opens with a summary row (3–4 hero stats)
// 3. Collapsible groups within each section for depth
// 4. Shared time-range picker across all sections (future)
// 5. Direct tab-bar access (no more navigating Dashboard → InsightsHub)
//
// What moved here:
// - From ProgressView: All strength/body/load/consistency sections
// - From InsightsHubView: Training/Nutrition/Recovery/AI analytics cards
// - From NutritionView (insights): NutritionStreakCard, NutritionTrendCard, etc.
// - From HealthView (insights): AppleHealthCard, SleepStagesCard, etc.

enum TrendsSection: String, CaseIterable, Identifiable {
    case training = "Training"
    case body = "Body"
    case nutrition = "Nutrition"
    case health = "Health"
    case ai = "AI"
    var id: String { rawValue }
}

struct TrendsView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    // Progress data
    @State private var progressVM = ProgressViewModel()
    @State private var bodySignals: [WellnessCorrelationEngine.Insight] = []

    // Insights data
    @State private var dashboardVM = DashboardViewModel()
    @State private var todaysPicture: DayOverview? = nil

    // Nutrition data
    @State private var nutritionVM = NutritionViewModel()
    @State private var lifestyleProfile: PersonProfile? = nil
    @State private var showLifestylePlan = false

    // Health data
    @State private var healthVM = HealthViewModel()

    // Navigation
    @State private var section: TrendsSection = .training
    @State private var showBodyTracking = false
    @State private var showPersonalHealth = false
    @State private var showLibrary = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {

                    // Pill picker instead of segmented control
                    PillPicker(selection: $section)
                        .padding(.bottom, 4)

                    switch section {
                    case .training:
                        trainingSection
                    case .body:
                        bodySection
                    case .nutrition:
                        nutritionSection
                    case .health:
                        healthSection
                    case .ai:
                        aiSection
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { loadAll() }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in loadAll() }
        .sheet(isPresented: $showBodyTracking) { BodyTrackingView() }
        .sheet(isPresented: $showPersonalHealth) { PersonalHealthView() }
        .sheet(isPresented: $showLibrary) { ExerciseLibraryView() }
        .sheet(isPresented: $showLifestylePlan) {
            if let profile = lifestyleProfile {
                LifestylePlanView(profile: profile)
            }
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // TRAINING SECTION
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @ViewBuilder
    private var trainingSection: some View {
        // Summary row
        HStack(spacing: 10) {
            SummaryStatCell(
                value: "\(progressVM.totalSessionCount)",
                label: "Total Sessions",
                icon: "dumbbell.fill",
                color: PayaColor.primary
            )
            SummaryStatCell(
                value: "\(progressVM.currentStreak)",
                label: "Week Streak",
                icon: "flame.fill",
                color: PayaColor.critical
            )
            SummaryStatCell(
                value: progressVM.weightLogs.isEmpty
                    ? "--"
                    : String(format: "%.1f", useLbs ? progressVM.totalWeightChange * 2.20462 : progressVM.totalWeightChange),
                label: useLbs ? "lbs Change" : "kg Change",
                icon: "arrow.up.arrow.down",
                color: progressVM.totalWeightChange <= 0 ? PayaColor.positive : PayaColor.warning
            )
        }

        // Week summary (moved from Dashboard)
        WeekSummary(viewModel: dashboardVM, appState: appState)

        // Strength analysis
        TrophyCaseCard()
        StrengthStandardsCard(sessions: progressVM.allSessions)

        // Personal records
        ProgressCollapsible(
            title: "Personal records",
            icon: "trophy.fill",
            color: "D97706"
        ) {
            PersonalBestTimelineCard()
            PRWallCard(sessions: progressVM.allSessions)
            PRTimelineCard(sessions: progressVM.allSessions)
            RecentPRsCard(sessions: progressVM.allSessions)
            VolumePRCard(sessions: progressVM.allSessions)
            VolumeLandmarkCard(sessions: progressVM.allSessions)
        }

        // Strength analysis
        ProgressCollapsible(
            title: "Strength analysis",
            icon: "chart.line.uptrend.xyaxis",
            color: "2563EB"
        ) {
            StrengthRadarCard(sessions: progressVM.allSessions)
            StrengthToWeightCard(sessions: progressVM.allSessions)
            EstimatedOneRMCard(sessions: progressVM.allSessions)
            ExerciseSparklineCard(sessions: progressVM.allSessions)
            ProgressiveOverloadCard(sessions: progressVM.allSessions)
            ExerciseAlternativesCard(sessions: progressVM.allSessions)
            ExerciseProgressionCard(sessions: progressVM.allSessions)
        }

        // Muscle & recovery
        ProgressCollapsible(
            title: "Muscle & recovery",
            icon: "figure.strengthtraining.traditional",
            color: "059669"
        ) {
            WeeklyBodyMapCard(sessions: progressVM.allSessions)
            MuscleRecoveryInsightCard(sessions: progressVM.allSessions)
            if !PlateauEngine.detect(sessions: progressVM.allSessions).isEmpty {
                PlateauCard(sessions: progressVM.allSessions)
            }
            if let lastSession = dashboardVM.lastSession {
                SessionScoreCard(session: lastSession)
            }
            if !dashboardVM.allCompletedSessions.isEmpty {
                MuscleRecoveryStatusCard(sessions: dashboardVM.allCompletedSessions)
                TrainingInsightsCard(sessions: dashboardVM.allCompletedSessions)
            }
        }

        // Load management
        ProgressCollapsible(
            title: "Load management",
            icon: "chart.bar.fill",
            color: "8B5CF6"
        ) {
            WorkoutIntensityScoreCard(sessions: progressVM.allSessions)
            ACWRCard()
            PeriodizationCard(sessions: progressVM.allSessions)
            WeeklyVolumeTrendCard(sessions: progressVM.allSessions)
            RepRangeAnalysisCard(sessions: progressVM.allSessions)
            WorkoutDensityCard(sessions: progressVM.allSessions)
            MuscleVolumeChart(sessions: progressVM.allSessions)
            WeeklyLoadCard(sessions: progressVM.allSessions)
            FatigueIndexCard(sessions: progressVM.allSessions)
            MuscleBalanceCard(sessions: progressVM.allSessions)
            RestTimeAnalyticsCard(sessions: progressVM.allSessions)
        }

        // Session trends
        ProgressCollapsible(
            title: "Session trends",
            icon: "clock.fill",
            color: "2563EB"
        ) {
            RPETrendCard(sessions: progressVM.allSessions)
            SessionDurationTrendCard(sessions: progressVM.allSessions)
            HRZoneDistributionCard(sessions: progressVM.allSessions)
            PersonalHRZoneCard()
        }

        // Consistency
        ProgressCollapsible(
            title: "Consistency",
            icon: "calendar",
            color: "059669"
        ) {
            ConsistencyScoreCard(sessions: progressVM.allSessions, plannedPerWeek: 3)
            TrainingHeatmapCard()
            TrainingFrequencyCard()
            WorkoutMilestonesCard(sessions: progressVM.allSessions)
            WeeklyVolumeChart(vm: progressVM)
        }

        // Insights from dashboard
        ProgressCollapsible(
            title: "Training insights",
            icon: "lightbulb.fill",
            color: "D97706"
        ) {
            SmartProgramCard()
            OptimalTrainingWindowCard()
            WeeklyEffortCard()
            SessionHistoryCardV2()
            CorrelationInsightsCard()
        }

        // Exercise library link
        InsightsHubView.LibraryCard(showLibrary: $showLibrary)
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // BODY SECTION
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @ViewBuilder
    private var bodySection: some View {
        ProgressWeightChart(vm: progressVM)
        BodyCompositionCard()
        BodyRecompCard()

        Button { showBodyTracking = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(PayaColor.accent.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "ruler.fill")
                        .foregroundColor(PayaColor.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Body Tracking")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text("Measurements & progress photos")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .payaCard(padding: 14)
        }
        .buttonStyle(.plain)

        if !bodySignals.isEmpty {
            BodySignalsCard(insights: bodySignals)
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // NUTRITION SECTION
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @ViewBuilder
    private var nutritionSection: some View {
        // Calorie deficit tracking
        CalorieDeficitCard()

        // Nutrition trends
        NutritionStreakCard()
        NutritionTrendCard()

        // Nutrient timing insights (from InsightsHub)
        NutrientTimingCard()
        PostWorkoutWindowCard()
        PerformanceNutritionCard()

        // AI nutrition (Pro)
        if let profile = lifestyleProfile {
            LifestylePlanCard(profile: profile, onOpen: { showLifestylePlan = true })
                .requiresPro()
        }
        MealSuggestionCard(
            vm: nutritionVM,
            dietPreference: lifestyleProfile?.dietPreference ?? .omnivore,
            modelContext: modelContext
        )
        AISuggestionCard(
            vm: nutritionVM,
            apiKey: appState.anthropicAPIKey,
            profile: appState.profile
        )
        .requiresPro()
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // HEALTH SECTION
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @ViewBuilder
    private var healthSection: some View {
        // Apple Health integration
        AppleHealthCard(vm: healthVM)

        // Sleep analytics
        SleepStagesCard()

        // Readiness trend
        ReadinessTrendCard()

        // Mindfulness
        MindfulMinutesCard()

        // Health goals
        WeeklyHealthGoalsCard(modelContext: modelContext)

        // Advanced health metrics (opt-in)
        ProgressCollapsible(
            title: "Advanced metrics",
            icon: "waveform.path.ecg",
            color: "8B5CF6"
        ) {
            CircadianCard()
            BiologicalAgeCard()
            VO2MaxCard()
            GLP1CompanionCard()
        }

        // Flare & correlations
        ProgressCollapsible(
            title: "Flare & correlations",
            icon: "exclamationmark.shield.fill",
            color: "D97706"
        ) {
            FlareRiskFactorsCard()
            SorenessCorrelationCard()
                .requiresPro()
            SupplementAdviceCard(
                vm: healthVM,
                apiKey: appState.anthropicAPIKey,
                condition: ProfileStore.current(context: modelContext)?.chronicCondition ?? .rheumatoidArthritis
            )
            .requiresPro()
        }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // AI SECTION
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    @ViewBuilder
    private var aiSection: some View {
        // Weekly report
        WeeklyReportCard()

        // AI weekly insight
        InsightsHubView.WeeklyInsightCard(
            vm: dashboardVM,
            context: modelContext,
            apiKey: appState.anthropicAPIKey,
            profile: appState.profile
        )
        .requiresPro()

        // Personal health narrative
        PersonalHealthNarrativeCard()
            .requiresPro()

        // Daily routine
        DailyRoutineCard()
            .requiresPro()

        // Today's picture
        TodaysPictureCard(overview: todaysPicture, onOpen: { showPersonalHealth = true })
            .buttonStyle(.plain)

        // Privacy
        PrivacyBadgeCard()
    }

    // MARK: - Helpers

    private var useLbs: Bool { appState.profile.prefersLbs }

    private func loadAll() {
        progressVM.loadAll(context: modelContext)
        Task { bodySignals = await WellnessCorrelationEngine.analyzeToday(context: modelContext) }

        dashboardVM.load(context: modelContext)
        Task {
            todaysPicture = await PersonalHealthTimelineEngine.build(for: .now, context: modelContext)
            await dashboardVM.loadAppleHealthData(context: modelContext, profile: appState.profile)
        }

        nutritionVM.appStateRef = appState
        nutritionVM.load(context: modelContext, profile: appState.profile)
        lifestyleProfile = ProfileStore.current(context: modelContext)

        healthVM.load(context: modelContext)
        Task { await healthVM.loadHealthKitData() }
    }
}
