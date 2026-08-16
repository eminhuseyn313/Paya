import SwiftUI
import SwiftData

// MARK: - Today Tab (v2 Redesign)
//
// Replaces DashboardView as the Home tab. Design principles from the
// Adaptive Depth redesign:
//
// 1. Score-first: Readiness ring is the hero (WHOOP/Oura benchmark)
// 2. Decision-first: "What should I do now?" not "Here is data"
// 3. Context-aware: Content changes based on time of day and session state
// 4. Three tiers: Glanceable → contextual → detailed (via sheets/pushes)
// 5. Minimal: 3–5 elements visible, no scroll needed on most devices
//
// Structural changes from DashboardView:
// - Removed: WeekSummary (moved to Trends tab)
// - Removed: InsightsHub link (Trends tab replaces it)
// - Removed: RecoveryBrief (absorbed into readiness detail sheet)
// - Added: Context-aware cards that swap by time of day
// - Kept: StatusHeader, VitalsStrip, TodayFocusCard, FlareAlertBanner

struct TodayView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = DashboardViewModel()
    @State private var showWeightEntry = false
    @State private var weightInput = ""
    @State private var showSettings = false
    @State private var showProfileSwitcher = false
    @State private var showNotifications = false
    @State private var showCheckIn = false
    @State private var showFlareRiskDetail = false
    @State private var showReadinessDetail = false
    @State private var todaysPicture: DayOverview? = nil
    @Query private var notificationRecords: [NotificationRecord]
    @Binding var selectedTab: Int
    @State private var lastLoadTime: Date = .distantPast

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            ScrollView {
                VStack(spacing: 16) {

                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    // 1. STATUS HEADER (reused from DashboardView)
                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                    StatusHeader(
                        appState: appState,
                        viewModel: viewModel,
                        unreadCount: unreadNotificationCount,
                        onProfile: { showProfileSwitcher = true },
                        onNotifications: { showNotifications = true },
                        onSettings: { showSettings = true },
                        onReadinessTap: { showReadinessDetail = true }
                    )

                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    // 2. TODAY'S FOCUS (training/rest recommendation)
                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                    // Morning check-in (ephemeral — disappears once done)
                    if appState.morningCheckInEnabled && !viewModel.hasCheckedInToday {
                        DashboardView.CheckInPromptCard(action: { showCheckIn = true })
                    }

                    TodayFocusCard(
                        appState: appState,
                        viewModel: viewModel,
                        selectedTab: $selectedTab
                    )

                    // Flare alert — only elevated/high, inline banner style
                    if appState.flareEngineEnabled,
                       let assessment = viewModel.flareAssessment,
                       assessment.level != .low {
                        Button { showFlareRiskDetail = true } label: {
                            FlareAlertBanner(assessment: assessment)
                        }
                        .buttonStyle(.plain)
                    }

                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    // 3. STATUS STRIP (vitals in compact row)
                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                    VitalsStrip(
                        viewModel: viewModel,
                        appState: appState,
                        selectedTab: $selectedTab,
                        onLogWeight: { showWeightEntry = true }
                    )

                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    // 4. CONTEXT CARDS (time-aware, 1–2 max)
                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                    contextCards

                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .frame(width: geo.size.width)
            }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showProfileSwitcher) { ProfileSwitcherView() }
            .sheet(isPresented: $showNotifications) {
                if let profileId = appState.currentProfileId {
                    NotificationCenterView(profileId: profileId) { record in
                        switch record.destination {
                        case .home: selectedTab = 0
                        case .train: selectedTab = 1
                        case .nutrition: selectedTab = 2
                        case .health: selectedTab = 2  // Now part of Log tab
                        case .progress: selectedTab = 3 // Now Trends tab
                        case .settings: showSettings = true
                        case .none: break
                        }
                        if record.category == .flareRisk {
                            selectedTab = 0
                            if viewModel.flareAssessment != nil { showFlareRiskDetail = true }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCheckIn) {
                DailyCheckInView(onDone: { loadData() })
            }
            .sheet(isPresented: $showFlareRiskDetail) {
                if let assessment = viewModel.flareAssessment {
                    FlareRiskDetailView(assessment: assessment)
                }
            }
            .sheet(isPresented: $showReadinessDetail) {
                if let readiness = viewModel.readiness {
                    ReadinessDetailView(report: readiness)
                } else if let score = viewModel.recoveryScore {
                    ReadinessDetailView(report: ReadinessEngine.Report(
                        score: score,
                        band: score >= 80 ? .primed : score >= 60 ? .steady : score >= 40 ? .caution : .recover,
                        drivers: [],
                        recommendation: "Limited biometric history — check back tomorrow for a baseline-relative score.",
                        journeyNotes: []
                    ))
                }
            }
            .sheet(isPresented: $showWeightEntry) {
                DashboardView.WeightEntrySheet(
                    weightInput: $weightInput,
                    onSave: {
                        if let kg = Double(weightInput) {
                            Task {
                                await viewModel.logWeight(kg, context: modelContext, appState: appState)
                                weightInput = ""
                                showWeightEntry = false
                            }
                        }
                    },
                    onCancel: {
                        weightInput = ""
                        showWeightEntry = false
                    }
                )
            }
        }
        .onAppear { loadData() }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in loadData() }
    }

    // MARK: - Context-Aware Cards

    @ViewBuilder
    private var contextCards: some View {
        let hour = Calendar.current.component(.hour, from: .now)

        // Morning context (5am–10am): sleep summary + readiness factors
        if hour >= 5 && hour < 10 {
            if let sleep = viewModel.appleHealthSleep {
                ContextCard(
                    icon: "moon.stars.fill",
                    iconColor: PayaColor.accent,
                    title: "Last night's sleep",
                    body_text: String(format: "%.1fh sleep", sleep)
                        + (sleep >= 7 ? " — solid recovery base." : " — below optimal. Consider lighter intensity today.")
                )
            }

            // Recovery notes (absorbed from RecoveryBrief)
            if let score = viewModel.recoveryScore, score < 60 {
                ContextCard(
                    icon: "heart.text.clipboard",
                    iconColor: PayaColor.warning,
                    title: "Recovery note",
                    body_text: "Readiness at \(score)/100. \(score < 40 ? "Consider a rest or light mobility day." : "Reduce volume ~20% from plan.")"
                )
            }
        }

        // Midday context (10am–2pm): training preview or nutrition prompt
        if hour >= 10 && hour < 14 {
            if appState.isTrainingDay && !appState.isSessionActive {
                ContextCard(
                    icon: "figure.strengthtraining.traditional",
                    iconColor: PayaColor.primary,
                    title: "Training today",
                    body_text: "Your planned session is ready. Warming up before lifting reduces injury risk and improves first-set performance.",
                    action: { selectedTab = 1 },
                    actionLabel: "Go to Train"
                )
            }

            let protein = viewModel.todaysNutrition?.totalProtein ?? 0
            let proteinTarget = viewModel.todaysNutrition?.proteinTarget ?? appState.profile.proteinTargetG
            if protein < proteinTarget * 0.3 {
                ContextCard(
                    icon: "fork.knife",
                    iconColor: PayaColor.primary,
                    title: "Front-load protein",
                    body_text: String(format: "%.0fg of %.0fg protein so far. Spreading intake across meals optimizes muscle protein synthesis.", protein, proteinTarget),
                    action: { selectedTab = 2 },
                    actionLabel: "Log food"
                )
            }
        }

        // Post-training context: session review (shown when session completed today)
        if let lastSession = viewModel.lastSession,
           Calendar.current.isDateInToday(lastSession.date),
           lastSession.isCompleted {
            let duration = Int(lastSession.durationMinutes)
            let exerciseCount = lastSession.exercises.count
            ContextCard(
                icon: "checkmark.circle.fill",
                iconColor: PayaColor.positive,
                title: "Session complete",
                body_text: "\(exerciseCount) exercises in \(duration) min. Check your trends to see how this session compares.",
                action: { selectedTab = 3 },
                actionLabel: "View trends"
            )
        }

        // Evening context (6pm+): day summary + sleep recommendation
        if hour >= 18 {
            let calories = viewModel.todaysNutrition?.totalCalories ?? 0
            let calorieTarget = viewModel.todaysNutrition?.calorieTarget ?? 2200
            let protein = viewModel.todaysNutrition?.totalProtein ?? 0
            let proteinTarget = viewModel.todaysNutrition?.proteinTarget ?? appState.profile.proteinTargetG

            if calories > 0 || protein > 0 {
                let calPct = calorieTarget > 0 ? Int(calories / calorieTarget * 100) : 0
                let protPct = proteinTarget > 0 ? Int(protein / proteinTarget * 100) : 0
                ContextCard(
                    icon: "moon.fill",
                    iconColor: PayaColor.accent,
                    title: "Evening wrap-up",
                    body_text: "Calories: \(calPct)% of target. Protein: \(protPct)% of target. \(protPct < 80 ? "A protein-rich snack before bed can help." : "Nutrition on track today.")"
                )
            }
        }
    }

    // MARK: - Helpers

    private var unreadNotificationCount: Int {
        guard let profileId = appState.currentProfileId else { return 0 }
        return notificationRecords.filter { $0.profileId == profileId && $0.readAt == nil }.count
    }

    private func loadData() {
        let now = Date()
        guard now.timeIntervalSince(lastLoadTime) > 15 else { return }
        lastLoadTime = now

        viewModel.load(context: modelContext)
        Task {
            todaysPicture = await PersonalHealthTimelineEngine.build(for: .now, context: modelContext)
            await viewModel.loadAppleHealthData(context: modelContext, profile: appState.profile)
            if appState.flareEngineEnabled,
               appState.profile.preFlareAlertsEnabled,
               let assessment = viewModel.flareAssessment {
                await NotificationManager.shared.schedulePreFlareAlert(
                    riskLevel: assessment.level,
                    recommendation: assessment.recommendation,
                    context: modelContext,
                    profile: appState.profile
                )
            }
            if let readiness = viewModel.readiness {
                NotificationManager.shared.scheduleRecoveryPrompt(
                    score: readiness.score,
                    bandLabel: readiness.band.rawValue,
                    context: modelContext,
                    profile: appState.profile
                )
            }
            if appState.isTrainingDay {
                let day = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
                NotificationManager.shared.recordInInbox(
                    category: .training,
                    title: "Training day",
                    body: "Your planned session is ready when you are.",
                    destination: .train,
                    deduplicationKey: "training_day_\(Int(day))",
                    context: modelContext
                )
            }
            await MilestoneEngine.checkDailyMilestones(context: modelContext, profile: appState.profile)
            AchievementEngine.evaluate(sessions: viewModel.allCompletedSessions, context: modelContext)
            LifestyleReminderScheduler.evaluate(profile: appState.profile, context: modelContext)
            await WeeklyDigestEngine.evaluateAndDeliver(userProfile: appState.profile, context: modelContext, apiKey: appState.anthropicAPIKey)
            await EnvironmentalReadingCapture.captureIfNeeded(context: modelContext)

            TrainingDayStore.seedIfNeeded(context: modelContext)
            let todayDay = TrainingDayStore.today(context: modelContext)
            let exerciseNames: [String]? = todayDay.flatMap { day in
                let sessionType = SessionType(rawValue: day.code) ?? .a
                let exercises = ProgramData.exercises(for: sessionType)
                return exercises.prefix(5).map(\.name)
            }
            WidgetSnapshotWriter.write(
                recoveryScore: viewModel.readiness?.score,
                recoveryBand: viewModel.readiness?.band.rawValue,
                trainingDayLabel: todayDay?.name,
                isTrainingDay: appState.isTrainingDay,
                waterMl: WaterStore.todayTotal(context: modelContext),
                waterTargetMl: WaterStore.dailyTargetMl,
                proteinG: viewModel.todaysNutrition?.totalProtein ?? 0,
                proteinTargetG: viewModel.todaysNutrition?.proteinTarget ?? 0,
                calories: viewModel.todaysNutrition?.totalCalories ?? 0,
                calorieTarget: viewModel.todaysNutrition?.calorieTarget ?? 0,
                nextExercises: exerciseNames
            )
        }
    }
}
