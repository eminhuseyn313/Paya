import SwiftUI
import SwiftData

// MARK: - Pulse Dashboard
//
// A radically different home screen. Not a card dump — a living health canvas.
//
// Architecture:
// ┌──────────────────────────────────────┐
// │  Atmospheric Background (ambient)    │  Gradient + breathing orb
// ├──────────────────────────────────────┤
// │  Greeting + Controls (minimal)       │  Name + 2 icons
// ├──────────────────────────────────────┤
// │  HERO: Readiness Ring + Score        │  The ONE thing — large, central
// │  + Band label + insight line         │
// ├──────────────────────────────────────┤
// │  Vitals Orbs (horizontal scroll)     │  Protein · Cal · Water · Weight · HR
// ├──────────────────────────────────────┤
// │  Hero Insight Card                   │  Context-aware "one big thing"
// ├──────────────────────────────────────┤
// │  Today's Focus (training/rest)       │  What to do — one CTA
// ├──────────────────────────────────────┤
// │  Week Pulse (compact)                │  3/3 sessions · 7.1t volume
// ├──────────────────────────────────────┤
// │  Quick Actions (chips)               │  Log food · Check in · Start session
// └──────────────────────────────────────┘
//
// Design principles:
// 1. Hero-first: Readiness score dominates — understood in <3 seconds
// 2. Atmospheric: Dark canvas with ambient glow reflecting state
// 3. Organic: Circles, arcs, orbs — no rectangular grid
// 4. Motion: Ring fills, numbers count, orb breathes
// 5. Progressive: Tap anything for detail sheets

struct WeekDayStatus: Identifiable {
    let id: Int
    let label: String
    let trained: Bool
    let isToday: Bool
    let isFuture: Bool

    var dotColor: Color {
        if trained { return Pulse.positive }
        if isToday { return Pulse.energy }
        if isFuture { return .white }
        return .white
    }
}

struct PulseDashboardView: View {

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
    @State private var showAdHocPicker = false
    @State private var todaysPicture: DayOverview? = nil
    @Query private var notificationRecords: [NotificationRecord]
    @Binding var selectedTab: Int
    @State private var lastLoadTime: Date = .distantPast
    @State private var hasAppeared = false
    @State private var todayTrainingDay: DaySnapshot? = nil
    @State private var showWaterSheet = false
    @State private var showHealthJourney = false
    @State private var showHealthProfileSummary = false
    @State private var showFoodQuickPicker = false
    @State private var showAskPaya = false
    @State private var trainingStreak: Int = 0

    private var readinessScore: Int {
        viewModel.readiness?.score ?? viewModel.recoveryScore ?? 0
    }

    private var readinessBand: String {
        viewModel.readiness?.band.rawValue ?? (readinessScore >= 80 ? "Primed" : readinessScore >= 60 ? "Steady" : readinessScore >= 40 ? "Caution" : "Recover")
    }

    private var stateColor: Color {
        if readinessScore >= 80 { return Pulse.positive }
        if readinessScore >= 60 { return Pulse.recovery }
        if readinessScore >= 40 { return Pulse.warning }
        return Pulse.critical
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // ━━━ Atmospheric Background ━━━
                atmosphericBackground

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // ━━━ 1. Greeting Bar ━━━
                        greetingBar
                            .padding(.top, 8)

                        // ━━━ 1.5 Connection Status ━━━
                        watchConnectionPill

                        // ━━━ 2. Hero Readiness ━━━
                        heroReadiness

                        // ━━━ 3. Vitals Orbs ━━━
                        vitalsOrbs

                        // ━━━ 4. Flare Alert — most urgent, leads everything
                        // below it. Previously this rendered after the health
                        // journey banner and nudge cards, so a genuine health
                        // warning had the SAME visual weight (and lower
                        // position) as routine prompts like "complete your
                        // health journey" — urgency wasn't legible from
                        // position or treatment alone.
                        if appState.flareEngineEnabled,
                           let assessment = viewModel.flareAssessment,
                           // Surface the card when TODAY is elevated, OR when
                           // today looks fine but the forecast says it won't
                           // stay that way — the entire point of a leading
                           // indicator is catching this case, which the old
                           // `assessment.level != .low` check couldn't.
                           assessment.level != .low || viewModel.flareForecast?.trajectory == .worsening {
                            flareAlert(assessment, forecast: viewModel.flareForecast)
                        }

                        // ━━━ 5. Hero Insight ━━━
                        heroInsightCard

                        // ━━━ 6. Today's Focus ━━━
                        todayFocus

                        // ━━━ 7. Daily Actions ━━━
                        DailyActionCard()

                        // ━━━ 8. Health — collapsed to ONE entry point.
                        // Previously up to 3 separate full-width cards
                        // (journey banner, profile badge, up to 2 nudge
                        // cards) stacked here regardless of urgency — all
                        // routine/informational, none as time-critical as the
                        // flare alert above, so they don't need to compete
                        // for the same "full card" attention budget.
                        healthSummaryEntry

                        // ━━━ 9. Week Pulse ━━━
                        weekPulse

                        // ━━━ 10. Quick Actions ━━━
                        quickActions

                        Spacer().frame(height: 56)
                    }
                    .padding(.horizontal, 20)
                }
                // Scroll-edge protection: content scrolls under the status
                // bar (navigationBarHidden removes the normal opaque nav-bar
                // backing that would otherwise sit behind it), so without
                // this a scrolled-up row — e.g. the readiness driver strip's
                // "Resting HR" label — renders directly under the clock/
                // signal icons with no legibility protection. Pinned outside
                // the ScrollView so it stays put regardless of scroll offset.
                VStack {
                    LinearGradient(
                        colors: [Pulse.canvasFallback, Pulse.canvasFallback.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 50)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                    Spacer()
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
                        // Recovery notifications used to just switch to Home
                        // and leave the user to find the ring themselves —
                        // now opens the actual driver breakdown directly,
                        // matching what the notification body now explains.
                        if record.category == .recovery {
                            selectedTab = 0
                            if viewModel.readiness != nil { showReadinessDetail = true }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCheckIn) {
                DailyCheckInView(onDone: { loadData() })
            }
            .sheet(isPresented: $showFlareRiskDetail) {
                if let assessment = viewModel.flareAssessment {
                    FlareRiskDetailView(assessment: assessment, forecast: viewModel.flareForecast)
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
            .sheet(isPresented: $showAskPaya) {
                AskPayaView()
            }
            .sheet(isPresented: $showWaterSheet) {
                WaterQuickSheet()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showFoodQuickPicker) {
                FoodQuickPickerSheet { action in
                    showFoodQuickPicker = false
                    appState.pendingNutritionAction = action
                    // Small delay so the sheet dismiss animation completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedTab = 2
                    }
                }
                .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $showHealthJourney) {
                if let profile = ProfileStore.current(context: modelContext) {
                    HealthJourneyView(profile: profile)
                }
            }
            .sheet(isPresented: $showHealthProfileSummary) {
                if let profile = ProfileStore.current(context: modelContext) {
                    HealthProfileSummaryView(profile: profile) {
                        showHealthJourney = true
                    }
                }
            }
        }
        .onAppear {
            loadData()
            withAnimation(.easeOut(duration: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in loadData() }
    }

    // MARK: - Atmospheric Background

    private var atmosphericBackground: some View {
        ZStack {
            // Base canvas
            Pulse.canvasFallback
                .ignoresSafeArea()

            // State-responsive ambient glow
            BreathingOrb(color: stateColor, size: 300)
                .offset(y: -200)
                .opacity(0.6)

            // Secondary ambient
            Circle()
                .fill(Pulse.hydration.opacity(0.04))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: 150, y: 300)
        }
    }

    // MARK: - Greeting Bar

    private var greetingBar: some View {
        HStack {
            // Tappable profile avatar — opens profile editor
            Button { showProfileSwitcher = true } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Pulse.ai.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Text(profileInitials)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Pulse.ai)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(greetingText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Pulse.textTertiary)
                        HStack(spacing: 8) {
                            Text(appState.profile.name.isEmpty ? "Athlete" : appState.profile.name.components(separatedBy: " ").first ?? "Athlete")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(Pulse.textPrimary)

                            if trainingStreak >= 2 {
                                HStack(spacing: 3) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 10))
                                    Text("\(trainingStreak)")
                                        .font(.system(size: 11, weight: .black, design: .rounded))
                                }
                                .foregroundColor(Pulse.energy)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Pulse.energy.opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .buttonStyle(PulsePress())

            Spacer()

            // Notification bell
            Button { showNotifications = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Pulse.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(Pulse.surfaceFallback)
                        .clipShape(Circle())

                    if unreadNotificationCount > 0 {
                        Text("\(min(unreadNotificationCount, 99))")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Pulse.critical)
                            .clipShape(Capsule())
                            .offset(x: 4, y: -2)
                    }
                }
            }

            // Settings
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Pulse.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(Pulse.surfaceFallback)
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Hero Readiness

    private var heroReadiness: some View {
        Button { showReadinessDetail = true } label: {
            VStack(spacing: 16) {
                ZStack {
                    if viewModel.hasWearableData || readinessScore > 0 {
                        // The ring
                        PulseRing(
                            progress: CGFloat(readinessScore) / 100.0,
                            size: 180,
                            lineWidth: 14,
                            color: stateColor
                        )

                        // Score inside
                        VStack(spacing: 4) {
                            PulseCounter(
                                value: readinessScore,
                                font: .system(size: 56, weight: .bold, design: .rounded),
                                color: stateColor
                            )
                            Text("Readiness")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Pulse.textTertiary)
                        }
                    } else {
                        // No wearable — show placeholder ring
                        PulseRing(
                            progress: 0,
                            size: 180,
                            lineWidth: 14,
                            color: Pulse.textTertiary.opacity(0.3)
                        )
                        VStack(spacing: 6) {
                            Image(systemName: "applewatch.slash")
                                .font(.system(size: 28))
                                .foregroundColor(Pulse.textTertiary)
                            Text("Readiness")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Pulse.textTertiary)
                        }
                    }
                }

                if viewModel.hasWearableData || readinessScore > 0 {
                    // Band label
                    Text(readinessBand)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(stateColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .background(stateColor.opacity(0.12))
                        .clipShape(Capsule())

                    // One-line recommendation
                    if let recommendation = viewModel.readiness?.recommendation {
                        Text(recommendation.components(separatedBy: ".").first ?? recommendation)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Pulse.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 20)
                    }

                    // ━━━ Driver breakdown — Whoop/Oura-style factor indicators ━━━
                    // Shows what's driving the score up or down at a glance
                    // without tapping into the detail sheet.
                    if let drivers = viewModel.readiness?.drivers, !drivers.isEmpty {
                        readinessDriverStrip(drivers: drivers)
                    }
                } else {
                    // No wearable explanation
                    Text("Connect a wearable")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.textSecondary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .background(Pulse.surfaceFallback)
                        .clipShape(Capsule())

                    Text("Pair an Apple Watch or sync a wearable via Apple Health to get your personalized readiness score.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Pulse.textTertiary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(PulsePress())
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.9)
    }

    // MARK: - Readiness Driver Strip

    /// Compact horizontal factor bars showing what's driving the readiness score.
    /// Each driver shows icon + label + mini progress bar + score.
    /// Inspired by Oura's contributing-factor breakdown.
    @ViewBuilder
    private func readinessDriverStrip(drivers: [ReadinessEngine.Driver]) -> some View {
        VStack(spacing: 6) {
            ForEach(drivers.prefix(4)) { driver in
                HStack(spacing: 8) {
                    // Semantic icon per driver type
                    Image(systemName: driverIcon(for: driver.id))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(driverColor(for: driver.id))
                        .frame(width: 14)

                    Text(driver.label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Pulse.textSecondary)
                        .frame(width: 72, alignment: .leading)

                    // Mini progress bar — score 0-100 mapped to fill
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Pulse.surfaceFallback)
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(driverBarColor(score: driver.score))
                                .frame(width: geo.size.width * CGFloat(min(driver.score, 100) / 100.0), height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("\(Int(driver.score))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(driverBarColor(score: driver.score))
                        .monospacedDigit()
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }

    private func driverIcon(for id: String) -> String {
        switch id {
        case "hrv":     return "waveform.path.ecg"
        case "rhr":     return "heart.fill"
        case "sleep":   return "moon.fill"
        case "load":    return "figure.strengthtraining.traditional"
        case "checkin": return "face.smiling"
        default:        return "circle.fill"
        }
    }

    private func driverColor(for id: String) -> Color {
        switch id {
        case "hrv":     return Pulse.recovery
        case "rhr":     return Pulse.vitals
        case "sleep":   return Pulse.ai
        case "load":    return Pulse.energy
        case "checkin": return Pulse.positive
        default:        return Pulse.textSecondary
        }
    }

    /// Bar fill color based on individual driver score.
    /// Green ≥ 70, amber 40–69, red < 40 — matches readiness band thresholds
    /// shifted down slightly for individual components.
    private func driverBarColor(score: Double) -> Color {
        if score >= 70 { return Pulse.positive }
        if score >= 40 { return Pulse.warning }
        return Pulse.critical
    }

    // MARK: - Watch Connection Pill

    @ViewBuilder
    private var watchConnectionPill: some View {
        // Read directly from source @Observable singletons — LiveHRManager's
        // computed properties don't propagate observation to the BLE/Watch
        // objects they delegate to.
        let watch = WatchSessionManager.shared
        let ble = BLEHeartRateManager.shared
        let hasBLE = ble.currentBPM != nil
        let hasWatchHR: Bool = {
            guard let _ = watch.watchHeartRate,
                  let ts = watch.watchHeartRateTimestamp else { return false }
            return Date().timeIntervalSince(ts) < 30
        }()
        let isLive = hasBLE || hasWatchHR

        if watch.hasActivated {
            HStack(spacing: 8) {
                // Connection dot — green when reachable, amber when paired but not on wrist
                Circle()
                    .fill(watch.isWatchReachable ? Pulse.positive : (watch.isConnected ? Pulse.warning : Pulse.textTertiary))
                    .frame(width: 6, height: 6)

                Image(systemName: watch.isConnected ? "applewatch" : "applewatch.slash")
                    .font(.system(size: 11))
                    .foregroundColor(watch.isWatchReachable ? Pulse.positive : Pulse.textTertiary)

                Text(watch.connectionLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Pulse.textSecondary)

                // Live HR source indicator
                if isLive {
                    Spacer(minLength: 4)
                    LiveHRPill()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Pulse.surfaceFallback)
                    .overlay(
                        Capsule()
                            .stroke(
                                (watch.isWatchReachable ? Pulse.positive : Pulse.textTertiary).opacity(0.15),
                                lineWidth: 0.5
                            )
                    )
            )
        }
    }

    // MARK: - Vitals Orbs

    private func progressColor(_ progress: Double) -> Color {
        let hour = Calendar.current.component(.hour, from: Date())
        let dayFraction = max(0.3, Double(hour) / 24.0)
        let adjusted = progress / dayFraction
        if adjusted >= 0.8 { return Pulse.positive }
        if adjusted >= 0.5 { return Pulse.warning }
        return Pulse.critical
    }

    private var vitalsOrbs: some View {
        let protein = viewModel.todaysNutrition?.totalProtein ?? 0
        let proteinTarget = viewModel.todaysNutrition?.proteinTarget ?? appState.profile.proteinTargetG
        let calories = viewModel.todaysNutrition?.totalCalories ?? 0
        let calorieTarget = viewModel.todaysNutrition?.calorieTarget ?? 2200
        let waterMl = WaterStore.todayTotal(context: modelContext)
        let waterTarget: Double = Double(WaterStore.dailyTargetMl)
        let proteinProgress = proteinTarget > 0 ? protein / proteinTarget : 0
        let calorieProgress = calorieTarget > 0 ? calories / calorieTarget : 0
        let waterProgress = waterTarget > 0 ? Double(waterMl) / waterTarget : 0

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                MetricOrb(
                    value: "\(Int(protein))",
                    unit: "g",
                    label: "Protein",
                    color: progressColor(proteinProgress),
                    progress: proteinProgress,
                    action: { showFoodQuickPicker = true }
                )

                MetricOrb(
                    value: "\(Int(calories))",
                    unit: "kcal",
                    label: "Calories",
                    color: progressColor(calorieProgress),
                    progress: calorieProgress,
                    action: { showFoodQuickPicker = true }
                )

                MetricOrb(
                    value: waterMl >= 1000 ? String(format: "%.1f", Double(waterMl) / 1000) : "\(waterMl)",
                    unit: waterMl >= 1000 ? "L" : "ml",
                    label: "Water",
                    color: progressColor(waterProgress),
                    progress: waterProgress,
                    action: { showWaterSheet = true }
                )

                MetricOrb(
                    value: viewModel.latestWeight.map { String(format: "%.1f", $0) } ?? "—",
                    unit: "kg",
                    label: "Weight",
                    color: Pulse.recovery,
                    action: { showWeightEntry = true }
                )

                // Live HR (BLE/Watch) takes priority over resting HR from HealthKit.
                // Read directly from source @Observable — LiveHRManager's computed
                // properties don't propagate observation across object boundaries.
                if let liveBPM = BLEHeartRateManager.shared.currentBPM {
                    MetricOrb(
                        value: "\(liveBPM)",
                        unit: "bpm",
                        label: "♥ Live",
                        color: LiveHRManager.shared.zone(for: liveBPM)?.color ?? Pulse.vitals,
                        progress: min(Double(liveBPM) / 200.0, 1.0),
                        action: { selectedTab = 3 }
                    )
                } else if let watchBPM = WatchSessionManager.shared.watchHeartRate,
                          let ts = WatchSessionManager.shared.watchHeartRateTimestamp,
                          Date().timeIntervalSince(ts) < 30 {
                    MetricOrb(
                        value: "\(watchBPM)",
                        unit: "bpm",
                        label: "♥ Watch",
                        color: LiveHRManager.shared.zone(for: watchBPM)?.color ?? Pulse.vitals,
                        progress: min(Double(watchBPM) / 200.0, 1.0),
                        action: { selectedTab = 3 }
                    )
                } else if let hr = viewModel.appleHealthHR {
                    MetricOrb(
                        value: "\(hr)",
                        unit: "bpm",
                        label: "Heart",
                        color: Pulse.vitals,
                        // Inverted: lower resting HR = better (Reimers et al. 2013)
                        progress: 1.0 - max(0, min((Double(hr) - 45) / 55, 1.0)),
                        action: { selectedTab = 3 }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
    }

    // MARK: - Hero Insight

    private var heroInsightCard: some View {
        Group {
            let hour = Calendar.current.component(.hour, from: .now)

            if appState.morningCheckInEnabled && !viewModel.hasCheckedInToday && hour < 12 {
                HeroInsight(
                    emoji: "☀️",
                    headline: "Start your day",
                    detail: "A quick check-in helps personalize your training intensity and recovery recommendations.",
                    accentColor: Pulse.nutrition,
                    action: { showCheckIn = true }
                )
            } else if let sleep = viewModel.appleHealthSleep, hour < 10 {
                HeroInsight(
                    emoji: sleep >= 7 ? "😴" : "⚡",
                    headline: sleep >= 7 ? "Solid recovery base" : "Light sleep — go easier today",
                    detail: String(format: "%.1f hours of sleep. %@", sleep,
                                   sleep >= 7 ? "Your body had time to recover. Push if readiness agrees." : "Below 7h — consider reducing volume ~20%."),
                    accentColor: sleep >= 7 ? Pulse.recovery : Pulse.warning
                )
            } else if let lastSession = viewModel.lastSession,
                      Calendar.current.isDateInToday(lastSession.date),
                      lastSession.isCompleted {
                let duration = Int(lastSession.durationMinutes)
                let exerciseCount = lastSession.exercises.count
                HeroInsight(
                    emoji: "🏋️",
                    headline: "Session complete",
                    detail: "\(exerciseCount) exercises in \(duration) min. Great work — check your trends to see progress.",
                    accentColor: Pulse.positive,
                    action: { selectedTab = 4 }
                )
            } else if readinessScore >= 80 {
                HeroInsight(
                    emoji: "🟢",
                    headline: "You're ready to push",
                    detail: "Readiness is high. Your body is primed for progression — consider adding intensity or volume.",
                    accentColor: Pulse.positive
                )
            } else if readinessScore < 40 {
                HeroInsight(
                    emoji: "🔴",
                    headline: "Recovery needs attention",
                    detail: "Low readiness score. Consider a rest day or light mobility work. Your body is asking for time.",
                    accentColor: Pulse.critical
                )
            } else {
                HeroInsight(
                    emoji: "💪",
                    headline: appState.isTrainingDay ? "Training day" : "Rest & recover",
                    detail: appState.isTrainingDay
                        ? "Your session is ready. Warm up before lifting to reduce injury risk."
                        : "Recovery + nutrition focus today. Protein front-loading optimizes repair.",
                    accentColor: appState.isTrainingDay ? Pulse.energy : Pulse.recovery,
                    action: appState.isTrainingDay ? { selectedTab = 1 } : nil
                )
            }
        }
    }

    // MARK: - Flare Alert

    private func flareAlert(_ assessment: FlareRiskAssessment, forecast: FlareForecastEngine.Forecast?) -> some View {
        // Today's level can legitimately be .low while the forecast is
        // worsening — the card's headline and color should track whichever
        // is more urgent, not just today's snapshot, or the leading-
        // indicator case would show as a bland "low risk" card.
        let isForecastLed = assessment.level == .low && forecast?.trajectory == .worsening
        let color = assessment.level == .high ? Pulse.critical
            : (assessment.level == .low && isForecastLed) ? Pulse.warning
            : Pulse.warning

        return Button { showFlareRiskDetail = true } label: {
            HStack(spacing: 12) {
                Image(systemName: isForecastLed ? "chart.line.uptrend.xyaxis" : "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isForecastLed ? "Flare risk rising" : "Flare risk: \(assessment.level.rawValue)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Pulse.textPrimary)
                    Text(isForecastLed
                         ? (forecast?.summary ?? "")
                         : (assessment.recommendation.components(separatedBy: ".").first ?? ""))
                        .font(.system(size: 12))
                        .foregroundColor(Pulse.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Pulse.textTertiary)
            }
            .pulseSurfaceGlow(
                color: color,
                padding: 16
            )
        }
        .buttonStyle(PulsePress())
    }

    // MARK: - Today's Focus

    private var todayFocus: some View {
        Group {
            if appState.isTrainingDay {
                Button { selectedTab = 1 } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Pulse.energy.opacity(0.15))
                                .frame(width: 52, height: 52)
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 22))
                                .foregroundColor(Pulse.energy)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start training")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(Pulse.textPrimary)
                            if let dayName = todayTrainingDay?.name {
                                Text(dayName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Pulse.textSecondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Pulse.energy)
                    }
                    .pulseSurfaceGlow(color: Pulse.energy, padding: 16)
                }
                .buttonStyle(PulsePress())
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Pulse.recovery.opacity(0.15))
                                .frame(width: 52, height: 52)
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Pulse.recovery)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rest day")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(Pulse.textPrimary)
                            Text("Recovery + nutrition focus")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Pulse.textSecondary)
                        }

                        Spacer()

                        Button {
                            showAdHocPicker = true
                        } label: {
                            Text("Train anyway")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Pulse.energy)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Pulse.energy.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
                .pulseSurfaceGlow(color: Pulse.recovery, padding: 16)
                .confirmationDialog("Pick a session", isPresented: $showAdHocPicker) {
                    let days = TrainingDayStore.allSnapshots(context: modelContext)
                    ForEach(days, id: \.code) { day in
                        Button("\(day.name) — \(day.focus)") {
                            selectedTab = 1
                        }
                    }
                }
            }
        }
    }

    // MARK: - Week Pulse

    @State private var weekDayStatuses: [WeekDayStatus] = []

    private var weekPulse: some View {
        VStack(spacing: 12) {
            PulseSectionHeader(title: "This week", icon: "calendar")

            VStack(spacing: 14) {
                // Day-by-day dot strip (Mon–Sun)
                if !weekDayStatuses.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(weekDayStatuses) { day in
                            VStack(spacing: 6) {
                                Text(day.label)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(day.isToday ? Pulse.textPrimary : Pulse.textTertiary)

                                ZStack {
                                    Circle()
                                        .fill(day.dotColor.opacity(day.isToday ? 0.2 : 0.1))
                                        .frame(width: 28, height: 28)

                                    if day.trained {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .black))
                                            .foregroundColor(Pulse.positive)
                                    } else if day.isToday {
                                        Circle()
                                            .fill(Pulse.energy)
                                            .frame(width: 6, height: 6)
                                    } else if day.isFuture {
                                        Circle()
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                            .frame(width: 28, height: 28)
                                    }
                                }

                                if day.isToday {
                                    Capsule()
                                        .fill(Pulse.energy)
                                        .frame(width: 12, height: 2)
                                } else {
                                    Spacer().frame(height: 2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }

                // Stats row
                HStack(spacing: 0) {
                    weekStat(
                        value: "\(viewModel.thisWeekSessions)/\(viewModel.thisWeekPossibleSessions)",
                        label: "Sessions",
                        color: Pulse.energy
                    )
                    Divider()
                        .frame(height: 30)
                        .overlay(Color.white.opacity(0.1))
                    weekStat(
                        value: viewModel.thisWeekVolume > 0 ? String(format: "%.1ft", viewModel.thisWeekVolume / 1000) : "—",
                        label: "Volume",
                        color: Pulse.positive
                    )
                    Divider()
                        .frame(height: 30)
                        .overlay(Color.white.opacity(0.1))
                    weekStat(
                        value: lastSessionLabel,
                        label: "Last session",
                        color: Pulse.recovery
                    )
                }
            }
            .pulseSurface(padding: 16)
        }
    }

    private func weekStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                PulseChip(icon: "fork.knife", label: "Log food", color: Pulse.nutrition) {
                    showFoodQuickPicker = true
                }
                PulseChip(icon: "drop.fill", label: "Water", color: Pulse.hydration) {
                    showWaterSheet = true
                }
                if appState.morningCheckInEnabled && !viewModel.hasCheckedInToday {
                    PulseChip(icon: "sun.max.fill", label: "Check in", color: Pulse.nutrition) {
                        showCheckIn = true
                    }
                }
                PulseChip(icon: "chart.line.uptrend.xyaxis", label: "Insights", color: Pulse.ai) {
                    selectedTab = 4
                }
                PulseChip(icon: "sparkles", label: "Ask Paya", color: Pulse.ai) {
                    showAskPaya = true
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
    }

    // MARK: - Helpers

    private var lastSessionLabel: String {
        guard let days = viewModel.lastSessionDaysAgo else { return "—" }
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days)d ago"
    }

    private var profileInitials: String {
        let name = appState.profile.name
        let parts = name.components(separatedBy: " ").filter { !$0.isEmpty }
        if parts.isEmpty { return "P" }
        if parts.count == 1 { return String(parts[0].prefix(1)).uppercased() }
        return (String(parts[0].prefix(1)) + String(parts[1].prefix(1))).uppercased()
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Good morning," }
        if hour < 17 { return "Good afternoon," }
        return "Good evening,"
    }

    private var unreadNotificationCount: Int {
        guard let profileId = appState.currentProfileId else { return 0 }
        return notificationRecords.filter { $0.profileId == profileId && $0.readAt == nil }.count
    }

    // MARK: - Health Journey Banner

    private func healthJourneyBanner(profile: PersonProfile) -> some View {
        Button {
            showHealthJourney = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Pulse.ai.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "heart.text.clipboard.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Pulse.ai)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Complete your Health Journey")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Pulse.textPrimary)
                    Text("Personalize nutrition, exercise & supplement safety")
                        .font(.caption2)
                        .foregroundColor(Pulse.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Pulse.ai)
            }
            .pulseSurfaceGlow(color: Pulse.ai, radius: 16, padding: 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Health Summary Entry
    //
    // Single consolidated entry point — was up to 3 separate full-width
    // cards (journey banner, contraindication badge, up to 2 nudge cards)
    // stacked back to back, all routine/informational and all competing for
    // the same visual weight as the flare alert above. Now one card: a
    // header that surfaces the single most urgent thing (top contraindication
    // warning, or a completion prompt), with nudges as compact rows inside
    // the same card instead of their own separate one.
    @ViewBuilder
    private var healthSummaryEntry: some View {
        if let profile = ProfileStore.current(context: modelContext) {
            if !profile.healthJourneyCompleted {
                healthJourneyBanner(profile: profile)
            } else {
                let report = HealthContraindicationEngine.generate(for: profile)
                let topWarning = report.allWarnings.sorted(by: { $0.severity > $1.severity }).first
                let nudges = HealthNudgeEngine.generate(profile: profile, context: modelContext)
                let visibleNudges = Array(nudges.prefix(2))
                let extraCount = nudges.count - visibleNudges.count
                let accentColor: Color = {
                    switch topWarning?.severity {
                    case .critical: return Pulse.critical
                    case .warning:  return Pulse.warning
                    case .caution:  return Pulse.warning
                    default:        return Pulse.ai
                    }
                }()

                if !report.isEmpty || !visibleNudges.isEmpty {
                    VStack(spacing: 0) {
                        Button {
                            showHealthProfileSummary = true
                        } label: {
                            VStack(spacing: 8) {
                                HStack(spacing: 10) {
                                    Image(systemName: "heart.text.clipboard")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(accentColor)
                                        .frame(width: 32, height: 32)
                                        .background(accentColor.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Health")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(Pulse.textPrimary)
                                        Text(topWarning.map { $0.title } ?? "\(report.totalCount) personalized rules active")
                                            .font(.system(size: 10))
                                            .foregroundColor(Pulse.textTertiary)
                                            .lineLimit(2)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Pulse.textTertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        if !visibleNudges.isEmpty {
                            Divider().padding(.vertical, 8)
                            VStack(spacing: 8) {
                                ForEach(visibleNudges) { nudge in
                                    nudgeCard(nudge)
                                }
                                if extraCount > 0 {
                                    Button {
                                        selectedTab = 3 // Health tab
                                    } label: {
                                        HStack {
                                            Text("+\(extraCount) more insight\(extraCount == 1 ? "" : "s")")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(Pulse.ai)
                                            Spacer()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Pulse.surfaceFallback)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(accentColor.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    private func nudgeCard(_ nudge: HealthNudgeEngine.Nudge) -> some View {
        let accentColor = nudgeColor(nudge.priority)

        return HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: nudge.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accentColor)
                .frame(width: 30, height: 30)
                .background(accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(nudge.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Pulse.textPrimary)

                Text(nudge.detail)
                    .font(.system(size: 11.5))
                    .foregroundColor(Pulse.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionLabel = nudge.actionLabel {
                    Button {
                        handleNudgeAction(nudge.action)
                    } label: {
                        Text(actionLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(accentColor)
                    }
                    .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Pulse.surfaceFallback)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(accentColor.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    private func handleNudgeAction(_ action: HealthNudgeEngine.Nudge.Action) {
        switch action {
        case .none:
            break
        case .switchTab(let tab):
            selectedTab = tab
        case .openSheet(let sheet):
            switch sheet {
            case .water:    showWaterSheet = true
            case .food:     showFoodQuickPicker = true
            case .training: selectedTab = 1
            case .checkIn:  showCheckIn = true
            }
        }
    }

    private func nudgeColor(_ priority: HealthNudgeEngine.Nudge.Priority) -> Color {
        switch priority {
        case .urgent: return Pulse.critical
        case .high:   return Pulse.warning
        case .medium: return Pulse.ai
        case .low:    return Pulse.recovery
        }
    }

    private func loadData() {
        let now = Date()
        guard now.timeIntervalSince(lastLoadTime) > 15 else { return }
        lastLoadTime = now

        viewModel.load(context: modelContext)
        todayTrainingDay = TrainingDayStore.today(context: modelContext)
        Task {
            todaysPicture = await PersonalHealthTimelineEngine.build(for: .now, context: modelContext)
            await viewModel.loadAppleHealthData(context: modelContext, profile: appState.profile)
            if appState.flareEngineEnabled,
               appState.profile.preFlareAlertsEnabled,
               let assessment = viewModel.flareAssessment {
                // Forecast-led case: today's assessed level can be .low
                // while the trend is worsening — schedulePreFlareAlert only
                // fires at .elevated+, so without this override the entire
                // point of the forecast (catching risk BEFORE today's score
                // reflects it) would never reach a notification, only
                // whoever happens to open the app.
                let isForecastLed = assessment.level == .low && viewModel.flareForecast?.trajectory == .worsening
                let effectiveLevel = isForecastLed ? .elevated : assessment.level
                let effectiveRecommendation = isForecastLed
                    ? (viewModel.flareForecast?.summary ?? assessment.recommendation)
                    : assessment.recommendation

                await NotificationManager.shared.schedulePreFlareAlert(
                    riskLevel: effectiveLevel,
                    recommendation: effectiveRecommendation,
                    context: modelContext,
                    profile: appState.profile
                )
            }
            // Daily briefing — one synthesized morning notification instead
            // of scattered pings. Guarded first so the narrative synthesis
            // (4 concurrent engines) only actually runs once per day, not
            // on every dashboard load.
            if !NotificationManager.shared.hasScheduledDailyBriefingToday() {
                let wellness = await WellnessCorrelationEngine.analyzeToday(context: modelContext)
                if let narrative = await DailyNarrativeEngine.build(
                    context: modelContext,
                    sexRaw: appState.profile.sexRaw,
                    flareAssessment: viewModel.flareAssessment,
                    flareForecast: viewModel.flareForecast,
                    wellnessInsights: wellness
                ) {
                    await NotificationManager.shared.scheduleDailyBriefing(
                        headline: narrative.headline.text,
                        context: modelContext,
                        profile: appState.profile
                    )
                    NarrativeHistoryStore.record(headline: narrative.headline, context: modelContext)
                }
            }
            if let readiness = viewModel.readiness {
                NotificationManager.shared.scheduleRecoveryPrompt(
                    score: readiness.score,
                    bandLabel: readiness.band.rawValue,
                    drivers: readiness.drivers,
                    context: modelContext,
                    profile: appState.profile
                )
                // Push the phone's baseline-relative score to the watch so
                // it doesn't have to guess from population-average thresholds
                WatchSessionManager.shared.pushReadiness(
                    score: readiness.score,
                    band: readiness.band.rawValue,
                    recommendation: readiness.recommendation
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

            // Training streak: consecutive days with completed sessions ending today or yesterday
            let streakCalendar = Calendar.current
            let streakToday = streakCalendar.startOfDay(for: Date())
            let completed = viewModel.allCompletedSessions
            var streak = 0
            for dayOffset in 0...30 {
                guard let checkDay = streakCalendar.date(byAdding: .day, value: -dayOffset, to: streakToday) else { break }
                if completed.contains(where: { streakCalendar.isDate($0.date, inSameDayAs: checkDay) }) {
                    streak += 1
                } else if dayOffset == 0 {
                    continue
                } else {
                    break
                }
            }
            trainingStreak = streak

            // Week day statuses (Mon–Sun)
            let weekCalendar = Calendar(identifier: .iso8601)
            let todayWeekday = weekCalendar.component(.weekday, from: Date())
            let mondayOffset = (todayWeekday + 5) % 7
            guard let monday = weekCalendar.date(byAdding: .day, value: -mondayOffset, to: streakCalendar.startOfDay(for: Date())) else { return }
            let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
            var statuses: [WeekDayStatus] = []
            for i in 0..<7 {
                guard let day = streakCalendar.date(byAdding: .day, value: i, to: monday) else { continue }
                let dayStart = streakCalendar.startOfDay(for: day)
                let isToday = streakCalendar.isDateInToday(day)
                let isFuture = day > Date()
                let trained = completed.contains(where: { streakCalendar.isDate($0.date, inSameDayAs: dayStart) })
                statuses.append(WeekDayStatus(id: i, label: dayLabels[i], trained: trained, isToday: isToday, isFuture: isFuture && !isToday))
            }
            weekDayStatuses = statuses
        }
    }
}
