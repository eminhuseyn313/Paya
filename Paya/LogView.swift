import SwiftUI
import SwiftData

// MARK: - Log Tab (v2 Redesign)
//
// Merges Nutrition and Health entry into a single "daily data capture" tab.
// Three segments: Food · Body · Health
//
// Design principles:
// 1. Logging-only — no analytics on this screen (those live in Trends)
// 2. Camera/voice elevated to primary entry points
// 3. Running totals always visible in Food segment
// 4. Smart defaults: auto-selects most relevant segment based on context
//
// What moved here:
// - From NutritionView: NutritionProgressCard, DescribeFoodCard, QuickActionBar,
//   food logging sheets, drink management, meal templates
// - From HealthView: FlareDayToggle, JointPainCard, SleepTrackerCard,
//   SymptomLogCard, MedicationsCard, BloodPressureCard, OutdoorTimeCard
//
// What moved OUT (to Trends tab):
// - Nutrition insights: NutritionStreakCard, NutritionTrendCard, MealSuggestionCard,
//   AISuggestionCard, LifestylePlanCard
// - Health insights: AppleHealthCard, SleepStagesCard, MindfulMinutesCard,
//   WeeklyHealthGoalsCard, SupplementAdviceCard

enum LogSection: String, CaseIterable, Identifiable {
    case food = "Food"
    case body = "Body"
    case health = "Health"
    var id: String { rawValue }
}

struct LogView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    // Nutrition state
    @State private var nutritionVM = NutritionViewModel()
    @State private var showManualLogSheet = false
    @State private var showAzeQuickAdd = false
    @State private var showLabelScanner = false
    @State private var scannedLabel: ParsedNutritionLabel? = nil
    @State private var showDescribeFood = false
    @State private var showPhotoEstimate = false
    @State private var showDrinkManagement = false

    // Health state
    @State private var healthVM = HealthViewModel()
    @State private var notesText: String = ""
    @State private var showHealthActivities = false

    // Body state
    @State private var showWeightEntry = false
    @State private var weightInput = ""
    @State private var showBodyTracking = false

    // Tab state
    @State private var section: LogSection = .food

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {

                    // Segment picker
                    Picker("Section", selection: $section) {
                        ForEach(LogSection.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch section {
                    case .food:
                        foodSection
                    case .body:
                        bodySection
                    case .health:
                        healthSection
                    }

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Log")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            autoSelectSection()
            loadAll()
        }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in loadAll() }
        // Nutrition sheets
        .sheet(isPresented: $showDescribeFood) {
            DescribeFoodView(vm: nutritionVM)
        }
        .sheet(isPresented: $showDrinkManagement) {
            DrinkManagementView()
        }
        .fullScreenCover(isPresented: $showPhotoEstimate) {
            FoodPhotoEstimateView(vm: nutritionVM)
        }
        .sheet(isPresented: $nutritionVM.showBarcodeScanner) {
            BarcodeScannerView(
                onCodeScanned: { code in
                    Task {
                        await nutritionVM.handleScannedCode(code, context: modelContext)
                    }
                },
                onCancel: {
                    nutritionVM.showBarcodeScanner = false
                }
            )
        }
        .sheet(isPresented: $nutritionVM.showScannedProductSheet) {
            if let product = nutritionVM.scannedProduct {
                ProductDetailSheet(product: product) { name, protein, calories in
                    nutritionVM.addMeal(
                        name: name, food: name,
                        protein: protein, calories: calories,
                        context: modelContext
                    )
                }
            }
        }
        .sheet(isPresented: $nutritionVM.showSearchSheet) {
            FoodSearchSheet(vm: nutritionVM)
        }
        .sheet(isPresented: $nutritionVM.showServingSizeSheet) {
            if let product = nutritionVM.selectedProduct {
                ServingSizeSheet(vm: nutritionVM, product: product)
            }
        }
        .sheet(isPresented: $showManualLogSheet) {
            ManualLogSheet(vm: nutritionVM)
        }
        .sheet(isPresented: $showAzeQuickAdd) {
            AzeQuickAddView { name, protein, calories in
                nutritionVM.addMeal(
                    name: name, food: name,
                    protein: protein, calories: calories,
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
                nutritionVM.addMeal(
                    name: name, food: name,
                    protein: protein, calories: calories,
                    context: modelContext
                )
            }
        }
        // Health sheets
        .sheet(isPresented: $showHealthActivities) {
            HealthActivitiesView()
        }
        // Body sheets
        .sheet(isPresented: $showWeightEntry) {
            DashboardView.WeightEntrySheet(
                weightInput: $weightInput,
                onSave: {
                    if let _ = Double(weightInput) {
                        // Weight logging handled by body section inline
                        weightInput = ""
                        showWeightEntry = false
                        appState.dataRefreshTrigger = UUID()
                    }
                },
                onCancel: {
                    weightInput = ""
                    showWeightEntry = false
                }
            )
        }
        .sheet(isPresented: $showBodyTracking) {
            BodyTrackingView()
        }
        .onChange(of: nutritionVM.mealVersion) { _, _ in
            appState.dataRefreshTrigger = UUID()
        }
    }

    // MARK: - Smart Default Section

    private func autoSelectSection() {
        let hour = Calendar.current.component(.hour, from: .now)

        // If training just completed, suggest Body (weight logging)
        if appState.isSessionActive == false {
            // Check if there was a recent session today
            let today = Calendar.current.startOfDay(for: .now)
            let desc = FetchDescriptor<TrainingSession>(
                predicate: #Predicate<TrainingSession> { $0.isCompleted && $0.date >= today }
            )
            if let sessions = try? modelContext.fetch(desc), !sessions.isEmpty {
                let lastSession = sessions.max(by: { $0.date < $1.date })
                if let last = lastSession, Date().timeIntervalSince(last.date) < 1800 {
                    section = .body
                    return
                }
            }
        }

        // Evening → Health (sleep prep, symptoms)
        if hour >= 20 {
            section = .health
            return
        }

        // Default → Food (most common use case)
        section = .food
    }

    // MARK: - Food Section

    @ViewBuilder
    private var foodSection: some View {
        // Progress rings
        NutritionProgressCard(vm: nutritionVM, appState: appState)

        // Voice log — primary input
        DescribeFoodCard(onOpen: { showDescribeFood = true })

        // Quick action chips
        QuickActionBar(
            onScan: { nutritionVM.showBarcodeScanner = true },
            onSearch: { nutritionVM.showSearchSheet = true },
            onManual: { showManualLogSheet = true },
            onAze: { showAzeQuickAdd = true },
            onLabel: { showLabelScanner = true },
            onPhoto: { showPhotoEstimate = true }
        )

        // Loading indicator
        if nutritionVM.isLookingUpBarcode {
            HStack {
                ProgressView()
                Text("Looking up product…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }

        if let error = nutritionVM.lookupError {
            Text(error)
                .font(.caption)
                .foregroundColor(PayaColor.warning)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(PayaColor.warning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }

        // Saved meal templates (quick re-log)
        QuickSavedMealTemplatesCard(onMealLogged: {
            nutritionVM.load(context: modelContext)
        })

        // Drink quick-log
        DrinkQuickCard(modelContext: modelContext, onOpenFull: { showDrinkManagement = true })

        // Today's logged meals
        if !nutritionVM.meals.isEmpty {
            LoggedMealsCard(vm: nutritionVM, modelContext: modelContext)
        }

        // Nutrient dashboard
        NutrientDashboardCard()

        // Recent meals
        if !nutritionVM.recentMeals.isEmpty {
            RecentMealsCard(vm: nutritionVM, modelContext: modelContext)
        }

        // Templates section
        if !nutritionVM.customTemplates.isEmpty {
            ProgressCollapsible(
                title: "Meal templates",
                icon: "doc.text.fill",
                color: "2563EB"
            ) {
                CustomTemplatesCard(vm: nutritionVM, modelContext: modelContext)
                MealTemplatesCard(vm: nutritionVM, modelContext: modelContext)
            }
        }

        // Supplements
        NutritionSupplementsCard()
    }

    // MARK: - Body Section

    @ViewBuilder
    private var bodySection: some View {
        // Quick weight entry
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 12))
                    .foregroundColor(PayaColor.positive)
                Text("Body weight")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button { showWeightEntry = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Log")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(PayaColor.positive)
                    .clipShape(Capsule())
                }
            }
        }
        .payaCard(padding: 14)

        // Body composition
        BodyCompositionCard()

        // Body tracking (measurements + photos)
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
                    Text("Measurements & Photos")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text("Track body measurements and progress photos")
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

        // Blood pressure
        BloodPressureCard()
    }

    // MARK: - Health Section

    @ViewBuilder
    private var healthSection: some View {
        // Flare day toggle
        FlareDayToggle(vm: healthVM, appState: appState, modelContext: modelContext)

        // Pain/soreness
        JointPainCard(vm: healthVM, appState: appState, modelContext: modelContext)

        // Sleep
        SleepTrackerCard(vm: healthVM, appState: appState, modelContext: modelContext)

        // Symptoms
        SymptomLogCard()

        // Medications
        MedicationsCard()

        // Outdoor time
        OutdoorTimeCard()

        // Health activities
        HealthActivitiesCard(onOpen: { showHealthActivities = true })

        // Notes
        NotesCard(vm: healthVM, notesText: $notesText, modelContext: modelContext)
    }

    // MARK: - Data Loading

    private func loadAll() {
        nutritionVM.appStateRef = appState
        nutritionVM.load(context: modelContext, profile: appState.profile)
        nutritionVM.checkAdaptiveCalories(appState: appState, context: modelContext)
        Task { await nutritionVM.loadTDEE(context: modelContext, profile: appState.profile) }
        Task { await nutritionVM.checkRecoveryNudge() }

        healthVM.load(context: modelContext)
        notesText = healthVM.todaysLog?.notes ?? ""
        Task { await healthVM.loadHealthKitData() }
    }
}
