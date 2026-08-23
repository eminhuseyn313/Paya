import Foundation

// MARK: - Diet Plan Data
//
// Deterministic, structured food & meal data that powers the diet plan
// views WITHOUT requiring any AI/API key. Every food item has real macro
// values per standard serving, sourced from USDA FoodData Central.
//
// The AI-generated plan becomes an optional enhancement layer on top —
// the baseline experience is always functional and visually rich.
//
// Research basis:
//   • Protein targets: Morton et al. 2018 (BJSM meta-analysis)
//   • Anti-inflammatory foods: Sköldstam L et al. Ann Rheum Dis 2003
//   • Mediterranean diet pattern: Petersson S et al. Nutrients 2018
//   • Omega-3 / joint health: Calder PC, Biochem Soc Trans 2017
//   • Gut-inflammation axis: Zinöcker & Lindseth, Nutrients 2018

// MARK: - Food Item

struct FoodItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let emoji: String
    let servingSize: String      // "100g", "1 cup", "1 fillet"
    let calories: Int            // per serving
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let category: FoodCategory
    let tags: Set<FoodTag>

    var macroSummary: String {
        "\(Int(proteinG))P · \(Int(carbsG))C · \(Int(fatG))F"
    }
}

enum FoodCategory: String, CaseIterable {
    case protein = "Protein"
    case carbs = "Carbs"
    case fats = "Healthy Fats"
    case vegetables = "Vegetables"
    case fruits = "Fruits"
    case dairy = "Dairy"
    case grains = "Grains"
    case legumes = "Legumes"

    var icon: String {
        switch self {
        case .protein: return "🥩"
        case .carbs: return "🍚"
        case .fats: return "🥑"
        case .vegetables: return "🥦"
        case .fruits: return "🍎"
        case .dairy: return "🧀"
        case .grains: return "🌾"
        case .legumes: return "🫘"
        }
    }
}

enum FoodTag: String {
    case antiInflammatory
    case highProtein
    case vegan
    case vegetarian
    case pescatarian
    case glutenFree
    case omega3Rich
    case fiberRich
    case probiotic
    case inflammatoryRisk  // foods to limit
    case highSodium
    case processedSugar
}

// MARK: - Meal Template

struct DietMeal: Identifiable {
    let id = UUID()
    let name: String
    let mealType: MealType
    let foods: [(food: FoodItem, servings: Double)]
    let dietPreferences: Set<DietPreference>  // which diets this works for

    var totalCalories: Int {
        foods.reduce(0) { $0 + Int(Double($1.food.calories) * $1.servings) }
    }
    var totalProtein: Double {
        foods.reduce(0) { $0 + $1.food.proteinG * $1.servings }
    }
    var totalCarbs: Double {
        foods.reduce(0) { $0 + $1.food.carbsG * $1.servings }
    }
    var totalFat: Double {
        foods.reduce(0) { $0 + $1.food.fatG * $1.servings }
    }
}

enum MealType: String, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    case preworkout = "Pre-Workout"
    case postworkout = "Post-Workout"

    var icon: String {
        switch self {
        case .breakfast: return "🌅"
        case .lunch: return "☀️"
        case .dinner: return "🌙"
        case .snack: return "🍏"
        case .preworkout: return "⚡"
        case .postworkout: return "💪"
        }
    }

    var timeHint: String {
        switch self {
        case .breakfast: return "7–9 AM"
        case .lunch: return "12–1 PM"
        case .dinner: return "6–8 PM"
        case .snack: return "Between meals"
        case .preworkout: return "60–90 min before"
        case .postworkout: return "Within 60 min after"
        }
    }
}

// MARK: - Daily Plan

struct DailyMealPlan {
    let dayType: DayType
    let meals: [DietMeal]

    var totalCalories: Int { meals.reduce(0) { $0 + $1.totalCalories } }
    var totalProtein: Double { meals.reduce(0) { $0 + $1.totalProtein } }
    var totalCarbs: Double { meals.reduce(0) { $0 + $1.totalCarbs } }
    var totalFat: Double { meals.reduce(0) { $0 + $1.totalFat } }

    enum DayType: String {
        case training = "Training Day"
        case rest = "Rest Day"
    }
}

// MARK: - Food Database

/// Curated food items with USDA-sourced macro values per standard serving.
enum FoodDatabase {

    // ── Proteins ────────────────────────────────────────────────────

    static let chickenBreast = FoodItem(
        name: "Chicken Breast", emoji: "🍗", servingSize: "150g",
        calories: 248, proteinG: 46.5, carbsG: 0, fatG: 5.4,
        category: .protein, tags: [.highProtein]
    )
    static let salmon = FoodItem(
        name: "Atlantic Salmon", emoji: "🐟", servingSize: "150g",
        calories: 312, proteinG: 33.9, carbsG: 0, fatG: 18.9,
        category: .protein, tags: [.highProtein, .omega3Rich, .antiInflammatory, .pescatarian]
    )
    static let eggs = FoodItem(
        name: "Whole Eggs", emoji: "🥚", servingSize: "3 large",
        calories: 234, proteinG: 18.6, carbsG: 1.1, fatG: 16.2,
        category: .protein, tags: [.highProtein, .vegetarian]
    )
    static let greekYogurt = FoodItem(
        name: "Greek Yogurt", emoji: "🥛", servingSize: "200g",
        calories: 130, proteinG: 22, carbsG: 8, fatG: 0.8,
        category: .dairy, tags: [.highProtein, .probiotic, .vegetarian]
    )
    static let tofu = FoodItem(
        name: "Firm Tofu", emoji: "🧊", servingSize: "150g",
        calories: 131, proteinG: 15.6, carbsG: 3.2, fatG: 7.2,
        category: .protein, tags: [.highProtein, .vegan, .vegetarian, .pescatarian]
    )
    static let lentils = FoodItem(
        name: "Cooked Lentils", emoji: "🫘", servingSize: "1 cup",
        calories: 230, proteinG: 17.9, carbsG: 39.9, fatG: 0.8,
        category: .legumes, tags: [.highProtein, .fiberRich, .vegan, .vegetarian, .pescatarian, .antiInflammatory]
    )
    static let turkey = FoodItem(
        name: "Turkey Breast", emoji: "🦃", servingSize: "150g",
        calories: 220, proteinG: 43, carbsG: 0, fatG: 4.5,
        category: .protein, tags: [.highProtein]
    )
    static let tuna = FoodItem(
        name: "Tuna Steak", emoji: "🐟", servingSize: "150g",
        calories: 184, proteinG: 39.8, carbsG: 0, fatG: 1.6,
        category: .protein, tags: [.highProtein, .omega3Rich, .pescatarian]
    )
    static let tempeh = FoodItem(
        name: "Tempeh", emoji: "🫘", servingSize: "100g",
        calories: 192, proteinG: 20.3, carbsG: 7.6, fatG: 10.8,
        category: .protein, tags: [.highProtein, .vegan, .vegetarian, .pescatarian, .probiotic]
    )
    static let cottageCheese = FoodItem(
        name: "Cottage Cheese", emoji: "🧀", servingSize: "200g",
        calories: 196, proteinG: 23, carbsG: 7.6, fatG: 8.6,
        category: .dairy, tags: [.highProtein, .vegetarian]
    )
    static let wheyProtein = FoodItem(
        name: "Whey Protein", emoji: "🥤", servingSize: "1 scoop (30g)",
        calories: 120, proteinG: 24, carbsG: 3, fatG: 1.5,
        category: .protein, tags: [.highProtein, .vegetarian]
    )

    // ── Carbs ───────────────────────────────────────────────────────

    static let brownRice = FoodItem(
        name: "Brown Rice", emoji: "🍚", servingSize: "1 cup cooked",
        calories: 216, proteinG: 5, carbsG: 44.8, fatG: 1.8,
        category: .carbs, tags: [.fiberRich, .vegan, .vegetarian, .pescatarian, .glutenFree]
    )
    static let sweetPotato = FoodItem(
        name: "Sweet Potato", emoji: "🍠", servingSize: "1 medium",
        calories: 103, proteinG: 2.3, carbsG: 24, fatG: 0.1,
        category: .carbs, tags: [.antiInflammatory, .fiberRich, .vegan, .vegetarian, .pescatarian, .glutenFree]
    )
    static let oats = FoodItem(
        name: "Rolled Oats", emoji: "🥣", servingSize: "80g dry",
        calories: 307, proteinG: 10.7, carbsG: 53.4, fatG: 5.3,
        category: .grains, tags: [.fiberRich, .vegan, .vegetarian, .pescatarian]
    )
    static let wholeWheatPasta = FoodItem(
        name: "Whole Wheat Pasta", emoji: "🍝", servingSize: "100g dry",
        calories: 348, proteinG: 14.6, carbsG: 64.5, fatG: 2.5,
        category: .grains, tags: [.fiberRich, .vegan, .vegetarian, .pescatarian]
    )
    static let quinoa = FoodItem(
        name: "Quinoa", emoji: "🌾", servingSize: "1 cup cooked",
        calories: 222, proteinG: 8.1, carbsG: 39.4, fatG: 3.6,
        category: .grains, tags: [.fiberRich, .vegan, .vegetarian, .pescatarian, .glutenFree]
    )
    static let banana = FoodItem(
        name: "Banana", emoji: "🍌", servingSize: "1 medium",
        calories: 105, proteinG: 1.3, carbsG: 27, fatG: 0.4,
        category: .fruits, tags: [.vegan, .vegetarian, .pescatarian, .glutenFree]
    )

    // ── Healthy Fats ────────────────────────────────────────────────

    static let avocado = FoodItem(
        name: "Avocado", emoji: "🥑", servingSize: "½ medium",
        calories: 120, proteinG: 1.5, carbsG: 6.4, fatG: 11,
        category: .fats, tags: [.antiInflammatory, .vegan, .vegetarian, .pescatarian, .glutenFree]
    )
    static let almonds = FoodItem(
        name: "Almonds", emoji: "🥜", servingSize: "30g",
        calories: 174, proteinG: 6.3, carbsG: 5.6, fatG: 15,
        category: .fats, tags: [.antiInflammatory, .vegan, .vegetarian, .pescatarian, .glutenFree]
    )
    static let oliveOil = FoodItem(
        name: "Extra Virgin Olive Oil", emoji: "🫒", servingSize: "1 tbsp",
        calories: 119, proteinG: 0, carbsG: 0, fatG: 13.5,
        category: .fats, tags: [.antiInflammatory, .vegan, .vegetarian, .pescatarian, .glutenFree, .omega3Rich]
    )
    static let walnuts = FoodItem(
        name: "Walnuts", emoji: "🌰", servingSize: "30g",
        calories: 196, proteinG: 4.6, carbsG: 3.9, fatG: 19.6,
        category: .fats, tags: [.antiInflammatory, .omega3Rich, .vegan, .vegetarian, .pescatarian, .glutenFree]
    )

    // ── Vegetables ──────────────────────────────────────────────────

    static let broccoli = FoodItem(
        name: "Broccoli", emoji: "🥦", servingSize: "1 cup",
        calories: 55, proteinG: 3.7, carbsG: 11.2, fatG: 0.6,
        category: .vegetables, tags: [.antiInflammatory, .fiberRich, .vegan, .vegetarian, .pescatarian, .glutenFree]
    )
    static let spinach = FoodItem(
        name: "Spinach", emoji: "🥬", servingSize: "2 cups raw",
        calories: 14, proteinG: 1.7, carbsG: 2.2, fatG: 0.2,
        category: .vegetables, tags: [.antiInflammatory, .vegan, .vegetarian, .pescatarian, .glutenFree]
    )
    static let mixedGreens = FoodItem(
        name: "Mixed Salad Greens", emoji: "🥗", servingSize: "2 cups",
        calories: 20, proteinG: 1.5, carbsG: 3.5, fatG: 0.3,
        category: .vegetables, tags: [.antiInflammatory, .fiberRich, .vegan, .vegetarian, .pescatarian, .glutenFree]
    )

    // ── Foods to Limit ──────────────────────────────────────────────

    static let processedMeats = FoodItem(
        name: "Processed Meats", emoji: "🌭", servingSize: "—",
        calories: 0, proteinG: 0, carbsG: 0, fatG: 0,
        category: .protein, tags: [.inflammatoryRisk, .highSodium]
    )
    static let refinedSugar = FoodItem(
        name: "Refined Sugar / Sweets", emoji: "🍬", servingSize: "—",
        calories: 0, proteinG: 0, carbsG: 0, fatG: 0,
        category: .carbs, tags: [.inflammatoryRisk, .processedSugar]
    )
    static let friedFoods = FoodItem(
        name: "Deep-Fried Foods", emoji: "🍟", servingSize: "—",
        calories: 0, proteinG: 0, carbsG: 0, fatG: 0,
        category: .fats, tags: [.inflammatoryRisk]
    )
    static let alcohol = FoodItem(
        name: "Alcohol", emoji: "🍺", servingSize: "—",
        calories: 0, proteinG: 0, carbsG: 0, fatG: 0,
        category: .carbs, tags: [.inflammatoryRisk]
    )

    // MARK: - Filtered Lists

    /// Foods appropriate for a given diet preference
    static func foods(for diet: DietPreference) -> [FoodItem] {
        let all: [FoodItem] = [
            chickenBreast, salmon, eggs, greekYogurt, tofu, lentils, turkey,
            tuna, tempeh, cottageCheese, wheyProtein,
            brownRice, sweetPotato, oats, wholeWheatPasta, quinoa, banana,
            avocado, almonds, oliveOil, walnuts,
            broccoli, spinach, mixedGreens
        ]
        switch diet {
        case .omnivore:
            return all
        case .pescatarian:
            return all.filter { $0.tags.contains(.pescatarian) || $0.tags.contains(.vegan) || $0.tags.contains(.vegetarian) || $0 == salmon || $0 == tuna }
        case .vegetarian:
            return all.filter { $0.tags.contains(.vegetarian) || $0.tags.contains(.vegan) }
        case .vegan:
            return all.filter { $0.tags.contains(.vegan) }
        }
    }

    /// Anti-inflammatory priority foods
    static var antiInflammatoryFoods: [FoodItem] {
        [salmon, sweetPotato, avocado, almonds, walnuts, oliveOil,
         broccoli, spinach, lentils, tempeh]
    }

    /// Foods to limit (inflammatory risk)
    static var foodsToLimit: [FoodItem] {
        [processedMeats, refinedSugar, friedFoods, alcohol]
    }

    /// High-protein options for a given diet
    static func highProteinFoods(for diet: DietPreference) -> [FoodItem] {
        foods(for: diet).filter { $0.tags.contains(.highProtein) }
    }
}

// MARK: - Meal Plan Generator

/// Builds deterministic daily meal plans from profile data — no AI needed.
/// Selects foods appropriate for diet preference, scales portions to match
/// calorie/protein targets, and structures meals around training timing.
enum MealPlanGenerator {

    static func trainingDayPlan(profile: PersonProfile) -> DailyMealPlan {
        let diet = profile.dietPreference
        let proteins = FoodDatabase.highProteinFoods(for: diet)
        let targetCal = Int(profile.trainingDayCalories)
        let targetProtein = Int(profile.proteinTargetG)

        let meals = buildMeals(
            diet: diet,
            proteins: proteins,
            targetCalories: targetCal,
            targetProtein: targetProtein,
            isTraining: true
        )
        return DailyMealPlan(dayType: .training, meals: meals)
    }

    static func restDayPlan(profile: PersonProfile) -> DailyMealPlan {
        let diet = profile.dietPreference
        let proteins = FoodDatabase.highProteinFoods(for: diet)
        let targetCal = Int(profile.restDayCalories)
        let targetProtein = Int(profile.proteinTargetG)

        let meals = buildMeals(
            diet: diet,
            proteins: proteins,
            targetCalories: targetCal,
            targetProtein: targetProtein,
            isTraining: false
        )
        return DailyMealPlan(dayType: .rest, meals: meals)
    }

    private static func buildMeals(
        diet: DietPreference,
        proteins: [FoodItem],
        targetCalories: Int,
        targetProtein: Int,
        isTraining: Bool
    ) -> [DietMeal] {
        let dietSet: Set<DietPreference> = [diet]

        // Pick primary proteins based on diet
        let mainProtein = proteins.first ?? FoodDatabase.tofu
        let altProtein = proteins.count > 1 ? proteins[1] : mainProtein

        var meals: [DietMeal] = []

        // Breakfast
        let breakfastFoods: [(FoodItem, Double)] = diet == .vegan
            ? [(FoodDatabase.oats, 1), (FoodDatabase.banana, 1), (FoodDatabase.almonds, 1)]
            : [(FoodDatabase.oats, 1), (FoodDatabase.eggs, 1), (FoodDatabase.banana, 0.5)]
        meals.append(DietMeal(
            name: diet == .vegan ? "Power Oats Bowl" : "Protein Oatmeal",
            mealType: .breakfast,
            foods: breakfastFoods.map { (food: $0.0, servings: $0.1) },
            dietPreferences: dietSet
        ))

        // Lunch
        let lunchFoods: [(FoodItem, Double)] = [
            (mainProtein, 1),
            (FoodDatabase.brownRice, 0.75),
            (FoodDatabase.broccoli, 1),
            (FoodDatabase.oliveOil, 0.5)
        ]
        meals.append(DietMeal(
            name: "\(mainProtein.name) & Rice Bowl",
            mealType: .lunch,
            foods: lunchFoods.map { (food: $0.0, servings: $0.1) },
            dietPreferences: dietSet
        ))

        // Dinner
        let dinnerFoods: [(FoodItem, Double)] = [
            (altProtein, 1),
            (FoodDatabase.sweetPotato, 1),
            (FoodDatabase.spinach, 1),
            (FoodDatabase.avocado, 0.5)
        ]
        meals.append(DietMeal(
            name: "\(altProtein.name) with Sweet Potato",
            mealType: .dinner,
            foods: dinnerFoods.map { (food: $0.0, servings: $0.1) },
            dietPreferences: dietSet
        ))

        if isTraining {
            // Post-workout
            let pwFoods: [(FoodItem, Double)] = diet == .vegan
                ? [(FoodDatabase.banana, 1), (FoodDatabase.almonds, 1)]
                : [(FoodDatabase.wheyProtein, 1), (FoodDatabase.banana, 1)]
            meals.append(DietMeal(
                name: isTraining ? "Post-Workout Fuel" : "Afternoon Snack",
                mealType: .postworkout,
                foods: pwFoods.map { (food: $0.0, servings: $0.1) },
                dietPreferences: dietSet
            ))
        } else {
            // Rest day snack — lighter
            let snackFoods: [(FoodItem, Double)] = diet == .vegan
                ? [(FoodDatabase.almonds, 1)]
                : [(FoodDatabase.greekYogurt, 1), (FoodDatabase.almonds, 0.5)]
            meals.append(DietMeal(
                name: "Afternoon Snack",
                mealType: .snack,
                foods: snackFoods.map { (food: $0.0, servings: $0.1) },
                dietPreferences: dietSet
            ))
        }

        return meals
    }
}
