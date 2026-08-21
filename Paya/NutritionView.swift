import SwiftUI
import SwiftData

// Was a flat scroll of up to 10 stacked cards — the same "wall of cards"
// problem fixed on Progress. The two actual logging actions (progress
// rings + quick-add bar) stay pinned above the picker since logging food
// is this screen's primary job; everything else groups behind tabs.
private enum NutritionSection: String, CaseIterable, Identifiable {
    case today = "Today"
    case templates = "Templates"
    case insights = "Insights"
    var id: String { rawValue }
}

struct NutritionView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var vm = NutritionViewModel()
    @State private var showManualLogSheet = false
    @State private var showAzeQuickAdd = false
    @State private var showLabelScanner = false
    @State private var scannedLabel: ParsedNutritionLabel? = nil
    @State private var showLifestylePlan = false
    @State private var lifestyleProfile: PersonProfile? = nil
    @State private var showDescribeFood = false
    @State private var showPhotoEstimate = false
    @State private var showDrinkManagement = false
    @State private var section: NutritionSection = .today

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            ScrollView {
                VStack(spacing: 14) {

                    // Progress rings
                    NutritionProgressCard(vm: vm, appState: appState)

                    // Voice log — primary input, always visible
                    DescribeFoodCard(onOpen: { showDescribeFood = true })

                    // Quick action chips — compact horizontal scroll
                    QuickActionBar(
                        onScan: { vm.showBarcodeScanner = true },
                        onSearch: { vm.showSearchSheet = true },
                        onManual: { showManualLogSheet = true },
                        onAze: { showAzeQuickAdd = true },
                        onLabel: { showLabelScanner = true },
                        onPhoto: { showPhotoEstimate = true }
                    )

                    // Loading indicator when looking up barcode
                    if vm.isLookingUpBarcode {
                        HStack {
                            ProgressView()
                            Text("Looking up product…")
                                .font(.caption)
                                .foregroundColor(Pulse.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if let error = vm.lookupError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(Pulse.warning)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Pulse.warning.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Picker("Section", selection: $section) {
                        ForEach(NutritionSection.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)

                    switch section {
                    case .today:
                        QuickSavedMealTemplatesCard(onMealLogged: {
                            vm.load(context: modelContext)
                        })
                        CalorieDeficitCard()
                        DrinkQuickCard(modelContext: modelContext, onOpenFull: { showDrinkManagement = true })
                        NutritionSupplementsCard()
                        if !vm.meals.isEmpty {
                            LoggedMealsCard(vm: vm, modelContext: modelContext)
                        }
                        NutrientDashboardCard()
                        if !vm.recentMeals.isEmpty {
                            RecentMealsCard(vm: vm, modelContext: modelContext)
                        }

                    case .templates:
                        if !vm.customTemplates.isEmpty {
                            CustomTemplatesCard(vm: vm, modelContext: modelContext)
                        }
                        MealTemplatesCard(vm: vm, modelContext: modelContext)

                    case .insights:
                        NutritionStreakCard()
                        NutritionTrendCard()
                        if let profile = lifestyleProfile {
                            LifestylePlanCard(profile: profile, onOpen: { showLifestylePlan = true })
                                .requiresPro()
                        }
                        MealSuggestionCard(vm: vm, dietPreference: lifestyleProfile?.dietPreference ?? .omnivore, modelContext: modelContext)
                        AISuggestionCard(vm: vm, apiKey: appState.anthropicAPIKey, profile: appState.profile)
                            .requiresPro()
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .frame(width: geo.size.width)
            }
            }
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            vm.appStateRef = appState
            vm.load(context: modelContext, profile: appState.profile)
            vm.checkAdaptiveCalories(appState: appState, context: modelContext)
            Task { await vm.loadTDEE(context: modelContext, profile: appState.profile) }
            Task { await vm.checkRecoveryNudge() }
            lifestyleProfile = ProfileStore.current(context: modelContext)
            applyPendingNutritionAction()
        }
        .onChange(of: appState.pendingNutritionAction) { _, action in
            if action != nil { applyPendingNutritionAction() }
        }
        .sheet(isPresented: $showLifestylePlan) {
            if let profile = lifestyleProfile {
                LifestylePlanView(profile: profile)
            }
        }
        .sheet(isPresented: $showDescribeFood) {
            DescribeFoodView(vm: vm)
        }
        .sheet(isPresented: $showDrinkManagement) {
            DrinkManagementView()
        }
        .fullScreenCover(isPresented: $showPhotoEstimate) {
            FoodPhotoEstimateView(vm: vm)
        }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in
            vm.load(context: modelContext, profile: appState.profile)
            Task { await vm.loadTDEE(context: modelContext, profile: appState.profile) }
        }
        .onChange(of: vm.mealVersion) { _, _ in
            appState.dataRefreshTrigger = UUID()
        }
        .sheet(isPresented: $vm.showBarcodeScanner) {
            BarcodeScannerView(
                onCodeScanned: { code in
                    Task {
                        await vm.handleScannedCode(code, context: modelContext)
                    }
                },
                onCancel: {
                    vm.showBarcodeScanner = false
                }
            )
        }
        .sheet(isPresented: $vm.showScannedProductSheet) {
                    if let product = vm.scannedProduct {
                        ProductDetailSheet(product: product) { name, protein, calories in
                            vm.addMeal(
                                name: name,
                                food: name,
                                protein: protein,
                                calories: calories,
                                context: modelContext
                            )
                        }
                    }
                }
        .sheet(isPresented: $vm.showSearchSheet) {
            FoodSearchSheet(vm: vm)
        }
        .sheet(isPresented: $vm.showServingSizeSheet) {
            if let product = vm.selectedProduct {
                ServingSizeSheet(vm: vm, product: product)
            }
        }
        .sheet(isPresented: $showManualLogSheet) {
            ManualLogSheet(vm: vm)
        }
        .sheet(isPresented: $showAzeQuickAdd) {
                    AzeQuickAddView { name, protein, calories in
                        vm.addMeal(
                            name: name,
                            food: name,
                            protein: protein,
                            calories: calories,
                            context: modelContext
                        )
                    }
                }
        .fullScreenCover(isPresented: $showLabelScanner) {
            NutritionLabelScannerView { parsed in
                scannedLabel = parsed
            }
        }
        .sheet(item: $scannedLabel) { label in
            LabelScanConfirmSheet(label: label) { name, protein, calories in
                vm.addMeal(
                    name: name,
                    food: name,
                    protein: protein,
                    calories: calories,
                    context: modelContext
                )
            }
        }
            }

    // MARK: - Deep-Link Action

    private func applyPendingNutritionAction() {
        guard let action = appState.pendingNutritionAction else { return }
        appState.pendingNutritionAction = nil
        // Small delay so the tab switch animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            switch action {
            case .search:   vm.showSearchSheet = true
            case .scan:     vm.showBarcodeScanner = true
            case .manual:   showManualLogSheet = true
            case .describe: showDescribeFood = true
            case .label:    showLabelScanner = true
            case .photo:    showPhotoEstimate = true
            }
        }
    }
        }

// MARK: - Progress Card

struct NutritionProgressCard: View {
    var vm: NutritionViewModel
    var appState: AppState

    var proteinProgress: Double {
        guard let log = vm.todaysLog, log.proteinTarget > 0 else { return 0 }
        return min(1.0, log.totalProtein / log.proteinTarget)
    }

    var calorieProgress: Double {
        guard let log = vm.todaysLog, log.calorieTarget > 0 else { return 0 }
        return min(1.0, log.totalCalories / log.calorieTarget)
    }

    var baselineTDEE: Double {
        TDEEEngine.bmr(bodyWeightKg: appState.profile.currentWeightKg, age: appState.profile.age, heightCm: appState.profile.heightCm, sexRaw: appState.profile.sexRaw) * 1.55
    }

    var tdeeDelta: Double? {
        guard let tdee = vm.tdeeToday else { return nil }
        return tdee.total - baselineTDEE
    }

    private func macroStat(label: String, value: String, hex: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: hex))
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(appState.calorieTargetLabel())
                .font(.caption.weight(.semibold))
                .foregroundColor(Pulse.textTertiary)

            if let tdee = vm.tdeeToday {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundColor(Pulse.warning)
                    Text("Calories out ~\(Int(tdee.total)) kcal (BMR \(Int(tdee.bmr)) + \(Int(tdee.activityKcal)) activity)")
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                    if let delta = tdeeDelta, abs(delta) >= 50 {
                        Text(delta > 0 ? "+\(Int(delta))" : "\(Int(delta))")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(delta > 0 ? Pulse.positive : Pulse.warning)
                    }
                }
            }

            if let kcal = vm.adaptiveAdjustmentKcal, let reason = vm.adaptiveAdjustmentReason {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                        .foregroundColor(Pulse.hydration)
                    Text("Target adjusted \(kcal > 0 ? "+" : "")\(Int(kcal)) kcal — \(reason)")
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                        .multilineTextAlignment(.leading)
                }
                .padding(8)
                .background(Pulse.hydration.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let nudge = vm.recoveryNudge {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.caption2)
                        .foregroundColor(Pulse.ai)
                    Text(nudge)
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                        .multilineTextAlignment(.leading)
                }
                .padding(8)
                .background(Pulse.ai.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 20) {

                // Protein ring
                MacroRing(
                    progress: proteinProgress,
                    color: Pulse.hydration,
                    label: "Protein",
                    value: "\(Int(vm.todaysLog?.totalProtein ?? 0))g",
                    target: "\(Int(vm.todaysLog?.proteinTarget ?? 170))g"
                )

                // Calorie ring
                MacroRing(
                    progress: calorieProgress,
                    color: Pulse.positive,
                    label: "Calories",
                    value: "\(Int(vm.todaysLog?.totalCalories ?? 0))",
                    target: "\(Int(vm.todaysLog?.calorieTarget ?? 2200))"
                )
            }

            if let log = vm.todaysLog, (log.totalFat > 0 || log.totalCarbs > 0) {
                HStack(spacing: 0) {
                    macroStat(label: "Carbs", value: "\(Int(log.totalCarbs))g", hex: "F97316")
                    macroStat(label: "Fat", value: "\(Int(log.totalFat))g", hex: "8B5CF6")
                    macroStat(label: "Fiber", value: "\(Int(log.totalFiber))g", hex: "22C55E")
                    macroStat(label: "Sugar", value: "\(Int(log.totalSugar))g", hex: "F59E0B")
                }
            }
        }
        .payaCard(padding: 16)
    }
}

struct MacroRing: View {
    var progress: Double
    var color: Color
    var label: String
    var value: String
    var target: String

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 10)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: progress)
                VStack(spacing: 2) {
                    Text(value)
                        .font(.headline.bold())
                    Text("/ \(target)")
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                }
            }
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(Pulse.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value) of \(target)")
    }
}

// MARK: - Quick Action Bar

struct QuickActionBar: View {
    var onScan: () -> Void
    var onSearch: () -> Void
    var onManual: () -> Void
    var onAze: () -> Void
    var onLabel: () -> Void
    var onPhoto: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                QuickActionChip(icon: "camera.viewfinder", label: "Photo", color: Pulse.critical, action: onPhoto)
                QuickActionChip(icon: "barcode.viewfinder", label: "Scan", color: Pulse.hydration, action: onScan)
                QuickActionChip(icon: "doc.text.viewfinder", label: "Label", color: Pulse.ai, action: onLabel)
                QuickActionChip(icon: "magnifyingglass", label: "Search", color: Pulse.positive, action: onSearch)
                QuickActionChip(icon: "plus.circle.fill", label: "Manual", color: Pulse.warning, action: onManual)
                QuickActionChip(emoji: "🇦🇿", label: "Local", color: Pulse.positive, action: onAze)
            }
            .padding(.horizontal, 2)
        }
    }
}

struct QuickActionChip: View {
    var icon: String? = nil
    var emoji: String? = nil
    var label: String
    var color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let emoji {
                    Text(emoji).font(.system(size: 14))
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Pulse.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())
        }
        .buttonStyle(PulsePress())
    }
}


// MARK: - Logged Meals

struct LoggedMealsCard: View {
    var vm: NutritionViewModel
    var modelContext: ModelContext

    @State private var selectedMeal: MealLog?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundColor(Pulse.positive)
                Text("Today's meals")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(vm.meals.count)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Pulse.positive)
            }

            VStack(spacing: 6) {
                ForEach(vm.meals) { meal in
                    Button { selectedMeal = meal } label: {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(meal.food)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Pulse.textPrimary)
                                    .multilineTextAlignment(.leading)
                                HStack(spacing: 6) {
                                    Text(meal.name)
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Pulse.positive.opacity(0.12))
                                        .foregroundColor(Pulse.positive)
                                        .clipShape(Capsule())
                                    Text("\(Int(meal.protein))g P · \(Int(meal.calories)) kcal")
                                        .font(.caption)
                                        .foregroundColor(Pulse.textTertiary)
                                    if meal.fatG > 0 || meal.carbsG > 0 {
                                        Text("· \(Int(meal.fatG))g F · \(Int(meal.carbsG))g C")
                                            .font(.caption)
                                            .foregroundColor(Pulse.textTertiary)
                                    }
                                }
                            }
                            Spacer()
                            Menu {
                                Button {
                                    vm.saveMealAsTemplate(meal, context: modelContext)
                                } label: {
                                    Label("Save as template", systemImage: "star")
                                }
                                Button(role: .destructive) {
                                    vm.deleteMeal(meal, context: modelContext)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundColor(Pulse.textTertiary)
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Meal options")
                        }
                        .padding(10)
                        .background(Pulse.surfaceElevatedFallback)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(PulsePress())
                }
            }
        }
        .payaCard(padding: 14)
        .sheet(item: $selectedMeal) { meal in
            MealNutrientDetailView(meal: meal)
        }
    }
}

// MARK: - Meal Nutrient Detail

struct MealNutrientDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let meal: MealLog

    private var nutrients: [(label: String, value: Double, unit: String)] {
        var list: [(String, Double, String)] = [
            ("Protein", meal.protein, "g"),
            ("Calories", meal.calories, "kcal"),
        ]
        if meal.fatG > 0 { list.append(("Fat", meal.fatG, "g")) }
        if meal.carbsG > 0 { list.append(("Carbs", meal.carbsG, "g")) }
        if meal.fiberG > 0 { list.append(("Fiber", meal.fiberG, "g")) }
        if meal.sugarG > 0 { list.append(("Sugar", meal.sugarG, "g")) }
        if meal.ironMg > 0 { list.append(("Iron", meal.ironMg, "mg")) }
        if meal.calciumMg > 0 { list.append(("Calcium", meal.calciumMg, "mg")) }
        if meal.magnesiumMg > 0 { list.append(("Magnesium", meal.magnesiumMg, "mg")) }
        if meal.zincMg > 0 { list.append(("Zinc", meal.zincMg, "mg")) }
        if meal.vitaminDMcg > 0 { list.append(("Vitamin D", meal.vitaminDMcg, "mcg")) }
        if meal.potassiumMg > 0 { list.append(("Potassium", meal.potassiumMg, "mg")) }
        if meal.vitaminCMg > 0 { list.append(("Vitamin C", meal.vitaminCMg, "mg")) }
        if meal.sodiumMg > 0 { list.append(("Sodium", meal.sodiumMg, "mg")) }
        return list
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(meal.food)
                            .font(.title3.weight(.bold))
                        HStack(spacing: 8) {
                            Text(meal.name)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Pulse.positive.opacity(0.12))
                                .foregroundColor(Pulse.positive)
                                .clipShape(Capsule())
                            Text(meal.loggedAt.formatted(.dateTime.hour().minute()))
                                .font(.caption)
                                .foregroundColor(Pulse.textTertiary)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(nutrients, id: \.label) { item in
                            HStack {
                                Text(item.label)
                                    .font(.subheadline)
                                    .foregroundColor(Pulse.textTertiary)
                                Spacer()
                                Text("\(formatted(item.value)) \(item.unit)")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(10)
                            .background(Pulse.surfaceElevatedFallback)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    if nutrients.count <= 2 {
                        VStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.title3)
                                .foregroundColor(Pulse.textTertiary)
                            Text("Detailed nutrients are available when food is logged via \"Describe a Food\" or photo scan. Manual entries only have protein and calories.")
                                .font(.caption)
                                .foregroundColor(Pulse.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Meal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func formatted(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f", value) : String(format: "%.0f", value)
    }
}

// MARK: - Meal Suggestions (instant, no AI)

struct MealSuggestionCard: View {
    var vm: NutritionViewModel
    var dietPreference: DietPreference
    var modelContext: ModelContext

    private var remainingProtein: Double {
        max(0, (vm.todaysLog?.proteinTarget ?? 170) - (vm.todaysLog?.totalProtein ?? 0))
    }
    private var remainingCalories: Double {
        max(0, (vm.todaysLog?.calorieTarget ?? 2200) - (vm.todaysLog?.totalCalories ?? 0))
    }
    private var suggestions: [FoodOption] {
        MealSuggestionEngine.suggest(
            remainingProteinG: remainingProtein,
            remainingCalories: remainingCalories,
            dietPreference: dietPreference
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "fork.knife.circle.fill")
                    .foregroundColor(Pulse.positive)
                Text("What to Eat Next")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(remainingProtein))g protein left")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Pulse.textTertiary)
            }

            if remainingProtein <= 0 {
                Text("Protein target hit for today — nice work.")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
            } else if suggestions.isEmpty {
                Text("No matching options for your diet preference right now.")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
            } else {
                VStack(spacing: 6) {
                    ForEach(suggestions) { option in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(option.name)
                                    .font(.caption.weight(.semibold))
                                Text("\(option.servingNote) · \(Int(option.proteinG))g protein · \(Int(option.calories)) kcal")
                                    .font(.caption2)
                                    .foregroundColor(Pulse.textTertiary)
                            }
                            Spacer()
                            Button {
                                vm.addMeal(name: "Snack", food: option.name, protein: option.proteinG, calories: option.calories, context: modelContext)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(Pulse.positive)
                            }
                            .buttonStyle(PulsePress())
                        }
                        .padding(8)
                        .background(Pulse.surfaceElevatedFallback)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .payaCard(padding: 14)
    }
}

// MARK: - AI Suggestion

struct AISuggestionCard: View {
    var vm: NutritionViewModel
    var apiKey: String
    var profile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: AIService.shared.providerIcon)
                    .foregroundColor(Pulse.ai)
                Text("AI Suggestion")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(AIService.shared.providerName)
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Pulse.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Pulse.surfaceElevatedFallback)
                    .clipShape(Capsule())
            }

            if let suggestion = vm.aiSuggestion {
                Text(suggestion)
                    .font(.subheadline)
                    .foregroundColor(Pulse.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Ask AI what to eat next based on your remaining protein and calorie goals.")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
            }

            Button {
                Task {
                    await vm.fetchAISuggestion(apiKey: apiKey, profile: profile)
                }
            } label: {
                HStack {
                    if vm.isFetchingAI {
                        ProgressView().tint(.white)
                        Text("Thinking…")
                    } else {
                        Image(systemName: "sparkles")
                        Text(vm.aiSuggestion == nil ? "Get suggestion" : "Get new suggestion")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Pulse.ai)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(vm.isFetchingAI)
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Food Search Sheet

struct FoodSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var vm: NutritionViewModel
    @State private var db = FoodDatabaseService.shared
    @State private var showAzeQuickAdd = false
    @Environment(AppState.self) private var appState

    private var azeShortcuts: [AzeFood] {
        let favorites = appState.profile.favoriteAzeFoodIds
        if !favorites.isEmpty {
            return AzeFoodsData.all.filter { favorites.contains($0.id) }
        }
        return AzeFood.Category.allCases.compactMap { AzeFoodsData.byCategory($0).first }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Pulse.textTertiary)
                    TextField("Search food (e.g. Greek yogurt)", text: $vm.searchQuery)
                        .onSubmit {
                            Task {
                                await db.search(query: vm.searchQuery)
                            }
                        }
                    if !vm.searchQuery.isEmpty {
                        Button {
                            vm.searchQuery = ""
                            db.clearResults()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Pulse.textTertiary)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(10)
                .background(Pulse.surfaceElevatedFallback)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if db.isSearching {
                    ProgressView().padding()
                }

                if vm.searchQuery.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if !vm.recentMeals.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Recent")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(Pulse.textTertiary)
                                    VStack(spacing: 8) {
                                        ForEach(vm.recentMeals.prefix(5)) { meal in
                                            Button {
                                                vm.logMealFromRecent(meal, context: modelContext)
                                                dismiss()
                                            } label: {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(meal.name)
                                                        .font(.subheadline.weight(.semibold))
                                                        .foregroundColor(Pulse.textPrimary)
                                                    Text("\(Int(meal.protein))g P · \(Int(meal.calories)) kcal")
                                                        .font(.caption)
                                                        .foregroundColor(Pulse.textTertiary)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .payaCard(padding: 10)
                                            }
                                        }
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("AZE Shortcuts")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(Pulse.textTertiary)
                                    Spacer()
                                    Button("Browse all") { showAzeQuickAdd = true }
                                        .font(.caption.weight(.semibold))
                                }
                                VStack(spacing: 8) {
                                    ForEach(azeShortcuts) { food in
                                        Button {
                                            let n = food.nutrition(grams: food.typicalPortionG)
                                            vm.addMeal(
                                                name: food.name,
                                                food: food.portionLabel,
                                                protein: n.protein,
                                                calories: n.calories,
                                                context: modelContext
                                            )
                                            dismiss()
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: food.category.icon)
                                                    .foregroundColor(Pulse.positive)
                                                    .frame(width: 20)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(food.name)
                                                        .font(.subheadline.weight(.semibold))
                                                        .foregroundColor(Pulse.textPrimary)
                                                    Text("\(food.portionLabel) · \(Int(food.nutrition(grams: food.typicalPortionG).protein))g P")
                                                        .font(.caption)
                                                        .foregroundColor(Pulse.textTertiary)
                                                }
                                                Spacer()
                                                Image(systemName: "plus.circle.fill")
                                                    .foregroundColor(Pulse.positive)
                                            }
                                            .payaCard(padding: 10)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }
                } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(db.searchResults) { product in
                            Button {
                                vm.selectedProduct = product
                                vm.servingSizeGrams = product.servingSize ?? 100
                                vm.showServingSizeSheet = true
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(Pulse.textPrimary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Text("\(Int(product.proteinPer100g))g P · \(Int(product.caloriesPer100g)) kcal per 100g")
                                        .font(.caption)
                                        .foregroundColor(Pulse.textTertiary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .payaCard(padding: 10)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                }
            }
            .navigationTitle("Search food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showAzeQuickAdd) {
                AzeQuickAddView { name, protein, calories in
                    vm.addMeal(name: name, food: name, protein: protein, calories: calories, context: modelContext)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Serving Size Sheet

struct ServingSizeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var vm: NutritionViewModel
    var product: FoodDatabaseService.FoodProduct

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(product.displayName)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text("Serving size (grams)")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                    TextField("Grams", value: $vm.servingSizeGrams, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.title2.bold())
                        .padding()
                        .background(Pulse.surfaceElevatedFallback)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    let (protein, calories) = product.nutritionFor(grams: vm.servingSizeGrams)
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(Int(protein))g")
                                .font(.title3.bold())
                                .foregroundColor(Pulse.hydration)
                            Text("Protein").font(.caption).foregroundColor(Pulse.textTertiary)
                        }
                        VStack {
                            Text("\(Int(calories))")
                                .font(.title3.bold())
                                .foregroundColor(Pulse.positive)
                            Text("kcal").font(.caption).foregroundColor(Pulse.textTertiary)
                        }
                    }

                    Button {
                        vm.logMealFromProduct(product, grams: vm.servingSizeGrams, context: modelContext)
                        dismiss()
                    } label: {
                        Text("Log meal")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Pulse.positive)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
            }
            .navigationTitle("Portion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Manual Log Sheet

struct ManualLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var vm: NutritionViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    LabeledField(label: "Meal name", text: $vm.mealName)
                    LabeledField(label: "What you ate", text: $vm.mealFood)
                    LabeledField(label: "Protein (g)", text: $vm.mealProtein, keyboard: .decimalPad)
                    LabeledField(label: "Calories", text: $vm.mealCalories, keyboard: .numberPad)

                    Button {
                        vm.addManualMeal(context: modelContext)
                        dismiss()
                    } label: {
                        Text("Log meal")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(vm.mealFood.isEmpty
                                ? Color.secondary.opacity(0.5)
                                : Pulse.positive)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(vm.mealFood.isEmpty)
                }
                .padding(16)
            }
            .navigationTitle("Add manually")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct LabeledField: View {
    var label: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(Pulse.textTertiary)
            TextField(label, text: $text)
                .keyboardType(keyboard)
                .padding(10)
                .background(Pulse.surfaceElevatedFallback)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}
// MARK: - Recent Meals

struct RecentMealsCard: View {
    var vm: NutritionViewModel
    var modelContext: ModelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(Pulse.textTertiary)
                Text("Log again")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.recentMeals) { meal in
                        Button {
                            vm.logMealFromRecent(meal, context: modelContext)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(meal.food)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(Pulse.textPrimary)
                                    .lineLimit(2)
                                Text("\(Int(meal.protein))g P · \(Int(meal.calories)) kcal")
                                    .font(.caption2)
                                    .foregroundColor(Pulse.textTertiary)
                            }
                            .frame(width: 130, alignment: .leading)
                            .padding(10)
                            .background(Pulse.surfaceElevatedFallback)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Custom Templates

struct CustomTemplatesCard: View {
    var vm: NutritionViewModel
    var modelContext: ModelContext
    @State private var templatePendingDelete: CustomMealTemplate? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(Pulse.warning)
                Text("Your saved meals")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            VStack(spacing: 6) {
                ForEach(vm.customTemplates) { template in
                    HStack {
                        Button {
                            vm.logMealFromCustomTemplate(template, context: modelContext)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(Pulse.warning)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(Pulse.textPrimary)
                                    Text("\(Int(template.protein))g P · \(Int(template.calories)) kcal")
                                        .font(.caption)
                                        .foregroundColor(Pulse.textTertiary)
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(PulsePress())

                        Button {
                            templatePendingDelete = template
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Delete \(template.name)")
                    }
                    .padding(8)
                    .background(Pulse.surfaceElevatedFallback)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .payaCard(padding: 14)
        .confirmationDialog(
            "Delete this saved meal?",
            isPresented: Binding(
                get: { templatePendingDelete != nil },
                set: { if !$0 { templatePendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let template = templatePendingDelete {
                    vm.deleteCustomTemplate(template, context: modelContext)
                }
                templatePendingDelete = nil
            }
            Button("Cancel", role: .cancel) { templatePendingDelete = nil }
        }
    }
}

// MARK: - Preset Templates

struct MealTemplatesCard: View {
    var vm: NutritionViewModel
    var modelContext: ModelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "square.grid.2x2")
                    .foregroundColor(Pulse.textTertiary)
                Text("Quick add")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(ProgramData.mealTemplates) { template in
                    Button {
                        vm.logMealFromTemplate(template, context: modelContext)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(template.name)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Pulse.textPrimary)
                            Text("\(Int(template.protein))g P · \(Int(template.calories)) kcal")
                                .font(.caption2)
                                .foregroundColor(Pulse.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Pulse.surfaceElevatedFallback)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Drink Quick Card (Nutrition Tab)

struct DrinkQuickCard: View {
    var modelContext: ModelContext
    var onOpenFull: () -> Void

    @State private var waterMl: Int = 0
    @State private var selectedDrink: DrinkType = .water

    private var progress: Double {
        min(1.0, Double(waterMl) / Double(WaterStore.dailyTargetMl))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Pulse.recovery.opacity(0.12), lineWidth: 5)
                        .frame(width: 40, height: 40)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Pulse.recovery, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "drop.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Pulse.recovery)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Drinks")
                        .font(.subheadline.weight(.semibold))
                    Text(String(format: "%.1fL / %.1fL", Double(waterMl) / 1000.0, Double(WaterStore.dailyTargetMl) / 1000.0))
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                }
                Spacer()
                Button { onOpenFull() } label: {
                    Text("Details")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Pulse.recovery)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Pulse.recovery.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(PulsePress())
            }

            HStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(DrinkType.allCases) { type in
                            Button { selectedDrink = type } label: {
                                Image(systemName: type.icon)
                                    .font(.system(size: 11))
                                    .foregroundColor(selectedDrink == type ? Pulse.recovery : .secondary)
                                    .frame(width: 28, height: 28)
                                    .background(selectedDrink == type ? Pulse.recovery.opacity(0.12) : Pulse.surfaceElevatedFallback)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PulsePress())
                        }
                    }
                }
                ForEach([250, 500], id: \.self) { amount in
                    Button { add(amount) } label: {
                        Text("+\(amount)ml")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Pulse.recovery)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Pulse.recovery.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PulsePress())
                }
            }
        }
        .payaCard(padding: 12)
        .onAppear {
            waterMl = WaterStore.todayTotal(context: modelContext)
        }
    }

    private func add(_ ml: Int) {
        waterMl = WaterStore.addWater(ml, drinkType: selectedDrink, context: modelContext)
        WatchSessionManager.shared.pushWaterTotal(waterMl)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
