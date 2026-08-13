import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    
    @State private var viewModel = DashboardViewModel()
    @State private var showWeightEntry = false
    @State private var weightInput = ""
    @State private var showSettings = false
    @State private var showLibrary = false
    @State private var showProfileSwitcher = false
    @State private var showNotifications = false
    @State private var showCheckIn = false
    @State private var showPersonalHealth = false
    @State private var showFlareRiskDetail = false
    @State private var showReadinessDetail = false
    @State private var todaysPicture: DayOverview? = nil
    @State private var showMore = false
    @Query private var notificationRecords: [NotificationRecord]
    @Binding var selectedTab: Int
    @State private var lastLoadTime: Date = .distantPast
    
    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            ScrollView {
                VStack(spacing: 14) {

                    // Greeting with profile + settings buttons
                    HStack {
                        GreetingHeader(appState: appState)
                        
                        Button {
                            showProfileSwitcher = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "2563EB").opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Text(String(appState.profile.name.prefix(1)).uppercased())
                                    .font(.subheadline.bold())
                                    .foregroundColor(Color(hex: "2563EB"))
                            }
                        }

                        if let profileId = appState.currentProfileId {
                            NotificationBellButton(
                                unreadCount: notificationRecords.filter { $0.profileId == profileId && $0.readAt == nil }.count,
                                action: { showNotifications = true }
                            )
                        }
                        
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .frame(width: 40, height: 40)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Settings")
                    }

                    // ═══════════════════════════════════
                    // SECTION 1: TODAY'S ESSENTIALS
                    // What you need to do right now.
                    // Follows Whoop/Oura: action-first.
                    // ═══════════════════════════════════

                    // Morning check-in prompt (ephemeral — disappears once done)
                    if appState.morningCheckInEnabled && !viewModel.hasCheckedInToday {
                        CheckInPromptCard(action: { showCheckIn = true })
                    }

                    // Daily action card — "what to do today"
                    DailyActionCard()

                    // Today's training day + readiness
                    TodayTrainingDayCard(selectedTab: $selectedTab)

                    if appState.isTrainingDay {
                        ReadyToTrainCard(
                            readinessScore: viewModel.recoveryScore,
                            freshMuscles: viewModel.freshMuscles,
                            sorenessLevel: nil
                        )
                        DynamicWarmUpCard()
                    }

                    // Rest day recovery suggestions
                    if !appState.isTrainingDay {
                        RestDayCard(
                            readinessScore: viewModel.recoveryScore,
                            lastSessionDaysAgo: viewModel.lastSessionDaysAgo
                        )
                    }

                    // Post-workout nutrition (only shows on training days with a session)
                    if let lastSession = viewModel.lastSession,
                       Calendar.current.isDateInToday(lastSession.date) {
                        PostWorkoutNutritionCard(session: lastSession)
                    }

                    // Volume trend alert
                    VolumeAlertCard()

                    // Offline AI coach — daily suggestion
                    OfflineCoachCard()

                    // ═══════════════════════════════════
                    // SECTION 2: FUEL & BODY
                    // Nutrition, hydration, weight at a glance.
                    // ═══════════════════════════════════

                    HStack(spacing: 12) {
                        NutritionMiniCard(vm: viewModel, selectedTab: $selectedTab)
                        WeightMiniCard(
                            vm: viewModel,
                            appState: appState,
                            onLog: { showWeightEntry = true }
                        )
                    }

                    // Quick hydration — always accessible
                    QuickHydrationCard(modelContext: modelContext)

                    // Supplement timing
                    SupplementTimingCard()

                    // ═══════════════════════════════════
                    // SECTION 3: RECOVERY & HEALTH
                    // How your body is doing.
                    // ═══════════════════════════════════

                    // Flare risk (conditional)
                    if appState.flareEngineEnabled,
                       let assessment = viewModel.flareAssessment {
                        Button {
                            showFlareRiskDetail = true
                        } label: {
                            FlareRiskCardCompact(assessment: assessment)
                        }
                        .buttonStyle(.plain)
                    }

                    if viewModel.recoveryScore != nil {
                        Button {
                            showReadinessDetail = true
                        } label: {
                            RecoveryCard(vm: viewModel)
                        }
                        .buttonStyle(.plain)
                    }

                    // Sleep debt tracker
                    SleepDebtCard()

                    // Behavior ↔ Recovery insights
                    BehaviorRecoveryCard()

                    // ═══════════════════════════════════
                    // SECTION 4: WEEKLY OVERVIEW
                    // Stats, plan, consistency.
                    // ═══════════════════════════════════

                    WeeklyStatsCard(
                        thisWeekSessions: viewModel.thisWeekSessions,
                        plannedSessions: viewModel.thisWeekPossibleSessions,
                        weekStreak: viewModel.weekStreak,
                        thisWeekVolume: viewModel.thisWeekVolume
                    )

                    TrainingConsistencyBanner()

                    WeeklyPlanCard()

                    // Last session summary
                    if let lastSession = viewModel.lastSession {
                        LastSessionCard(session: lastSession)
                    }

                    // Momentum streaks
                    MomentumCard()

                    // Milestone celebrations
                    MilestoneCelebrationCard()

                    // ═══════════════════════════════════
                    // SECTION 5: DEEP INSIGHTS
                    // Analytics, trends, correlations —
                    // collapsible for cleaner default view.
                    // ═══════════════════════════════════

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showMore.toggle() }
                    } label: {
                        HStack {
                            Text(showMore ? "Hide insights" : "Insights & analytics")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Image(systemName: showMore ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if showMore {
                        // Nutrient timing analysis
                        NutrientTimingCard()

                        ReadinessTrendCard()

                        OptimalTrainingWindowCard()

                        if let lastSession = viewModel.lastSession {
                            SessionScoreCard(session: lastSession)
                        }

                        SmartProgramCard()

                        PostWorkoutWindowCard()

                        PerformanceNutritionCard()

                        if !viewModel.allCompletedSessions.isEmpty {
                            MuscleRecoveryStatusCard(sessions: viewModel.allCompletedSessions)
                            TrainingInsightsCard(sessions: viewModel.allCompletedSessions)
                        }

                        WeeklyEffortCard()

                        WeeklyReportCard()

                        WeeklyInsightCard(
                            vm: viewModel,
                            context: modelContext,
                            apiKey: appState.anthropicAPIKey,
                            profile: appState.profile
                        )
                        .requiresPro()

                        // Circadian profile
                        CircadianCard()

                        // Biological age estimate
                        BiologicalAgeCard()

                        // GLP-1 companion
                        GLP1CompanionCard()

                        // Body recomposition
                        BodyRecompCard()

                        // Personal health narrative
                        PersonalHealthNarrativeCard()
                            .requiresPro()

                        DailyRoutineCard()
                            .requiresPro()

                        TodaysPictureCard(overview: todaysPicture, onOpen: { showPersonalHealth = true })
                            .buttonStyle(.plain)

                        LibraryCard(showLibrary: $showLibrary)

                        PrivacyBadgeCard()
                    }

                    Spacer().frame(height: 30)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .frame(width: geo.size.width)
            }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showProfileSwitcher) {
                ProfileSwitcherView()
            }
            .sheet(isPresented: $showNotifications) {
                if let profileId = appState.currentProfileId {
                    NotificationCenterView(profileId: profileId) { record in
                        switch record.destination {
                        case .home: selectedTab = 0
                        case .train: selectedTab = 1
                        case .nutrition: selectedTab = 2
                        case .health: selectedTab = 3
                        case .progress: selectedTab = 4
                        case .settings: showSettings = true
                        case .none: break
                        }
                        // Tapping a flare-risk notification used to just
                        // switch tabs with no way to see WHY it fired —
                        // land on the actual explanation instead.
                        if record.category == .flareRisk {
                            selectedTab = 0
                            if viewModel.flareAssessment != nil {
                                showFlareRiskDetail = true
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showLibrary) {
                ExerciseLibraryView()
            }
            .sheet(isPresented: $showCheckIn) {
                DailyCheckInView(onDone: { loadData() })
            }
            .sheet(isPresented: $showPersonalHealth) {
                PersonalHealthView()
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
                WeightEntrySheet(
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
        .onAppear {
            loadData()
        }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in
            loadData()
        }
    }
    
    private func loadData() {
        // Debounce: skip if last refresh was <15s ago (tab switches fire
        // dataRefreshTrigger on every change, causing 15+ async tasks each time)
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
    
    // MARK: - Greeting
    
    struct GreetingHeader: View {
        @Bindable var appState: AppState
        
        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.greeting + ",")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text(appState.profile.name)
                        .font(.system(size: 30, weight: .bold))
                }
                Spacer()
                
                if appState.isFlareDay {
                    VStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundColor(Color(hex: "B45309"))
                        Text("Flare day")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(Color(hex: "B45309"))
                    }
                    .padding(10)
                    .background(Color(hex: "B45309").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Flare day is active")
                }
            }
        }
    }
    
    
    // MARK: - Recovery Card
    
    struct RecoveryCard: View {
        var vm: DashboardViewModel
        
        var scoreColor: Color {
            guard let score = vm.recoveryScore else { return .secondary }
            switch score {
            case 80...100: return Color(hex: "059669")
            case 60..<80:  return Color(hex: "4D7C0F")
            case 40..<60:  return Color(hex: "B45309")
            default:       return Color(hex: "DC2626")
            }
        }

        var recoveryAccessibilityLabel: String {
            let title = vm.readiness != nil ? "Readiness" : "Recovery"
            var text = "\(title) score \(vm.recoveryScore ?? 0) of 100"
            if let band = vm.readiness?.band.rawValue {
                text += ", \(band)"
            }
            return text
        }

        var body: some View {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(scoreColor.opacity(0.15), lineWidth: 8)
                        .frame(width: 74, height: 74)
                    Circle()
                        .trim(from: 0, to: Double(vm.recoveryScore ?? 0) / 100.0)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 74, height: 74)
                        .rotationEffect(.degrees(-90))
                        .animation(PayaAnimation.dataChange, value: vm.recoveryScore)
                    VStack(spacing: 0) {
                        HeroNumberText(value: "\(vm.recoveryScore ?? 0)", size: 24, color: scoreColor)
                        Text("/100")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(recoveryAccessibilityLabel)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(vm.readiness != nil ? "Readiness" : "Recovery")
                            .font(.subheadline.weight(.semibold))
                        if let band = vm.readiness?.band {
                            Text(band.rawValue)
                                .font(.caption2.weight(.bold))
                                .foregroundColor(Color(hex: band.colorHex))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color(hex: band.colorHex).opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text(vm.readiness?.recommendation ?? "Based on sleep, HR, HRV")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let note = vm.readiness?.journeyNotes.first {
                        Text(note)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 1)
                    }

                    HStack(spacing: 8) {
                        if let sleep = vm.appleHealthSleep {
                            MiniMetric(icon: "moon.fill", value: String(format: "%.1fh", sleep), color: Color(hex: "8B5CF6"))
                        }
                        if let hr = vm.appleHealthHR {
                            MiniMetric(icon: "heart.fill", value: "\(hr)", color: Color(hex: "DC2626"))
                        }
                        if let hrv = vm.appleHealthHRV {
                            MiniMetric(icon: "waveform.path.ecg", value: String(format: "%.0f", hrv), color: Color(hex: "2563EB"))
                        }
                        if let steps = vm.appleHealthSteps {
                            MiniMetric(
                                icon: "figure.walk",
                                value: steps >= 1000 ? String(format: "%.1fk", Double(steps) / 1000) : "\(steps)",
                                color: Color(hex: "059669")
                            )
                        }
                    }
                    .padding(.top, 4)
                }
                Spacer()
            }
            .payaCard()
        }
    }

    struct CheckInPromptCard: View {
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 12) {
                    Text(greetingEmoji)
                        .font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Morning check-in")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text("Rate body, energy & sleep — adjusts today's training loads")
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
        }

        private var greetingEmoji: String {
            let hour = Calendar.current.component(.hour, from: .now)
            if hour < 12 { return "☀️" }
            if hour < 17 { return "👋" }
            return "🌙"
        }
    }

    struct MiniMetric: View {
        var icon: String
        var value: String
        var color: Color
        
        var body: some View {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 10, weight: .semibold))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Flare Risk Card (Compact)
    
    struct FlareRiskCardCompact: View {
        var assessment: FlareRiskAssessment

        var body: some View {
            // Low risk is the everyday state — a full card for it just adds
            // noise; only elevated/high risk deserves prominent real estate.
            if assessment.level == .low {
                HStack(spacing: 6) {
                    Image(systemName: assessment.level.icon)
                        .font(.caption2)
                        .foregroundColor(assessment.level.color)
                    Text("Flare risk low")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 4)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: assessment.level.icon)
                        .font(.caption)
                        .foregroundColor(assessment.level.color)
                    Text("Flare risk \(assessment.level.displayName.lowercased())")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(assessment.level.color)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(assessment.recommendation)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(assessment.level.color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
    
    // MARK: - Nutrition Mini
    
    struct NutritionMiniCard: View {
        var vm: DashboardViewModel
        @Binding var selectedTab: Int
        
        var body: some View {
            Button {
                selectedTab = 2
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "fork.knife")
                            .foregroundColor(Color(hex: "2563EB"))
                        Text("Protein")
                            .font(.caption.weight(.semibold))
                    }
                    ZStack {
                        Circle()
                            .stroke(Color(hex: "2563EB").opacity(0.15), lineWidth: 8)
                            .frame(width: 80, height: 80)
                        Circle()
                            .trim(from: 0, to: vm.proteinProgress)
                            .stroke(Color(hex: "2563EB"), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(PayaAnimation.dataChange, value: vm.proteinProgress)
                        VStack(spacing: 0) {
                            HeroNumberText(value: "\(Int(vm.todaysNutrition?.totalProtein ?? 0))", size: 22, color: Color(hex: "2563EB"))
                            Text("g")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text("/ \(Int(vm.todaysNutrition?.proteinTarget ?? 170))g goal")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .payaCard(padding: 14)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Protein, \(Int(vm.todaysNutrition?.totalProtein ?? 0)) of \(Int(vm.todaysNutrition?.proteinTarget ?? 170)) grams")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens Nutrition")
        }
    }

    // MARK: - Weight Mini
    
    struct WeightMiniCard: View {
        var vm: DashboardViewModel
        var appState: AppState
        var onLog: () -> Void
        
        var goalDelta: Double? {
            guard let latest = vm.latestWeight else { return nil }
            return latest - appState.profile.bodyWeightGoalKg
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "scalemass.fill")
                        .foregroundColor(Color(hex: "059669"))
                    Text("Weight")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    if vm.latestWeightSource != .none {
                        Text(vm.latestWeightSource.displayLabel)
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Capsule())
                    }
                }
                HeroNumberText(value: vm.latestWeight.map { String(format: "%.1f", $0) } ?? "—", size: 30)
                Text("kg")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let delta = goalDelta {
                    HStack(spacing: 3) {
                        Image(systemName: delta > 0 ? "arrow.down" : "arrow.up")
                            .font(.system(size: 9, weight: .bold))
                        Text(String(format: "%.1f kg to goal", abs(delta)))
                            .font(.caption2)
                    }
                    .foregroundColor(delta > 0 ? Color(hex: "059669") : Color(hex: "B45309"))
                }
                
                Button(action: onLog) {
                    Label("Log weight", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Color(hex: "059669"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color(hex: "059669").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .payaCard(padding: 14)
        }
    }
    
    // MARK: - Weekly Insight
    
    struct WeeklyInsightCard: View {
        var vm: DashboardViewModel
        var context: ModelContext
        var apiKey: String
        var profile: UserProfile
        
        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: AIService.shared.providerIcon)
                        .foregroundColor(Color(hex: "8B5CF6"))
                    Text("Weekly Insight")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(AIService.shared.providerName)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                }
                
                if let insight = vm.weeklyInsight {
                    Text(insight)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                } else if !vm.isFetchingInsight, let lastError = AIService.shared.lastError {
                    Text(lastError)
                        .font(.caption)
                        .foregroundColor(Color(hex: "DC2626"))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("AI analysis of your week so far.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button {
                    Task {
                        await vm.fetchWeeklyInsight(context: context, apiKey: apiKey, profile: profile)
                    }
                } label: {
                    HStack {
                        if vm.isFetchingInsight {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                            Text(vm.weeklyInsight == nil ? "Get insight" : "New insight")
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(hex: "8B5CF6"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(vm.isFetchingInsight)
            }
            .payaCard(padding: 14)
        }
    }
    
    // MARK: - Library Card
    
    struct LibraryCard: View {
        @Binding var showLibrary: Bool
        
        var body: some View {
            Button {
                showLibrary = true
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "2563EB").opacity(0.15))
                            .frame(width: 50, height: 50)
                        Image(systemName: "books.vertical.fill")
                            .font(.title2)
                            .foregroundColor(Color(hex: "2563EB"))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Exercise Library")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text("800+ exercises with images and instructions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .payaCard(padding: 14)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Weight Entry Sheet
    
    struct WeightEntrySheet: View {
        @Binding var weightInput: String
        var onSave: () -> Void
        var onCancel: () -> Void
        
        var body: some View {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Log body weight")
                        .font(.headline)
                        .padding(.top, 20)
                    
                    HStack {
                        TextField("Weight", text: $weightInput)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 44, weight: .bold))
                            .padding()
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text("kg")
                            .font(.title.bold())
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 40)
                    
                    Button(action: onSave) {
                        Text("Save")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(weightInput.isEmpty
                                        ? Color.secondary.opacity(0.5)
                                        : Color(hex: "059669"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)
                    .disabled(weightInput.isEmpty)
                    
                    Spacer()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel", action: onCancel)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}
