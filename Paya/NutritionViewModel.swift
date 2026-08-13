import SwiftUI
import SwiftData

@MainActor
@Observable
class NutritionViewModel {

    // MARK: - State

    var todaysLog: NutritionLog? = nil
    var meals: [MealLog] = []
    var recentMeals: [MealLog] = []
    var customTemplates: [CustomMealTemplate] = []
    var isLoading: Bool = false

    // Barcode / product state
    var scannedProduct: FoodDatabaseService.FoodProduct? = nil
    var showScannedProductSheet: Bool = false
    var showBarcodeScanner: Bool = false
    var isLookingUpBarcode: Bool = false
    var lookupError: String? = nil

    // Search state
    var showSearchSheet: Bool = false
    var searchQuery: String = ""

    // Serving size sheet
    var servingSizeGrams: Double = 100
    var selectedProduct: FoodDatabaseService.FoodProduct? = nil
    var showServingSizeSheet: Bool = false

    // Manual meal state
    var mealName: String = "Meal"
    var mealFood: String = ""
    var mealProtein: String = ""
    var mealCalories: String = ""

    // Bumped on every meal add/delete so child cards can react
    var mealVersion: Int = 0

    // Direct reference so add/delete can refresh cards immediately
    // instead of relying on a two-hop .onChange chain
    weak var appStateRef: AppState?

    // AI suggestion
    var aiSuggestion: String? = nil
    var isFetchingAI: Bool = false

    // TDEE (BMR + steps/TRIMP activity)
    var tdeeToday: TDEEEngine.Breakdown? = nil

    // Adaptive calorie target — set when a weekly adjustment recently applied
    var adaptiveAdjustmentKcal: Double? = nil
    var adaptiveAdjustmentReason: String? = nil

    // Recovery-aware nutrition nudge — ties today's recovery signal to
    // nutrition, the integration gap flagged against WHOOP/MacroFactor.
    var recoveryNudge: String? = nil

    func checkRecoveryNudge() async {
        let manager = HealthKitManager.shared
        async let sleep = HealthMetricsProvider.shared.fetchSleepRobust()
        async let hrv = manager.fetchHRV()
        async let hr = manager.fetchRestingHR()
        let (sleepVal, hrvVal, hrVal) = await (sleep, hrv, hr)

        guard let score = manager.computeRecoveryScore(
            sleepHours: sleepVal, hrvMs: hrvVal, restingHR: hrVal
        ) else {
            recoveryNudge = nil
            return
        }

        recoveryNudge = score < 50
            ? "Recovery is low today (\(score)/100) — lean a little heavier on protein and calories to support it."
            : nil
    }

    // MARK: - Adaptive calorie targets

    func checkAdaptiveCalories(appState: AppState, context: ModelContext) {
        guard let profile = ProfileStore.current(context: context) else { return }
        AdaptiveCalorieEngine.applyIfDue(profile: profile, appState: appState, context: context)

        if let date = profile.lastCalorieAdjustmentDate,
           let days = Calendar.current.dateComponents([.day], from: date, to: .now).day,
           days < 3,
           profile.lastCalorieAdjustmentKcal != 0 {
            adaptiveAdjustmentKcal = profile.lastCalorieAdjustmentKcal
            adaptiveAdjustmentReason = profile.lastCalorieAdjustmentReason
        } else {
            adaptiveAdjustmentKcal = nil
            adaptiveAdjustmentReason = nil
        }
    }

    // MARK: - TDEE

    func loadTDEE(context: ModelContext, profile: UserProfile) async {
        let steps = await HealthMetricsProvider.shared.fetchStepsRobust()
        tdeeToday = TDEEEngine.computeToday(profile: profile, steps: steps ?? 0, context: context)
    }

    // MARK: - Load

    func load(context: ModelContext, profile: UserProfile? = nil) {
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let pid = ActiveProfile.id

        // Fetch today's log — scoped to the active profile, same as every
        // other multi-profile data source in the app (previously fetched
        // ALL profiles' logs and picked whichever matched today's date,
        // which could silently show one profile's meals under another's).
        let descriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let allLogs = (try? context.fetch(descriptor)) ?? []
        if let log = allLogs.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            if let profile, log.proteinTarget == 170, profile.proteinTargetG != 170 {
                log.proteinTarget = profile.proteinTargetG
                let isTraining = log.isTrainingDay
                log.calorieTarget = isTraining ? profile.trainingDayCalories : profile.restDayCalories
                try? context.save()
            }
            todaysLog = log
        } else {
            let isTraining = ProgramData.todaySessionType != nil
            let proteinT = profile?.proteinTargetG ?? 170
            let calorieT = isTraining
                ? (profile?.trainingDayCalories ?? 2200)
                : (profile?.restDayCalories ?? 1900)
            let newLog = NutritionLog(date: Date(), isTrainingDay: isTraining, proteinTarget: proteinT, calorieTarget: calorieT)
            newLog.profileId = pid
            context.insert(newLog)
            try? context.save()
            todaysLog = newLog
        }
        meals = (todaysLog?.meals ?? []).sorted { $0.loggedAt > $1.loggedAt }

        // Recent meals (last 30 days, dedup by food) — MealLog has no own
        // profileId (it's a child of NutritionLog), so scope through the
        // parent relationship rather than mixing every profile's history
        // into "recent" quick-add suggestions.
        let mealDescriptor = FetchDescriptor<MealLog>(
            sortBy: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
        let allMeals = (try? context.fetch(mealDescriptor)) ?? []
        let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recent = allMeals.filter { $0.loggedAt > cutoff && $0.nutritionLog?.profileId == pid }
        var seen: Set<String> = []
        var unique: [MealLog] = []
        for meal in recent {
            let key = "\(meal.name)|\(meal.food)"
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(meal)
                if unique.count >= 8 { break }
            }
        }
        recentMeals = unique

        // Custom templates
        let templateDescriptor = FetchDescriptor<CustomMealTemplate>(
            predicate: #Predicate<CustomMealTemplate> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.useCount, order: .reverse)]
        )
        customTemplates = (try? context.fetch(templateDescriptor)) ?? []
    }

    // MARK: - Barcode Lookup

    func handleScannedCode(_ code: String, context: ModelContext) async {
        isLookingUpBarcode = true
        showBarcodeScanner = false
        defer { isLookingUpBarcode = false }

        if let product = await FoodDatabaseService.shared.lookupBarcode(code) {
            scannedProduct = product
            selectedProduct = product
            servingSizeGrams = product.servingSize ?? 100
            showScannedProductSheet = true
        } else {
            lookupError = "Product not found — try scanning again or search manually"
        }
    }

    // MARK: - Log meal from product

    func logMealFromProduct(
        _ product: FoodDatabaseService.FoodProduct,
        grams: Double,
        context: ModelContext
    ) {
        let (protein, calories) = product.nutritionFor(grams: grams)
        addMeal(
            name: product.brand.isEmpty ? "Meal" : product.brand,
            food: "\(Int(grams))g \(product.name)",
            protein: protein,
            calories: calories,
            context: context
        )
    }

    // MARK: - Log meal from template

    func logMealFromTemplate(_ template: MealTemplate, context: ModelContext) {
        addMeal(
            name: template.name,
            food: template.food,
            protein: template.protein,
            calories: template.calories,
            context: context
        )
    }

    func logMealFromCustomTemplate(_ template: CustomMealTemplate, context: ModelContext) {
        addMeal(
            name: template.name,
            food: template.food,
            protein: template.protein,
            calories: template.calories,
            context: context
        )
        template.useCount += 1
        try? context.save()
    }

    func logMealFromRecent(_ meal: MealLog, context: ModelContext) {
        addMeal(
            name: meal.name,
            food: meal.food,
            protein: meal.protein,
            calories: meal.calories,
            context: context
        )
    }

    // MARK: - Add meal (unified)

    func addMeal(
        name: String,
        food: String,
        protein: Double,
        calories: Double,
        context: ModelContext,
        estimate: GeminiFoodService.Estimate? = nil
    ) {
        guard let log = todaysLog else { return }
        let meal = MealLog(
            name: name,
            food: food,
            protein: protein,
            calories: calories,
            fatG: estimate?.fatG ?? 0,
            carbsG: estimate?.carbsG ?? 0,
            fiberG: estimate?.fiberG ?? 0,
            sugarG: estimate?.sugarG ?? 0,
            sodiumMg: estimate?.sodiumMg ?? 0,
            ironMg: estimate?.ironMg ?? 0,
            calciumMg: estimate?.calciumMg ?? 0,
            magnesiumMg: estimate?.magnesiumMg ?? 0,
            zincMg: estimate?.zincMg ?? 0,
            vitaminDMcg: estimate?.vitaminDMcg ?? 0,
            potassiumMg: estimate?.potassiumMg ?? 0,
            vitaminCMg: estimate?.vitaminCMg ?? 0
        )
        context.insert(meal)
        meal.nutritionLog = log
        log.meals.append(meal)
        log.recalculateTotals()
        try? context.save()
        load(context: context)
        mealVersion += 1
        appStateRef?.dataRefreshTrigger = UUID()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Add manual meal

    func addManualMeal(context: ModelContext) {
        let protein = Double(mealProtein) ?? 0
        let calories = Double(mealCalories) ?? 0
        guard !mealFood.isEmpty else { return }

        addMeal(
            name: mealName.isEmpty ? "Meal" : mealName,
            food: mealFood,
            protein: protein,
            calories: calories,
            context: context
        )

        // Reset form
        mealName = "Meal"
        mealFood = ""
        mealProtein = ""
        mealCalories = ""
    }

    // MARK: - Save custom template

    func saveMealAsTemplate(_ meal: MealLog, context: ModelContext) {
        let template = CustomMealTemplate(
            name: meal.name,
            food: meal.food,
            protein: meal.protein,
            calories: meal.calories
        )
        context.insert(template)
        try? context.save()
        load(context: context)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func deleteCustomTemplate(_ template: CustomMealTemplate, context: ModelContext) {
        context.delete(template)
        try? context.save()
        load(context: context)
    }

    // MARK: - Delete meal

    func deleteMeal(_ meal: MealLog, context: ModelContext) {
        guard let log = todaysLog else { return }
        log.meals.removeAll { $0.id == meal.id }
        context.delete(meal)
        log.recalculateTotals()
        try? context.save()
        load(context: context)
        mealVersion += 1
        appStateRef?.dataRefreshTrigger = UUID()
    }

    // MARK: - AI Suggestion

    func fetchAISuggestion(apiKey: String, profile: UserProfile) async {
        isFetchingAI = true
        defer { isFetchingAI = false }

        let proteinNeeded = (todaysLog?.proteinTarget ?? 170) - (todaysLog?.totalProtein ?? 0)
        let caloriesLeft = (todaysLog?.calorieTarget ?? 2200) - (todaysLog?.totalCalories ?? 0)
        let sexWord = profile.sexRaw.lowercased() == "female" ? "woman" : "man"

        let system = """
        You are a concise nutrition coach for a \(profile.age)-year-old \(sexWord) whose training goal is \(profile.goal.displayName.lowercased()).
        Keep suggestions practical, realistic serving sizes, and always in a friendly, direct tone. 2-3 sentences max.
        """

        let userMessage = """
        I still need about \(Int(proteinNeeded))g protein and \(Int(caloriesLeft)) calories today.
        What should I eat next? Suggest one specific meal.
        """

        aiSuggestion = await AIService.shared.generate(
            system: system,
            userMessage: userMessage,
            apiKey: apiKey
        )
    }
}
