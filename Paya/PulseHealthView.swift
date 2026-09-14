import SwiftUI
import SwiftData

// MARK: - Pulse Health View
//
// Design personality: CALM · INTELLIGENT · ANALYTICAL
//
// This is the body intelligence center. Information should feel like
// a trusted advisor explaining your physiology, not a medical chart.
//
// Benchmark: Oura (health radials, progressive disclosure), Apple Health
// (clean data presentation), WHOOP (recovery insights)
//
// Key transformation:
// 1. Hero: Wellness state visualization — radial or organic shape showing
//    overall body state (sleep + pain + recovery merged)
// 2. Health inputs become interactive sliders with visual feedback
// 3. Segmented sections replaced with flowing organic sections
// 4. Apple Health data gets radial orb presentation (like Home vitals)
// 5. Dark canvas with calm recovery/vitals teal-rose palette

private enum PulseHealthSection: String, CaseIterable, Identifiable {
    case today = "Today"
    case insights = "Insights"
    var id: String { rawValue }
}

struct PulseHealthView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var vm = HealthViewModel()
    @State private var notesText: String = ""
    @State private var section: PulseHealthSection = .today
    @State private var showHealthActivities = false
    @State private var showSymptomDiet = false
    @State private var showReadinessDetail = false
    @State private var hasAppeared = false
    @State private var readinessReport: ReadinessEngine.Report? = nil
    @State private var narrative: DailyNarrativeEngine.Narrative? = nil
    @State private var narrativeLoading = true
    @State private var showTrendJournal = false

    // Wellness composite score — integrates biometrics when available.
    //
    // Scoring architecture (matches Oura's readiness logic):
    // - Recovery score (from ReadinessEngine / HRV+HR+sleep composite): 60% weight
    // - Subjective inputs (pain, energy): 20% weight
    // - Sleep hours (NSF 7–9h adult recommendation): 20% weight
    //
    // When no wearable data exists, falls back to manual-only scoring
    // so the ring is never empty for users without an Apple Watch.
    private var wellnessScore: CGFloat {
        // Prefer ReadinessEngine (z-score based) over simple recovery score
        let recovery = readinessReport?.score ?? vm.recoveryScore

        // If recovery score is available (requires wearable), blend it in
        if let recovery {
            var score = CGFloat(recovery) * 0.6  // 60% from biometrics

            // Sleep contribution (20%)
            if let sleep = vm.applHealthSleepHours {
                let sleepScore: CGFloat = switch sleep {
                    case 7...9:  100
                    case 6..<7:  75 + CGFloat(sleep - 6) * 25
                    case 9..<10: 100 - CGFloat(sleep - 9) * 25
                    default:     max(30, 75 - abs(CGFloat(sleep) - 8) * 15)
                }
                score += sleepScore * 0.2
            } else {
                score += 50 * 0.2  // neutral if no sleep data
            }

            // Subjective signals (20%)
            var subjective: CGFloat = 60  // neutral baseline
            if let pain = vm.todaysLog?.jointPainLevel, pain > 0 {
                subjective -= CGFloat(pain) * 6  // pain is a strong negative
            }
            if let energy = vm.todaysLog?.energyLevel {
                subjective += CGFloat(energy - 2) * 10  // energy 1=−10, 2=0, 3=+10
            }
            score += max(0, min(100, subjective)) * 0.2

            return max(0, min(100, score))
        }

        // Manual-only fallback (no wearable)
        var score: CGFloat = 50
        if let sleep = vm.applHealthSleepHours {
            score += min(CGFloat(sleep / 8.0) * 20, 20)
        }
        if let pain = vm.todaysLog?.jointPainLevel {
            score -= CGFloat(pain) * 5
        }
        if let energy = vm.todaysLog?.energyLevel {
            score += CGFloat(energy) * 3
        }
        return max(0, min(100, score))
    }

    /// Whether the score is driven by real biometric data vs manual-only
    private var hasBiometricScore: Bool {
        readinessReport != nil || vm.recoveryScore != nil
    }

    private var wellnessColor: Color {
        if wellnessScore >= 75 { return Pulse.positive }
        if wellnessScore >= 50 { return Pulse.recovery }
        if wellnessScore >= 30 { return Pulse.warning }
        return Pulse.critical
    }

    private var wellnessLabel: String {
        if wellnessScore >= 75 { return "Thriving" }
        if wellnessScore >= 50 { return "Balanced" }
        if wellnessScore >= 30 { return "Taxed" }
        return "Stressed"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                healthBackground

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ━━━ Hero: Wellness State ━━━
                        wellnessHero

                        // ━━━ Flare Day Toggle ━━━
                        if appState.flareEngineEnabled {
                            pulseFlareToggle
                        }

                        // ━━━ Biometrics Strip ━━━
                        biometricsStrip

                        // ━━━ Section Picker ━━━
                        pulseSectionPicker

                        // ━━━ Content ━━━
                        switch section {
                        case .today:
                            todaySection
                        case .insights:
                            insightsSection
                        }

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Health")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.textPrimary)
                }
            }
        }
        .onAppear {
            vm.load(context: modelContext)
            notesText = vm.todaysLog?.notes ?? ""
            Task {
                await vm.loadHealthKitData()
                // Load BiometricStore for proper ReadinessEngine scoring
                // (shares the singleton with dashboard, so no duplicate fetch)
                let store = BiometricStore.shared
                if store.history.isEmpty {
                    await store.loadHistory(daysBack: 30)
                }
                readinessReport = ReadinessEngine.compute(store: store, context: modelContext)
                await loadNarrative(store: store)
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) { hasAppeared = true }
        }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in
            vm.load(context: modelContext)
            Task {
                await vm.loadHealthKitData()
                readinessReport = ReadinessEngine.compute(store: BiometricStore.shared, context: modelContext)
            }
        }
        .sheet(isPresented: $showTrendJournal) { TrendJournalView() }
        .sheet(isPresented: $showHealthActivities) { HealthActivitiesView() }
        .sheet(isPresented: $showSymptomDiet) {
            if let profile = ProfileStore.current(context: modelContext) {
                SymptomDietPlanView(profile: profile)
            }
        }
        .sheet(isPresented: $showReadinessDetail) {
            if let report = readinessReport {
                ReadinessDetailView(report: report)
            }
        }
    }

    // MARK: - Background

    private var healthBackground: some View {
        ZStack {
            Pulse.canvasFallback.ignoresSafeArea()
            // Calm wellness glow
            BreathingOrb(color: wellnessColor, size: 280)
                .offset(y: -220)
                .opacity(0.4)
            Circle()
                .fill(Pulse.vitals.opacity(0.03))
                .frame(width: 300, height: 300)
                .blur(radius: 70)
                .offset(x: 120, y: 300)
        }
    }

    // MARK: - Wellness Hero

    private var wellnessHero: some View {
        VStack(spacing: 14) {
            Button {
                if readinessReport != nil {
                    showReadinessDetail = true
                }
            } label: {
                ZStack {
                    PulseRing(
                        progress: wellnessScore / 100,
                        size: 140,
                        lineWidth: 12,
                        color: wellnessColor
                    )

                    VStack(spacing: 2) {
                        Text("\(Int(wellnessScore))")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(wellnessColor)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text(wellnessLabel)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(wellnessColor.opacity(0.8))
                    }
                }
            }
            .buttonStyle(.plain)

            // Quick context stats
            HStack(spacing: 16) {
                if let sleep = vm.applHealthSleepHours {
                    healthQuickStat(icon: "moon.fill", value: String(format: "%.1fh", sleep), label: "Sleep", color: Pulse.ai)
                }
                if let hrv = vm.applHealthHRV {
                    healthQuickStat(
                        icon: "waveform.path.ecg",
                        value: String(format: "%.0fms", hrv),
                        label: "HRV",
                        color: Pulse.recovery
                    )
                }
                if let hr = vm.applHealthRestingHR {
                    healthQuickStat(icon: "heart.fill", value: "\(hr)bpm", label: "Rest HR", color: Pulse.vitals)
                }
                if let pain = vm.todaysLog?.jointPainLevel, pain > 0 {
                    healthQuickStat(icon: "bandage.fill", value: "\(pain)/10", label: "Pain", color: Pulse.warning)
                }
                if let energy = vm.todaysLog?.energyLevel, energy > 0 {
                    healthQuickStat(icon: "bolt.fill", value: "\(energy)/5", label: "Energy", color: Pulse.energy)
                }
            }

            // Score source context
            if let report = readinessReport {
                VStack(spacing: 4) {
                    Text(report.band.rawValue)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(wellnessColor)
                    Text(report.recommendation)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Pulse.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .lineLimit(2)
                }
            } else if hasBiometricScore {
                if let recoveryVal = vm.recoveryScore {
                    Text("Recovery \(recoveryVal)/100 · HRV + heart rate + sleep")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Pulse.textTertiary)
                }
            } else if !vm.hasWearableData && vm.healthKitAuthorized {
                Text("Based on manual logs only — connect a wearable for biometric-driven scoring")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Pulse.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.92)
    }

    private func healthQuickStat(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Pulse.textPrimary)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Pulse.textTertiary)
            }
        }
    }

    // MARK: - Flare Day Toggle

    private var pulseFlareToggle: some View {
        FlareDayToggle(vm: vm, appState: appState, modelContext: modelContext)
    }

    // MARK: - Biometrics Strip

    private var biometricsStrip: some View {
        VStack(spacing: 12) {
            // Connection status — always visible so the user knows their
            // watch/BLE state at a glance (not just when data is missing)
            watchConnectionBar

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    // Live HR first — highest visual priority when streaming.
                    // Read directly from source @Observable singletons.
                    if let liveBPM = BLEHeartRateManager.shared.currentBPM {
                        MetricOrb(
                            value: "\(liveBPM)",
                            unit: "bpm",
                            label: "♥ Live",
                            color: LiveHRManager.shared.zone(for: liveBPM)?.color ?? Pulse.vitals,
                            // Live HR as fraction of estimated max (220 − age,
                            // Tanaka et al. 2001); capped at 200 bpm fallback
                            progress: min(Double(liveBPM) / 200.0, 1.0),
                            isFresh: true
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
                            isFresh: true
                        )
                    }

                    if let sleep = vm.applHealthSleepHours {
                        MetricOrb(
                            value: String(format: "%.1f", sleep),
                            unit: "hrs",
                            label: "Sleep",
                            color: Pulse.ai,
                            progress: min(sleep / 8.0, 1.0)
                        )
                    }
                    if let hr = vm.applHealthRestingHR {
                        MetricOrb(
                            value: "\(hr)",
                            unit: "bpm",
                            label: "Rest HR",
                            color: Pulse.vitals,
                            // Lower resting HR = better cardiovascular fitness.
                            // Inverted scale: 45 bpm → 1.0, 100 bpm → 0.0
                            // (Reimers et al. 2013, population norms)
                            progress: 1.0 - max(0, min((Double(hr) - 45) / 55, 1.0)),
                            freshness: vm.freshnessLabel(for: vm.restingHRTimestamp),
                            isFresh: vm.isFresh(vm.restingHRTimestamp)
                        )
                    }
                    if let hrv = vm.applHealthHRV {
                        MetricOrb(
                            value: String(format: "%.0f", hrv),
                            unit: "ms",
                            label: "HRV",
                            color: Pulse.recovery,
                            // Higher HRV = better autonomic recovery.
                            // Scaled against 80 ms (Shaffer & Ginsberg 2017,
                            // healthy adult rMSSD median)
                            progress: min(hrv / 80.0, 1.0),
                            freshness: vm.freshnessLabel(for: vm.hrvTimestamp),
                            isFresh: vm.isFresh(vm.hrvTimestamp)
                        )
                    }
                    if let spo2 = vm.applHealthBloodOxygen {
                        MetricOrb(
                            value: String(format: "%.0f", spo2),
                            unit: "%",
                            label: "SpO₂",
                            color: Pulse.hydration,
                            progress: min(spo2 / 100.0, 1.0),
                            freshness: vm.freshnessLabel(for: vm.bloodOxygenTimestamp),
                            isFresh: vm.isFresh(vm.bloodOxygenTimestamp)
                        )
                    }
                    if let steps = vm.applHealthSteps {
                        MetricOrb(
                            value: steps >= 1000 ? String(format: "%.1fk", Double(steps) / 1000) : "\(steps)",
                            unit: "",
                            label: "Steps",
                            color: Pulse.energy,
                            progress: min(Double(steps) / 10000, 1.0)
                        )
                    }
                    if let resp = vm.applHealthRespiratoryRate {
                        MetricOrb(
                            value: String(format: "%.0f", resp),
                            unit: "/min",
                            label: "Resp",
                            color: Pulse.positive,
                            // Normal respiratory rate 12–20 brpm (Barrett et al. 2012)
                            progress: min(resp / 20.0, 1.0),
                            freshness: vm.freshnessLabel(for: vm.respiratoryRateTimestamp),
                            isFresh: vm.isFresh(vm.respiratoryRateTimestamp)
                        )
                    }
                    if let burned = vm.applHealthEnergyBurned {
                        MetricOrb(
                            value: "\(Int(burned))",
                            unit: "kcal",
                            label: "Burned",
                            color: Pulse.energy,
                            // Daily active energy target 500 kcal (ACSM guideline)
                            progress: min(burned / 500.0, 1.0)
                        )
                    }

                    // Placeholder orbs when no wearable data
                    if !vm.hasWearableData {
                        noDataOrb(label: "Rest HR", unit: "bpm", color: Pulse.vitals)
                        noDataOrb(label: "HRV", unit: "ms", color: Pulse.recovery)
                        noDataOrb(label: "SpO₂", unit: "%", color: Pulse.hydration)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Watch Connection Bar

    /// Always-visible connection indicator — shows watch pairing state,
    /// live HR source, and BLE monitor status so the user always knows
    /// whether real-time data is flowing. Whoop-style: connection state
    /// is never hidden behind "no data" conditionals.
    @ViewBuilder
    private var watchConnectionBar: some View {
        // Read directly from each @Observable singleton — computed properties
        // on LiveHRManager that delegate to BLEHeartRateManager won't trigger
        // SwiftUI updates because @Observable only tracks stored properties.
        let watch = WatchSessionManager.shared
        let ble = BLEHeartRateManager.shared
        let hasBLE = ble.currentBPM != nil
        let watchHR = watch.watchHeartRate
        let watchHRTs = watch.watchHeartRateTimestamp
        let hasWatchHR = watchHR != nil && watchHRTs != nil && Date().timeIntervalSince(watchHRTs!) < 30
        let isLive = hasBLE || hasWatchHR
        let sourceLabel = hasBLE ? "BLE" : (hasWatchHR ? "Watch" : "—")

        let statusColor = isLive ? Pulse.positive : (watch.isWatchReachable ? Pulse.hydration : (watch.isConnected ? Pulse.warning : Pulse.textTertiary))

        HStack(spacing: 10) {
            // Status dot — green=streaming, teal=connected, amber=paired, grey=none
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Image(systemName: isLive ? "waveform.path.ecg" : (watch.isConnected ? "applewatch" : "applewatch.slash"))
                .font(.system(size: 13))
                .foregroundColor(isLive ? Pulse.positive : (watch.isConnected ? Pulse.hydration : Pulse.warning))

            VStack(alignment: .leading, spacing: 1) {
                if isLive {
                    Text("Live HR · \(sourceLabel)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Pulse.positive)
                } else {
                    Text(watch.hasActivated ? watch.connectionLabel : "Checking…")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Pulse.textPrimary)
                }

                if !watch.isConnected && !isLive {
                    Text("Connect Apple Watch or BLE HR monitor for real-time data")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Pulse.textTertiary)
                } else if watch.isConnected && !watch.isWatchReachable && !isLive {
                    Text("Paired · not on wrist — wear your watch for live readings")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Pulse.textTertiary)
                }
            }

            Spacer(minLength: 0)

            // Live HR pill when streaming
            if isLive {
                LiveHRPill()
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: Pulse.Radius.sm)
                .fill(statusColor.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: Pulse.Radius.sm)
                        .stroke(statusColor.opacity(0.12), lineWidth: 0.5)
                )
        )
    }

    /// Placeholder orb showing "—" for metrics that require a wearable
    private func noDataOrb(label: String, unit: String, color: Color) -> some View {
        MetricOrb(
            value: "—",
            unit: unit,
            label: label,
            color: color.opacity(0.4),
            freshness: "no data",
            isFresh: false
        )
    }

    // MARK: - Section Picker

    private var pulseSectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(PulseHealthSection.allCases) { s in
                Button {
                    withAnimation(Pulse.Motion.standard) { section = s }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Text(s.rawValue)
                        .font(.system(size: 13, weight: section == s ? .bold : .medium))
                        .foregroundColor(section == s ? Pulse.recovery : Pulse.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(section == s ? Pulse.recovery.opacity(0.1) : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(3)
        .background(Pulse.surfaceFallback)
        .clipShape(Capsule())
    }

    // MARK: - Today Section

    @ViewBuilder
    private var todaySection: some View {
        // Quick-access: AI diet plan — surfaced here so it's not buried in Insights
        if let profile = ProfileStore.current(context: modelContext),
           profile.healthJourneyCompleted {
            Button { showSymptomDiet = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Pulse.nutrition)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your diet plan")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Pulse.textPrimary)
                        Text("Personalized nutrition based on your health profile")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Pulse.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Pulse.textTertiary)
                }
                .padding(12)
                .background(Pulse.nutrition.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Pulse.nutrition.opacity(0.12), lineWidth: 0.5)
                )
            }
            .buttonStyle(PulsePress())
        }

        // Primary inputs
        JointPainCard(vm: vm, appState: appState, modelContext: modelContext)
        SleepTrackerCard(vm: vm, appState: appState, modelContext: modelContext)

        // Cycle-aware adaptation — menstrual phase × training/nutrition
        // (McNulty 2020, Oosthuyse 2010, Hewett 2007, Barr 1995)
        CycleAwareCard(sexRaw: appState.profile.sexRaw)

        // Sleep debt — accumulated deficit with decay model
        // (Van Dongen 2003), grounded in NSF 7-9h recommendation
        SleepDebtCard()

        // Allostatic load — composite stress accumulation from wearable signals
        // (McEwen & Stellar 1993, Johns Hopkins 2025, Davy et al. 2024)
        AllostasisCard()

        // Health tracking — grouped
        PulseCollapsible(title: "Health tracking", icon: "list.clipboard.fill", color: Pulse.hydration) {
            BathroomTrackingCard()
            SymptomLogCard()
            MedicationsCard()
            BloodPressureCard()
            OutdoorTimeCard()
            HealthActivitiesCard(onOpen: { showHealthActivities = true })
        }

        // Risk & observations
        PulseCollapsible(title: "Risk & observations", icon: "exclamationmark.shield.fill", color: Pulse.warning) {
            FlareRiskFactorsCard()
            SorenessCorrelationCard()
                .requiresPro()
            NotesCard(vm: vm, notesText: $notesText, modelContext: modelContext)
        }
    }

    // MARK: - Narrative Loading

    /// Synthesizes the signal engines already used individually below into
    /// one ranked narrative — see DailyNarrativeEngine. Runs after the
    /// screen's own biometric load so BiometricStore is already warm (no
    /// duplicate HealthKit fetch), and after readinessReport is set so this
    /// doesn't race it for the same store.
    private func loadNarrative(store: BiometricStore) async {
        let pid = ActiveProfile.id
        let hDescriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let healthLogs = (try? modelContext.fetch(hDescriptor)) ?? []
        let chronicWindowStart = Calendar.current.date(byAdding: .day, value: -28, to: .now) ?? .now
        let sessionDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid && $0.date >= chronicWindowStart }
        )
        let recentSessions = (try? modelContext.fetch(sessionDescriptor)) ?? []
        let medications = (try? modelContext.fetch(FetchDescriptor<Medication>(
            predicate: #Predicate<Medication> { $0.profileId == pid }
        ))) ?? []
        let doseLogs = (try? modelContext.fetch(FetchDescriptor<MedicationDoseLog>(
            predicate: #Predicate<MedicationDoseLog> { $0.profileId == pid }
        ))) ?? []
        let assessment = appState.flareEngineEnabled
            ? FlareDetectionEngine.shared.assess(biometrics: store, healthLogs: healthLogs, recentSessions: recentSessions, medications: medications, medicationDoseLogs: doseLogs)
            : nil
        let forecast = assessment.flatMap { FlareForecastEngine.forecast(biometrics: store, todayAssessment: $0) }
        let wellness = await WellnessCorrelationEngine.analyzeToday(context: modelContext)

        narrative = await DailyNarrativeEngine.build(
            context: modelContext,
            sexRaw: appState.profile.sexRaw,
            flareAssessment: assessment,
            flareForecast: forecast,
            wellnessInsights: wellness
        )
        narrativeLoading = false
    }

    // MARK: - Insights Section

    @ViewBuilder
    private var insightsSection: some View {
        // Synthesis layer — the one thing worth reading first, drawn from
        // every signal engine below instead of scrolling through each
        // separately. See DailyNarrativeEngine.
        // Proactive, not buried in Settings — surfaces only when the data
        // itself suggests it's worth having ready for an appointment.
        CareTeamPromptCard()

        NarrativeCard(narrative: narrative, isLoading: narrativeLoading)

        Button { showTrendJournal = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "book.pages")
                    .font(.caption)
                Text("View trend journal")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(Pulse.ai)
            .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)

        // Closed-loop tracking — did what you tried actually work.
        ExperimentsCard()

        // AI diet plan — symptom-driven anti-inflammatory guidance
        if let profile = ProfileStore.current(context: modelContext) {
            SymptomDietCard(profile: profile, onOpen: { showSymptomDiet = true })
        }

        // CGM glucose response — post-meal curves, food rankings,
        // pre-workout glucose × performance (Zeevi 2015, Battelino 2019,
        // Cockcroft 2020, Monnier 2003, Danne 2017)
        GlucoseInsightsCard()

        // Chrononutrition — meal timing × sleep/HRV correlations
        // (Crispim 2011, St-Onge 2016, Iao 2021, Wirth 2020)
        ChronoNutritionCard()

        // Digestive patterns — food → gut outcome lag mapping
        // (Koloski 2019, Böhn 2013, Lewis & Heaton 1997)
        DigestivePatternCard()

        AppleHealthCard(vm: vm)
        SleepStagesCard()
        MindfulMinutesCard()
        WeeklyHealthGoalsCard(modelContext: modelContext)
        SupplementAdviceCard(vm: vm, apiKey: appState.anthropicAPIKey, condition: ProfileStore.current(context: modelContext)?.chronicCondition ?? .rheumatoidArthritis)
            .requiresPro()
    }
}

// MARK: - Pulse Collapsible (dark-themed)

struct PulseCollapsible<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(Pulse.Motion.standard) { isExpanded.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundColor(color)
                        .frame(width: 28, height: 28)
                        .background(color.opacity(0.12))
                        .clipShape(Circle())

                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Pulse.textPrimary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Pulse.textTertiary)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(PulsePress(scale: 0.99))

            if isExpanded {
                VStack(spacing: 12) {
                    content()
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity
                ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Pulse.Radius.lg)
                .fill(Pulse.surfaceFallback)
                .overlay(
                    RoundedRectangle(cornerRadius: Pulse.Radius.lg)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
}
