import SwiftUI
import SwiftData

// MARK: - Pulse Nutrition View
//
// Design personality: FLUID · VISUAL · APPROACHABLE
//
// Food is emotional, daily, repetitive. This screen must make logging feel
// effortless and satisfying — not like data entry.
//
// Benchmark: MyFitnessPal (efficiency), Cal AI (visual logging),
// modern wellness apps (organic shapes, daily flow)
//
// Key transformation:
// 1. Hero macro rings become large, animated, atmospheric
// 2. Food input becomes a prominent "magic bar" — voice/photo/scan
// 3. Segmented sections replaced with organic flowing sections
// 4. Calorie balance becomes a visual wave, not a table
// 5. Meals logged today become a visual timeline, not a card list
// 6. Dark atmospheric canvas with nutrition-warm amber glow

private enum PulseNutritionSection: String, CaseIterable, Identifiable {
    case today = "Today"
    case templates = "Templates"
    case insights = "Insights"
    var id: String { rawValue }
}

struct PulseNutritionView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var vm = NutritionViewModel()
    @State private var showManualLogSheet = false
    @State private var showAzeQuickAdd = false
    @State private var showLabelScanner = false
    @State private var scannedLabel: ParsedNutritionLabel? = nil
    @State private var showLifestylePlan = false
    @State private var showSymptomDiet = false
    @State private var lifestyleProfile: PersonProfile? = nil
    @State private var showDescribeFood = false
    @State private var showPhotoEstimate = false
    @State private var showDrinkManagement = false
    @State private var section: PulseNutritionSection = .today
    @State private var hasAppeared = false

    private var proteinProgress: CGFloat {
        guard let log = vm.todaysLog else { return 0 }
        let target = log.proteinTarget > 0 ? log.proteinTarget : appState.profile.proteinTargetG
        return target > 0 ? CGFloat(log.totalProtein / target) : 0
    }

    private var calorieProgress: CGFloat {
        guard let log = vm.todaysLog else { return 0 }
        return log.calorieTarget > 0 ? CGFloat(log.totalCalories / log.calorieTarget) : 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                nutritionBackground

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // ━━━ Hero: Macro Rings ━━━
                        heroMacros

                        // ━━━ Magic Input Bar ━━━
                        magicInputBar

                        // ━━━ Section Picker ━━━
                        pulseSectionPicker

                        // ━━━ Section Content ━━━
                        switch section {
                        case .today:
                            todaySection
                        case .templates:
                            templatesSection
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
                    Text("Nutrition")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.textPrimary)
                }
            }
        }
        .onAppear {
            vm.appStateRef = appState
            vm.load(context: modelContext, profile: appState.profile)
            vm.checkAdaptiveCalories(appState: appState, context: modelContext)
            Task { await vm.loadTDEE(context: modelContext, profile: appState.profile) }
            Task { await vm.checkRecoveryNudge() }
            lifestyleProfile = ProfileStore.current(context: modelContext)
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) { hasAppeared = true }
        }
        .sheet(isPresented: $showLifestylePlan) {
            if let profile = lifestyleProfile { LifestylePlanView(profile: profile) }
        }
        .sheet(isPresented: $showSymptomDiet) {
            if let profile = lifestyleProfile { SymptomDietPlanView(profile: profile) }
        }
        .sheet(isPresented: $showDescribeFood) { DescribeFoodView(vm: vm) }
        .sheet(isPresented: $showDrinkManagement) { DrinkManagementView() }
        .fullScreenCover(isPresented: $showPhotoEstimate) { FoodPhotoEstimateView(vm: vm) }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in
            vm.load(context: modelContext, profile: appState.profile)
            Task { await vm.loadTDEE(context: modelContext, profile: appState.profile) }
        }
        .onChange(of: vm.mealVersion) { _, _ in appState.dataRefreshTrigger = UUID() }
        .sheet(isPresented: $vm.showBarcodeScanner) {
            BarcodeScannerView(
                onCodeScanned: { code in Task { await vm.handleScannedCode(code, context: modelContext) } },
                onCancel: { vm.showBarcodeScanner = false }
            )
        }
        .sheet(isPresented: $vm.showScannedProductSheet) {
            if let product = vm.scannedProduct {
                ProductDetailSheet(product: product) { name, protein, calories in
                    vm.addMeal(name: name, food: name, protein: protein, calories: calories, context: modelContext)
                }
            }
        }
        .sheet(isPresented: $vm.showSearchSheet) { FoodSearchSheet(vm: vm) }
        .sheet(isPresented: $vm.showServingSizeSheet) {
            if let product = vm.selectedProduct { ServingSizeSheet(vm: vm, product: product) }
        }
        .sheet(isPresented: $showManualLogSheet) { ManualLogSheet(vm: vm) }
        .sheet(isPresented: $showAzeQuickAdd) {
            AzeQuickAddView { name, protein, calories in
                vm.addMeal(name: name, food: name, protein: protein, calories: calories, context: modelContext)
            }
        }
        .fullScreenCover(isPresented: $showLabelScanner) {
            NutritionLabelScannerView { parsed in
                scannedLabel = parsed
            }
        }
        .sheet(item: $scannedLabel) { label in
            LabelScanConfirmSheet(label: label) { name, protein, calories in
                vm.addMeal(name: name, food: name, protein: protein, calories: calories, context: modelContext)
            }
        }
    }

    // MARK: - Background

    private var nutritionBackground: some View {
        ZStack {
            Pulse.canvasFallback.ignoresSafeArea()
            Circle()
                .fill(Pulse.nutrition.opacity(0.04))
                .frame(width: 350, height: 350)
                .blur(radius: 80)
                .offset(x: 80, y: -150)
            Circle()
                .fill(Pulse.hydration.opacity(0.03))
                .frame(width: 300, height: 300)
                .blur(radius: 70)
                .offset(x: -120, y: 250)
        }
    }

    // MARK: - Hero Macros

    private var heroMacros: some View {
        let protein = vm.todaysLog?.totalProtein ?? 0
        let proteinTarget = vm.todaysLog?.proteinTarget ?? appState.profile.proteinTargetG
        let calories = vm.todaysLog?.totalCalories ?? 0
        let calorieTarget = vm.todaysLog?.calorieTarget ?? 2200

        return HStack(spacing: 24) {
            // Protein ring
            VStack(spacing: 8) {
                ZStack {
                    PulseRing(
                        progress: proteinTarget > 0 ? CGFloat(protein / proteinTarget) : 0,
                        size: 110,
                        lineWidth: 10,
                        color: Pulse.nutrition,
                        showGlow: true
                    )
                    VStack(spacing: 2) {
                        Text("\(Int(protein))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Pulse.textPrimary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(Pulse.Motion.standard, value: Int(protein))
                        Text("/ \(Int(proteinTarget))g")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Pulse.textTertiary)
                    }
                }
                Text("Protein")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Pulse.nutrition)
            }

            // Calories ring
            VStack(spacing: 8) {
                ZStack {
                    PulseRing(
                        progress: calorieTarget > 0 ? CGFloat(calories / calorieTarget) : 0,
                        size: 110,
                        lineWidth: 10,
                        color: Pulse.energy,
                        showGlow: true
                    )
                    VStack(spacing: 2) {
                        Text("\(Int(calories))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Pulse.textPrimary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(Pulse.Motion.standard, value: Int(calories))
                        Text("/ \(Int(calorieTarget))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Pulse.textTertiary)
                    }
                }
                Text("Calories")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Pulse.energy)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.92)

    }

    // MARK: - Magic Input Bar

    private var magicInputBar: some View {
        VStack(spacing: 12) {
            // Primary: Voice log
            Button { showDescribeFood = true } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Pulse.ai.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Pulse.ai)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Voice log")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(Pulse.textPrimary)
                        Text("\"I had two eggs and toast\" — we estimate the rest")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Pulse.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Pulse.textTertiary)
                }
                .pulseSurfaceGlow(color: Pulse.ai, padding: 14)
            }
            .buttonStyle(PulsePress())

            // Secondary: Quick action chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    PulseChip(icon: "camera.fill", label: "Photo", color: Pulse.nutrition) { showPhotoEstimate = true }
                    PulseChip(icon: "barcode.viewfinder", label: "Scan", color: Pulse.energy) { vm.showBarcodeScanner = true }
                    PulseChip(icon: "doc.text.viewfinder", label: "Label", color: Pulse.recovery) { showLabelScanner = true }
                    PulseChip(icon: "magnifyingglass", label: "Search", color: Pulse.hydration) { vm.showSearchSheet = true }
                    PulseChip(icon: "plus", label: "Manual", color: Pulse.textSecondary) { showManualLogSheet = true }
                }
            }
        }
    }

    // MARK: - Section Picker

    private var pulseSectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(PulseNutritionSection.allCases) { s in
                Button {
                    withAnimation(Pulse.Motion.standard) { section = s }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Text(s.rawValue)
                        .font(.system(size: 13, weight: section == s ? .bold : .medium))
                        .foregroundColor(section == s ? Pulse.nutrition : Pulse.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(section == s ? Pulse.nutrition.opacity(0.1) : Color.clear)
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
        // Loading indicator
        if vm.isLookingUpBarcode {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(Pulse.nutrition)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Looking up product…")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Pulse.textPrimary)
                    Text("Scanning database")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Pulse.textTertiary)
                }
                Spacer()
            }
            .pulseSurfaceGlow(color: Pulse.nutrition, padding: 14)
        }

        if let error = vm.lookupError {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Pulse.warning)
                Text(error)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Pulse.warning)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
                .background(Pulse.warning.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: Pulse.Radius.sm))
        }

        // Quick saved meals
        QuickSavedMealTemplatesCard(onMealLogged: { vm.load(context: modelContext) })

        // Calorie deficit
        CalorieDeficitCard()

        // Drinks
        DrinkQuickCard(modelContext: modelContext, onOpenFull: { showDrinkManagement = true })

        // Supplements — surfaced here so users don't need to navigate to Templates
        NutritionSupplementsCard()

        // Logged meals
        if !vm.meals.isEmpty {
            LoggedMealsCard(vm: vm, modelContext: modelContext)
        }

        // Nutrient dashboard
        NutrientDashboardCard()

        // Recent meals
        if !vm.recentMeals.isEmpty {
            RecentMealsCard(vm: vm, modelContext: modelContext)
        }
    }

    // MARK: - Templates Section

    @ViewBuilder
    private var templatesSection: some View {
        if !vm.customTemplates.isEmpty {
            CustomTemplatesCard(vm: vm, modelContext: modelContext)
        }
        MealTemplatesCard(vm: vm, modelContext: modelContext)
        NutritionSupplementsCard()
    }

    // MARK: - Insights Section

    @ViewBuilder
    private var insightsSection: some View {
        NutritionStreakCard()
        NutritionTrendCard()
        if let profile = lifestyleProfile {
            LifestylePlanCard(profile: profile, onOpen: { showLifestylePlan = true })
                .requiresPro()
            SymptomDietCard(profile: profile, onOpen: { showSymptomDiet = true })
        }
        MealSuggestionCard(vm: vm, dietPreference: lifestyleProfile?.dietPreference ?? .omnivore, modelContext: modelContext)
        AISuggestionCard(vm: vm, apiKey: appState.anthropicAPIKey, profile: appState.profile)
            .requiresPro()
    }
}
