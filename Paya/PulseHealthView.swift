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
    @State private var hasAppeared = false

    // Wellness "score" — simple composite for hero visualization
    private var wellnessScore: CGFloat {
        var score: CGFloat = 50 // baseline
        // Sleep contribution
        if let sleep = vm.applHealthSleepHours {
            score += min(CGFloat(sleep / 8.0) * 20, 20) // up to +20
        }
        // Pain negative
        if let pain = vm.todaysLog?.jointPainLevel {
            score -= CGFloat(pain) * 5 // -0 to -50
        }
        // Energy positive
        if let energy = vm.todaysLog?.energyLevel {
            score += CGFloat(energy) * 3 // up to +15
        }
        return max(0, min(100, score))
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
            .preferredColorScheme(.dark)
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
            Task { await vm.loadHealthKitData() }
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) { hasAppeared = true }
        }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in
            vm.load(context: modelContext)
            Task { await vm.loadHealthKitData() }
        }
        .sheet(isPresented: $showHealthActivities) { HealthActivitiesView() }
        .sheet(isPresented: $showSymptomDiet) {
            if let profile = ProfileStore.current(context: modelContext) {
                SymptomDietPlanView(profile: profile)
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
            ZStack {
                PulseRing(
                    progress: wellnessScore / 100,
                    size: 140,
                    lineWidth: 12,
                    color: wellnessColor
                )

                VStack(spacing: 4) {
                    Text(wellnessLabel)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(wellnessColor)
                    Text("Body state")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Pulse.textTertiary)
                }
            }

            // Quick context
            if let sleep = vm.applHealthSleepHours {
                HStack(spacing: 16) {
                    healthQuickStat(icon: "moon.fill", value: String(format: "%.1fh", sleep), label: "Sleep", color: Pulse.ai)
                    if let pain = vm.todaysLog?.jointPainLevel, pain > 0 {
                        healthQuickStat(icon: "bandage.fill", value: "\(pain)/10", label: "Pain", color: Pulse.warning)
                    }
                    if let energy = vm.todaysLog?.energyLevel, energy > 0 {
                        healthQuickStat(icon: "bolt.fill", value: "\(energy)/5", label: "Energy", color: Pulse.energy)
                    }
                }
            }

            // No-wearable context for wellness score
            if !vm.hasWearableData && vm.healthKitAuthorized {
                Text("Based on manual logs only — connect a wearable for biometric-driven wellness scoring")
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
            // No-wearable notice when no biometric data detected
            if !vm.hasWearableData && vm.healthKitAuthorized {
                noWearableNotice
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
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
                            color: Pulse.vitals
                        )
                    }
                    if let hrv = vm.applHealthHRV {
                        MetricOrb(
                            value: String(format: "%.0f", hrv),
                            unit: "ms",
                            label: "HRV",
                            color: Pulse.recovery
                        )
                    }
                    if let spo2 = vm.applHealthBloodOxygen {
                        MetricOrb(
                            value: String(format: "%.0f", spo2),
                            unit: "%",
                            label: "SpO₂",
                            color: Pulse.hydration,
                            progress: min(spo2 / 100.0, 1.0)
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
                            color: Pulse.positive
                        )
                    }
                    if let burned = vm.applHealthEnergyBurned {
                        MetricOrb(
                            value: "\(Int(burned))",
                            unit: "kcal",
                            label: "Burned",
                            color: Pulse.energy
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

    // MARK: - No Wearable Notice

    private var noWearableNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "applewatch.slash")
                .font(.system(size: 14))
                .foregroundColor(Pulse.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("No wearable detected")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Pulse.textPrimary)
                Text("Connect an Apple Watch or any wearable via Apple Health to unlock heart rate, HRV, SpO₂, and readiness tracking.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Pulse.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Pulse.Radius.sm)
                .fill(Pulse.warning.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: Pulse.Radius.sm)
                        .stroke(Pulse.warning.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    /// Placeholder orb showing "—" for metrics that require a wearable
    private func noDataOrb(label: String, unit: String, color: Color) -> some View {
        MetricOrb(
            value: "—",
            unit: unit,
            label: label,
            color: color.opacity(0.4)
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
        // Primary inputs
        JointPainCard(vm: vm, appState: appState, modelContext: modelContext)
        SleepTrackerCard(vm: vm, appState: appState, modelContext: modelContext)

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

    // MARK: - Insights Section

    @ViewBuilder
    private var insightsSection: some View {
        // AI diet plan — symptom-driven anti-inflammatory guidance
        if let profile = ProfileStore.current(context: modelContext) {
            SymptomDietCard(profile: profile, onOpen: { showSymptomDiet = true })
        }

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
