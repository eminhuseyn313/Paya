import SwiftUI
import SwiftData

// Same "wall of cards" fix applied to Progress/Nutrition — 8 uniform cards
// in one scroll split into today's inputs vs. Apple Health / AI insights.
private enum HealthSection: String, CaseIterable, Identifiable {
    case today = "Today's Log"
    case insights = "Insights"
    var id: String { rawValue }
}

struct HealthView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var vm = HealthViewModel()
    @State private var notesText: String = ""
    @State private var section: HealthSection = .today
    @State private var showHealthActivities = false

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            ScrollView {
                VStack(spacing: 14) {

                    // Flare day toggle — frequently checked/toggled, stays
                    // visible above the section picker.
                    FlareDayToggle(vm: vm, appState: appState, modelContext: modelContext)

                    Picker("Section", selection: $section) {
                        ForEach(HealthSection.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)

                    switch section {
                    case .today:
                        SymptomLogCard()
                        HealthActivitiesCard(onOpen: { showHealthActivities = true })
                        MedicationsCard()
                        BloodPressureCard()
                        OutdoorTimeCard()
                        FlareRiskFactorsCard()
                        SorenessCorrelationCard()
                            .requiresPro()
                        JointPainCard(vm: vm, appState: appState, modelContext: modelContext)
                        SleepTrackerCard(vm: vm, appState: appState, modelContext: modelContext)
                        NotesCard(vm: vm, notesText: $notesText, modelContext: modelContext)

                    case .insights:
                        AppleHealthCard(vm: vm)
                        SleepStagesCard()
                        MindfulMinutesCard()
                        WeeklyHealthGoalsCard(modelContext: modelContext)
                        SupplementAdviceCard(vm: vm, apiKey: appState.anthropicAPIKey, condition: ProfileStore.current(context: modelContext)?.chronicCondition ?? .rheumatoidArthritis)
                            .requiresPro()
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .frame(width: geo.size.width)
            }
            }
            .navigationTitle("Health")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            vm.load(context: modelContext)
            notesText = vm.todaysLog?.notes ?? ""
            Task {
                await vm.loadHealthKitData()
            }
        }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in
            vm.load(context: modelContext)
            Task { await vm.loadHealthKitData() }
        }
        .sheet(isPresented: $showHealthActivities) {
            HealthActivitiesView()
        }
    }
}

// MARK: - Apple Health Card

struct AppleHealthCard: View {
    var vm: HealthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Apple Health")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if vm.healthKitAuthorized {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "059669"))
                        .font(.caption)
                }
            }

            if !vm.healthKitAuthorized {
                Text("Enable Apple Health to see your sleep, HR, HRV, and steps here.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 10)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    HealthMetricCard(
                        icon: "moon.fill",
                        label: "Sleep",
                        value: vm.applHealthSleepHours.map { String(format: "%.1fh", $0) } ?? "—",
                        color: Color(hex: "8B5CF6")
                    )
                    HealthMetricCard(
                        icon: "heart.fill",
                        label: "Resting HR",
                        value: vm.applHealthRestingHR.map { "\($0)" } ?? "—",
                        color: Color(hex: "DC2626")
                    )
                    HealthMetricCard(
                        icon: "waveform.path.ecg",
                        label: "HRV",
                        value: vm.applHealthHRV.map { String(format: "%.0f ms", $0) } ?? "—",
                        color: Color(hex: "2563EB")
                    )
                    HealthMetricCard(
                        icon: "figure.walk",
                        label: "Steps",
                        value: vm.applHealthSteps.map { "\($0)" } ?? "—",
                        color: Color(hex: "059669")
                    )
                    HealthMetricCard(
                        icon: "speaker.wave.2.fill",
                        label: "Avg Noise",
                        value: vm.applHealthAvgNoiseDb.map { "\(Int($0))dB" } ?? "—",
                        color: (vm.applHealthAvgNoiseDb ?? 0) >= 70 ? Color(hex: "DC2626") : Color(hex: "6B7280")
                    )
                }
            }
        }
        .payaCard(padding: 14)
    }
}

struct HealthMetricCard: View {
    var icon: String
    var label: String
    var value: String
    var color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline.weight(.bold))
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Flare Day

struct FlareDayToggle: View {
    var vm: HealthViewModel
    var appState: AppState
    var modelContext: ModelContext

    var body: some View {
        Button {
            let newVal = !(vm.todaysLog?.isFlareDay ?? false)
            vm.updateFlareDay(newVal, context: modelContext, appState: appState)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: appState.isFlareDay
                      ? "exclamationmark.triangle.fill"
                      : "checkmark.shield.fill")
                    .font(.title3)
                    .foregroundColor(appState.isFlareDay
                        ? Color(hex: "B45309")
                        : Color(hex: "059669"))
                VStack(alignment: .leading, spacing: 2) {
                    Text(appState.isFlareDay ? "Flare day" : "No flare")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(appState.isFlareDay
                         ? "Weights reduced 25% · Tap to clear"
                         : "Tap if you feel a flare coming on")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(appState.isFlareDay
                ? Color(hex: "B45309").opacity(0.1)
                : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

// MARK: - Joint Pain

struct JointPainCard: View {
    var vm: HealthViewModel
    var appState: AppState
    var modelContext: ModelContext

    @State private var painLevel: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Joint pain")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(painLevel))/10")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(painColor)
            }
            Slider(value: $painLevel, in: 0...10, step: 1) { editing in
                if !editing {
                    vm.updatePainLevel(Int(painLevel), context: modelContext, appState: appState)
                }
            }
            .tint(painColor)
            if painLevel >= 4 {
                Text("Factored into today's flare risk — check Home for the updated assessment.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .payaCard(padding: 14)
        .onAppear {
            painLevel = Double(vm.todaysLog?.jointPainLevel ?? 0)
        }
    }

    var painColor: Color {
        switch painLevel {
        case 0...3:  return Color(hex: "059669")
        case 4...6:  return Color(hex: "B45309")
        default:     return Color(hex: "DC2626")
        }
    }
}

// MARK: - Sleep

struct SleepTrackerCard: View {
    var vm: HealthViewModel
    var appState: AppState
    var modelContext: ModelContext

    @State private var sleepHours: Double = 7.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundColor(Color(hex: "8B5CF6"))
                Text("Sleep last night")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: "%.1fh", sleepHours))
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Color(hex: "8B5CF6"))
            }
            Slider(value: $sleepHours, in: 3...10, step: 0.5) { editing in
                if !editing {
                    vm.updateSleepHours(sleepHours, context: modelContext, appState: appState)
                }
            }
            .tint(Color(hex: "8B5CF6"))
        }
        .payaCard(padding: 14)
        .onAppear {
            sleepHours = vm.applHealthSleepHours ?? vm.todaysLog?.sleepHours ?? 7.0
        }
    }
}

// MARK: - Water Intake
// Syncs with the watch app — logging from either side updates both.

struct WaterIntakeCard: View {
    var modelContext: ModelContext

    @State private var waterMl: Int = 0
    @State private var caffeineMg: Double = 0
    @State private var selectedDrink: DrinkType = .water

    private var progress: Double {
        min(1.0, Double(waterMl) / Double(WaterStore.dailyTargetMl))
    }
    private var liters: String {
        String(format: "%.1fL", Double(waterMl) / 1000.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(Color(hex: "0891B2"))
                Text("Liquid")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(liters) / \(String(format: "%.1fL", Double(WaterStore.dailyTargetMl) / 1000.0))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "0891B2").opacity(0.15))
                    Capsule()
                        .fill(Color(hex: "0891B2"))
                        .frame(width: geo.size.width * progress)
                        .animation(.spring(response: 0.4), value: progress)
                }
            }
            .frame(height: 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DrinkType.allCases) { type in
                        Button {
                            withAnimation(.spring(response: 0.25)) { selectedDrink = type }
                        } label: {
                            VStack(spacing: 3) {
                                ZStack {
                                    Circle()
                                        .fill(selectedDrink == type
                                              ? Color(hex: type.colorHex).opacity(0.18)
                                              : Color(.tertiarySystemBackground))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: type.icon)
                                        .font(.system(size: 12))
                                        .foregroundColor(selectedDrink == type ? Color(hex: type.colorHex) : .secondary)
                                }
                                Text(type.displayName)
                                    .font(.system(size: 8, weight: selectedDrink == type ? .bold : .medium))
                                    .foregroundColor(selectedDrink == type ? .primary : .secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 48)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Component preview
            if !selectedDrink.components.isEmpty {
                HStack(spacing: 8) {
                    ForEach(selectedDrink.components, id: \.label) { comp in
                        HStack(spacing: 3) {
                            Image(systemName: comp.icon)
                                .font(.system(size: 8))
                                .foregroundColor(Color(hex: comp.hex))
                            Text("\(comp.value)")
                                .font(.system(size: 9, weight: .semibold))
                        }
                    }
                    Spacer()
                    Text("per 250ml")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 8) {
                let amounts = selectedDrink == .espresso ? [30, 60, 90] : [100, 250, 500]
                let btnColor = Color(hex: selectedDrink.colorHex)
                ForEach(amounts, id: \.self) { amount in
                    Button {
                        add(amount)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.caption2)
                            Text("\(amount)ml")
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(btnColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(btnColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            if caffeineMg >= 50 {
                Text("~\(Int(caffeineMg))mg caffeine today from logged coffee/tea — worth noting if sleep or HRV looks off tonight.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .payaCard(padding: 14)
        .onAppear {
            waterMl = WaterStore.todayTotal(context: modelContext)
            caffeineMg = WaterStore.todayCaffeineMg(context: modelContext)
        }
    }

    private func add(_ ml: Int) {
        waterMl = WaterStore.addWater(ml, drinkType: selectedDrink, context: modelContext)
        caffeineMg = WaterStore.todayCaffeineMg(context: modelContext)
        WatchSessionManager.shared.pushWaterTotal(waterMl)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Energy

struct EnergyLevelCard: View {
    var vm: HealthViewModel
    var appState: AppState
    var modelContext: ModelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Energy level")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                ForEach(1...3, id: \.self) { level in
                    Button {
                        vm.updateEnergyLevel(level, context: modelContext, appState: appState)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(appState.energyLabel(level))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(vm.todaysLog?.energyLevel == level
                                ? appState.energyColor(level)
                                : Color(.tertiarySystemBackground))
                            .foregroundColor(vm.todaysLog?.energyLevel == level
                                ? .white
                                : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Notes

struct NotesCard: View {
    var vm: HealthViewModel
    @Binding var notesText: String
    var modelContext: ModelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.subheadline.weight(.semibold))
            TextField("Symptoms, thoughts, observations", text: $notesText, axis: .vertical)
                .lineLimit(3...6)
                .padding(10)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onChange(of: notesText) { _, val in
                    vm.updateNotes(val, context: modelContext)
                }
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Supplement AI Advice

struct SupplementAdviceCard: View {
    var vm: HealthViewModel
    var apiKey: String
    var condition: ChronicCondition

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: AIService.shared.providerIcon)
                    .foregroundColor(Color(hex: "8B5CF6"))
                Text("Health advice")
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
            if let advice = vm.supplementAdvice {
                Text(advice)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Get AI advice based on today's pain, sleep, and energy.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Button {
                Task {
                    await vm.fetchSupplementAdvice(apiKey: apiKey, condition: condition)
                }
            } label: {
                HStack {
                    if vm.isFetchingAI {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                        Text(vm.supplementAdvice == nil ? "Get advice" : "New advice")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(hex: "8B5CF6"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(vm.isFetchingAI)

            Text("Not medical advice. Consult your doctor.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .payaCard(padding: 14)
    }
}
