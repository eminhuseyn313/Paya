import SwiftUI
import SwiftData
import Charts

// MARK: - Dashboard (Redesigned)
//
// Previous: 26 cards + 18 collapsible = 44 elements on one screen.
// Now: 6 focused sections with progressive disclosure.
//
// Design principles:
// 1. Decision-first — show what to DO, not what data EXISTS
// 2. Progressive disclosure — summary here, detail on tap
// 3. Contextual density — training days show different content than rest days
// 4. Whoop/Oura benchmark — status header with readiness ring, biometric chips
//
// Architecture:
// ┌─────────────────────────────────┐
// │  Status Header                  │  Readiness ring + biometric chips
// ├─────────────────────────────────┤
// │  Today's Focus                  │  One CTA: train/rest/check-in
// ├─────────────────────────────────┤
// │  Vitals Strip                   │  Protein · Calories · Water · Weight
// ├─────────────────────────────────┤
// │  Recovery Brief (conditional)   │  Only when noteworthy
// ├─────────────────────────────────┤
// │  Week Summary                   │  Compact stats + last session
// ├─────────────────────────────────┤
// │  Explore → InsightsHub          │  18 analytics cards live here now
// └─────────────────────────────────┘

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
    @Query private var notificationRecords: [NotificationRecord]
    @Binding var selectedTab: Int
    @State private var lastLoadTime: Date = .distantPast

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            ScrollView {
                VStack(spacing: 16) {

                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    // 1. STATUS HEADER
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
                    // 2. TODAY'S FOCUS
                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                    // Morning check-in (ephemeral — disappears once done)
                    if appState.morningCheckInEnabled && !viewModel.hasCheckedInToday {
                        CheckInPromptCard(action: { showCheckIn = true })
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
                    // 3. VITALS STRIP
                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                    VitalsStrip(
                        viewModel: viewModel,
                        appState: appState,
                        selectedTab: $selectedTab,
                        onLogWeight: { showWeightEntry = true }
                    )

                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    // 4. RECOVERY BRIEF (conditional)
                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                    RecoveryBrief(
                        viewModel: viewModel,
                        onReadinessTap: { showReadinessDetail = true }
                    )

                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    // 5. WEEK SUMMARY
                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                    WeekSummary(
                        viewModel: viewModel,
                        appState: appState
                    )

                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                    // 6. EXPLORE → INSIGHTS HUB
                    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

                    NavigationLink {
                        InsightsHubView()
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: "8B5CF6").opacity(0.1))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "chart.bar.xaxis.ascending")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(hex: "8B5CF6"))
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Insights & analytics")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("Training, nutrition, recovery deep-dives")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: PayaRadius.card))
                    }
                    .buttonStyle(.plain)

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
                        case .health: selectedTab = 3
                        case .progress: selectedTab = 4
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
            .sheet(isPresented: $showLibrary) { ExerciseLibraryView() }
            .sheet(isPresented: $showCheckIn) {
                DailyCheckInView(onDone: { loadData() })
            }
            .sheet(isPresented: $showPersonalHealth) { PersonalHealthView() }
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
        .onAppear { loadData() }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in loadData() }
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

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 1. STATUS HEADER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
// Greeting + readiness ring + biometric chips + toolbar buttons.
// Replaces: GreetingHeader + RecoveryCard (from old dashboard).
// Benchmark: Whoop's top-of-screen recovery ring, Oura's readiness score.

struct StatusHeader: View {

    @Bindable var appState: AppState
    var viewModel: DashboardViewModel
    var unreadCount: Int
    var onProfile: () -> Void
    var onNotifications: () -> Void
    var onSettings: () -> Void
    var onReadinessTap: () -> Void

    private var scoreColor: Color {
        guard let score = viewModel.recoveryScore else { return .secondary }
        switch score {
        case 80...100: return Color(hex: "059669")
        case 60..<80:  return Color(hex: "4D7C0F")
        case 40..<60:  return Color(hex: "B45309")
        default:       return Color(hex: "DC2626")
        }
    }

    var body: some View {
        VStack(spacing: 12) {

            // Top row: greeting + buttons
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.greeting + ",")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text(appState.profile.name)
                        .font(.system(size: 22, weight: .bold))
                }
                Spacer()

                if appState.isFlareDay {
                    flareDayBadge
                }

                profileButton
                notificationButton
                settingsButton
            }

            // Readiness + biometrics row
            if viewModel.recoveryScore != nil {
                Button(action: onReadinessTap) {
                    HStack(spacing: 14) {
                        // Readiness ring
                        readinessRing
                            .frame(width: 56, height: 56)

                        // Score + band
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(viewModel.readiness != nil ? "Readiness" : "Recovery")
                                    .font(.system(size: 13, weight: .semibold))
                                if let band = viewModel.readiness?.band {
                                    Text(band.rawValue)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color(hex: band.colorHex))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(hex: band.colorHex).opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                            if let rec = viewModel.readiness?.recommendation {
                                Text(rec)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: PayaRadius.card))
                }
                .buttonStyle(.plain)

                // Biometric chips
                biometricChips
            }
        }
    }

    // MARK: - Readiness Ring

    private var readinessRing: some View {
        ZStack {
            Circle()
                .stroke(scoreColor.opacity(0.15), lineWidth: 6)
            Circle()
                .trim(from: 0, to: Double(viewModel.recoveryScore ?? 0) / 100.0)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(PayaAnimation.dataChange, value: viewModel.recoveryScore)
            VStack(spacing: 0) {
                Text("\(viewModel.recoveryScore ?? 0)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(scoreColor)
                    .contentTransition(.numericText())
            }
        }
    }

    // MARK: - Biometric Chips

    private var biometricChips: some View {
        HStack(spacing: 8) {
            if let sleep = viewModel.appleHealthSleep {
                biometricChip(icon: "moon.fill", value: String(format: "%.1fh", sleep), color: "8B5CF6")
            }
            if let hr = viewModel.appleHealthHR {
                biometricChip(icon: "heart.fill", value: "\(hr) bpm", color: "DC2626")
            }
            if let hrv = viewModel.appleHealthHRV {
                biometricChip(icon: "waveform.path.ecg", value: String(format: "%.0f ms", hrv), color: "2563EB")
            }
            if let steps = viewModel.appleHealthSteps {
                biometricChip(
                    icon: "figure.walk",
                    value: steps >= 1000 ? String(format: "%.1fk", Double(steps) / 1000) : "\(steps)",
                    color: "059669"
                )
            }
            Spacer(minLength: 0)
        }
    }

    private func biometricChip(icon: String, value: String, color: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(Color(hex: color))
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(hex: color).opacity(0.08))
        .clipShape(Capsule())
    }

    // MARK: - Toolbar Buttons

    private var profileButton: some View {
        Button(action: onProfile) {
            ZStack {
                Circle()
                    .fill(Color(hex: "2563EB").opacity(0.12))
                    .frame(width: 34, height: 34)
                Text(String(appState.profile.name.prefix(1)).uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: "2563EB"))
            }
        }
    }

    private var notificationButton: some View {
        Group {
            if appState.currentProfileId != nil {
                NotificationBellButton(
                    unreadCount: unreadCount,
                    action: onNotifications
                )
            }
        }
    }

    private var settingsButton: some View {
        Button(action: onSettings) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 34, height: 34)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())
        }
        .accessibilityLabel("Settings")
    }

    private var flareDayBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
            Text("Flare")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(Color(hex: "B45309"))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(hex: "B45309").opacity(0.12))
        .clipShape(Capsule())
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 2. TODAY'S FOCUS CARD
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
// The ONE thing to do today. Training day → session preview + start CTA.
// Rest day → recovery guidance. Replaces 8 separate cards.

struct TodayFocusCard: View {

    @Environment(\.modelContext) private var modelContext
    var appState: AppState
    var viewModel: DashboardViewModel
    @Binding var selectedTab: Int

    @State private var todayDay: DaySnapshot? = nil
    @State private var exercises: [String] = []
    @State private var actions: [DailyAction] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: what kind of day is it?
            Button { selectedTab = 1 } label: {
                HStack(spacing: 12) {
                    if let day = todayDay {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(day.color.opacity(0.15))
                                .frame(width: 48, height: 48)
                            Text(day.code)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(day.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            Text(day.focus)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(day.color)
                        }
                        Spacer()
                        Text("Start")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(day.color)
                            .clipShape(Capsule())
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "059669").opacity(0.15))
                                .frame(width: 48, height: 48)
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "059669"))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rest day")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Recovery + nutrition focus")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .buttonStyle(.plain)

            // Exercise pills (training day only)
            if todayDay != nil, !exercises.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(exercises, id: \.self) { name in
                            Text(shortName(name))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.top, 10)
            }

            // Top 2 daily actions (condensed)
            if !actions.isEmpty {
                Divider()
                    .padding(.vertical, 10)

                ForEach(Array(actions.prefix(2))) { action in
                    HStack(spacing: 8) {
                        Image(systemName: action.icon)
                            .font(.system(size: 11))
                            .foregroundColor(action.color)
                            .frame(width: 22, height: 22)
                            .background(action.color.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text(action.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Text(action.domain)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(action.color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(action.color.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .padding(.bottom, actions.last?.id == action.id ? 0 : 4)
                }
            }
        }
        .payaCard()
        .onAppear {
            TrainingDayStore.seedIfNeeded(context: modelContext)
            todayDay = TrainingDayStore.today(context: modelContext)
            if let day = todayDay {
                let defs = CustomSessionStore.effectiveExercises(forCode: day.code, context: modelContext)
                exercises = defs.map(\.name)
            }
            buildActions()
        }
    }

    private func shortName(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: " — ", with: " ").replacingOccurrences(of: "°", with: "")
        let words = cleaned.split(separator: " ")
        if words.count <= 2 { return cleaned }
        return words.prefix(2).joined(separator: " ")
    }

    // MARK: - Condensed Action Builder

    private func buildActions() {
        let calendar = Calendar.current
        let pid = ActiveProfile.id
        let today = calendar.startOfDay(for: Date())
        let profile = appState.profile
        var result: [DailyAction] = []

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let healthDesc = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> {
                $0.profileId == pid && $0.date >= yesterday && $0.date < today
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let lastHealth = (try? modelContext.fetch(healthDesc))?.first

        if let sleep = lastHealth?.sleepHours, sleep < 6 {
            result.append(DailyAction(
                icon: "moon.fill",
                title: "Low sleep — reduce intensity",
                detail: String(format: "%.1fh sleep. Drop volume ~20%%.", sleep),
                color: Color(hex: "DC2626"),
                priority: 1,
                domain: "recovery"
            ))
        }

        let nutritionDesc = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> {
                $0.profileId == pid && $0.date >= yesterday && $0.date < today
            }
        )
        if let yesterdayNutrition = (try? modelContext.fetch(nutritionDesc))?.first {
            let deficit = profile.proteinTargetG - yesterdayNutrition.totalProtein
            if deficit > 30 {
                result.append(DailyAction(
                    icon: "fork.knife",
                    title: "Front-load protein today",
                    detail: String(format: "%.0fg deficit yesterday.", deficit),
                    color: Color(hex: "2563EB"),
                    priority: 2,
                    domain: "nutrition"
                ))
            }
        }

        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let sessionDesc = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> {
                $0.profileId == pid && $0.isCompleted && $0.date >= sevenDaysAgo
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let recentSessions = (try? modelContext.fetch(sessionDesc)) ?? []
        var consecutiveDays = 0
        for dayOffset in 1...5 {
            guard let checkDay = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { break }
            let dayStart = calendar.startOfDay(for: checkDay)
            if recentSessions.contains(where: { calendar.isDate($0.date, inSameDayAs: dayStart) }) {
                consecutiveDays += 1
            } else { break }
        }
        if consecutiveDays >= 3 && appState.isTrainingDay {
            result.append(DailyAction(
                icon: "exclamationmark.triangle.fill",
                title: "\(consecutiveDays) days straight — watch fatigue",
                detail: "Consider lighter volume today.",
                color: Color(hex: "F59E0B"),
                priority: 2,
                domain: "training"
            ))
        }

        if let energy = lastHealth?.energyLevel, energy == 1 {
            result.append(DailyAction(
                icon: "bolt.slash.fill",
                title: "Low energy — check hydration",
                detail: "Aim 2-3L water, eat within 1h of waking.",
                color: Color(hex: "F59E0B"),
                priority: 3,
                domain: "health"
            ))
        }

        actions = result.sorted { $0.priority < $1.priority }
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 3. VITALS STRIP
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
// Protein, Calories, Water, Weight — four compact cells in one row.
// Replaces NutritionMiniCard + WeightMiniCard + QuickHydrationCard + SupplementTimingCard.

struct VitalsStrip: View {

    var viewModel: DashboardViewModel
    var appState: AppState
    @Binding var selectedTab: Int
    var onLogWeight: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var waterMl: Int = 0

    var body: some View {
        HStack(spacing: 10) {
            // Protein
            vitalCell(
                icon: "fork.knife",
                label: "Protein",
                value: "\(Int(viewModel.todaysNutrition?.totalProtein ?? 0))",
                unit: "g",
                progress: viewModel.proteinProgress,
                color: "2563EB"
            ) {
                selectedTab = 2
            }

            // Calories
            vitalCell(
                icon: "flame.fill",
                label: "Calories",
                value: "\(Int(viewModel.todaysNutrition?.totalCalories ?? 0))",
                unit: "",
                progress: viewModel.calorieProgress,
                color: "F59E0B"
            ) {
                selectedTab = 2
            }

            // Water
            vitalCell(
                icon: "drop.fill",
                label: "Water",
                value: waterMl >= 1000 ? String(format: "%.1f", Double(waterMl) / 1000) : "\(waterMl)",
                unit: waterMl >= 1000 ? "L" : "ml",
                progress: min(1.0, Double(waterMl) / Double(WaterStore.dailyTargetMl)),
                color: "0891B2"
            ) {
                addWater(250)
            }

            // Weight
            vitalCell(
                icon: "scalemass.fill",
                label: "Weight",
                value: viewModel.latestWeight.map { String(format: "%.1f", $0) } ?? "—",
                unit: "kg",
                progress: nil,
                color: "059669"
            ) {
                onLogWeight()
            }
        }
        .onAppear {
            waterMl = WaterStore.todayTotal(context: modelContext)
        }
    }

    private func addWater(_ ml: Int) {
        waterMl = WaterStore.addWater(ml, context: modelContext)
        WatchSessionManager.shared.pushWaterTotal(waterMl)
    }

    private func vitalCell(
        icon: String,
        label: String,
        value: String,
        unit: String,
        progress: Double?,
        color: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Mini progress ring or icon
                ZStack {
                    if let prog = progress {
                        Circle()
                            .stroke(Color(hex: color).opacity(0.12), lineWidth: 3)
                            .frame(width: 32, height: 32)
                        Circle()
                            .trim(from: 0, to: prog)
                            .stroke(Color(hex: color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))
                            .animation(PayaAnimation.dataChange, value: prog)
                    }
                    Image(systemName: icon)
                        .font(.system(size: progress != nil ? 10 : 13))
                        .foregroundColor(Color(hex: color))
                }
                .frame(height: 32)

                HStack(spacing: 1) {
                    Text(value)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 4. RECOVERY BRIEF
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
// Only shows when there's something worth calling out: sleep debt, low
// readiness, or behavioral recovery insight. Disappears when everything
// is normal — no noise for no signal.

struct RecoveryBrief: View {

    var viewModel: DashboardViewModel
    var onReadinessTap: () -> Void

    var body: some View {
        let items = buildItems()
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.text.clipboard")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "059669"))
                    Text("Recovery notes")
                        .font(.system(size: 13, weight: .semibold))
                }

                ForEach(items, id: \.title) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color(hex: item.color))
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(.system(size: 12, weight: .semibold))
                            Text(item.detail)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .payaCard(padding: 14)
        }
    }

    private struct BriefItem {
        let title: String
        let detail: String
        let color: String
    }

    private func buildItems() -> [BriefItem] {
        var items: [BriefItem] = []

        // Low readiness
        if let score = viewModel.recoveryScore, score < 50 {
            items.append(BriefItem(
                title: "Low readiness (\(score)/100)",
                detail: "Consider lighter loads or active recovery today.",
                color: "DC2626"
            ))
        }

        // Sleep insight
        if let sleep = viewModel.appleHealthSleep {
            if sleep < 6 {
                items.append(BriefItem(
                    title: String(format: "Short sleep (%.1fh)", sleep),
                    detail: "Below 6h reduces strength output 10-15%. Prioritize an early night.",
                    color: "F59E0B"
                ))
            }
        }

        // Journey notes from readiness engine
        if let notes = viewModel.readiness?.journeyNotes, !notes.isEmpty {
            items.append(BriefItem(
                title: "Trend",
                detail: notes.first ?? "",
                color: "2563EB"
            ))
        }

        return items
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - FLARE ALERT BANNER
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct FlareAlertBanner: View {
    var assessment: FlareRiskAssessment

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: assessment.level.icon)
                .font(.system(size: 12))
                .foregroundColor(assessment.level.color)
            Text("Flare risk \(assessment.level.displayName.lowercased())")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(assessment.level.color)
            Text("·")
                .foregroundColor(.secondary)
            Text(assessment.recommendation)
                .font(.system(size: 11))
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
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - 5. WEEK SUMMARY
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//
// Compact weekly stats: sessions, streak, volume + last session one-liner.
// Replaces 6 cards: WeeklyStatsCard, TrainingConsistencyBanner, WeeklyPlanCard,
// LastSessionCard, MomentumCard, MilestoneCelebrationCard.

struct WeekSummary: View {

    var viewModel: DashboardViewModel
    var appState: AppState

    private var useLbs: Bool { appState.profile.prefersLbs }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "2563EB"))
                Text("This week")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if viewModel.weekStreak > 1 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                        Text("\(viewModel.weekStreak)w streak")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "DC2626"))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(hex: "DC2626").opacity(0.08))
                    .clipShape(Capsule())
                }
            }

            // Stats row
            HStack(spacing: 0) {
                statCell(
                    value: "\(viewModel.thisWeekSessions)/\(viewModel.thisWeekPossibleSessions)",
                    label: "Sessions",
                    color: sessionColor
                )
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 0.5, height: 28)
                    .padding(.horizontal, 4)
                statCell(
                    value: volumeLabel,
                    label: "Volume",
                    color: Color(hex: "0891B2")
                )
                if let lastSession = viewModel.lastSession {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 0.5, height: 28)
                        .padding(.horizontal, 4)
                    statCell(
                        value: lastSessionLabel(lastSession),
                        label: "Last session",
                        color: .secondary
                    )
                }
            }
        }
        .payaCard(padding: 14)
    }

    private var sessionColor: Color {
        if viewModel.thisWeekSessions >= viewModel.thisWeekPossibleSessions { return Color(hex: "059669") }
        if viewModel.thisWeekSessions > 0 { return Color(hex: "F59E0B") }
        return .secondary
    }

    private var volumeLabel: String {
        let vol = useLbs ? viewModel.thisWeekVolume * 2.20462 : viewModel.thisWeekVolume
        if vol >= 1000 {
            return String(format: "%.1f%@", vol / 1000, useLbs ? "klbs" : "t")
        }
        return String(format: "%.0f%@", vol, useLbs ? "lbs" : "kg")
    }

    private func lastSessionLabel(_ session: TrainingSession) -> String {
        guard let days = viewModel.lastSessionDaysAgo else { return "—" }
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days)d ago"
    }

    private func statCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - CHECK-IN PROMPT (kept from original, lightly restyled)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

extension DashboardView {

    struct CheckInPromptCard: View {
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 10) {
                    Text(greetingEmoji)
                        .font(.system(size: 24))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Morning check-in")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Rate body, energy & sleep — adjusts training loads")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .payaCard(padding: 12)
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
                            .background(weightInput.isEmpty ? Color.secondary.opacity(0.5) : Color(hex: "059669"))
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
