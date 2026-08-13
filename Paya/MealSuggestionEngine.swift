import Foundation

// MARK: - Meal Suggestion Engine
//
// "What should I eat next" answered instantly from a curated food list
// scored against today's actual remaining protein/calorie gap — no AI call,
// no API key, no network wait. The existing AI Suggestion card is one
// free-text sentence and silently does nothing without a configured key;
// this is the reliable, always-available complement, the same way
// ExercisePool is the generative alternative to hand-authored templates.

struct FoodOption: Identifiable {
    let name: String
    let proteinG: Double
    let calories: Double
    let servingNote: String
    let dietTags: Set<DietPreference>   // diets this food fits; empty = fits every diet

    var id: String { name }

    func fits(_ diet: DietPreference) -> Bool {
        dietTags.isEmpty || dietTags.contains(diet)
    }
}

enum MealSuggestionEngine {

    static let options: [FoodOption] = [
        FoodOption(name: "Greek yogurt (1 cup) + honey", proteinG: 20, calories: 180, servingNote: "1 cup plain 2%", dietTags: [.omnivore, .vegetarian, .pescatarian]),
        FoodOption(name: "Grilled chicken breast", proteinG: 35, calories: 190, servingNote: "150g cooked", dietTags: [.omnivore, .pescatarian]),
        FoodOption(name: "Canned tuna (in water)", proteinG: 26, calories: 130, servingNote: "1 can, drained", dietTags: [.omnivore, .pescatarian]),
        FoodOption(name: "3 whole eggs", proteinG: 18, calories: 220, servingNote: "3 large eggs", dietTags: [.omnivore, .vegetarian, .pescatarian]),
        FoodOption(name: "Cottage cheese (1 cup)", proteinG: 25, calories: 180, servingNote: "1 cup low-fat", dietTags: [.omnivore, .vegetarian, .pescatarian]),
        FoodOption(name: "Whey protein shake", proteinG: 25, calories: 130, servingNote: "1 scoop + water", dietTags: [.omnivore, .vegetarian, .pescatarian]),
        FoodOption(name: "Salmon fillet", proteinG: 34, calories: 280, servingNote: "150g cooked", dietTags: [.omnivore, .pescatarian]),
        FoodOption(name: "Lentils (1 cup, cooked)", proteinG: 18, calories: 230, servingNote: "1 cup cooked", dietTags: []),
        FoodOption(name: "Firm tofu, pan-seared", proteinG: 20, calories: 190, servingNote: "200g", dietTags: []),
        FoodOption(name: "Edamame (1 cup)", proteinG: 17, calories: 190, servingNote: "1 cup, shelled", dietTags: []),
        FoodOption(name: "Turkey breast slices", proteinG: 24, calories: 120, servingNote: "100g", dietTags: [.omnivore, .pescatarian]),
        FoodOption(name: "Protein bar", proteinG: 20, calories: 210, servingNote: "1 bar, typical brand", dietTags: [.omnivore, .vegetarian, .vegan, .pescatarian]),
        FoodOption(name: "Chickpeas (1 cup, cooked)", proteinG: 15, calories: 270, servingNote: "1 cup cooked", dietTags: []),
        FoodOption(name: "Tempeh, pan-seared", proteinG: 20, calories: 220, servingNote: "150g", dietTags: []),
        FoodOption(name: "Skyr (1 cup)", proteinG: 22, calories: 140, servingNote: "1 cup plain", dietTags: [.omnivore, .vegetarian, .pescatarian]),
        FoodOption(name: "Lean beef mince (5% fat)", proteinG: 32, calories: 220, servingNote: "150g cooked", dietTags: [.omnivore]),
        FoodOption(name: "Shrimp, sautéed", proteinG: 28, calories: 150, servingNote: "150g", dietTags: [.omnivore, .pescatarian]),
        FoodOption(name: "Seitan, pan-fried", proteinG: 30, calories: 180, servingNote: "100g", dietTags: [.vegetarian, .vegan])
    ]

    /// Ranks foods by how well they'd close today's remaining protein gap
    /// without blowing past the remaining calorie budget — scored, not just
    /// filtered, so a slight calorie overshoot for a much better protein
    /// match still surfaces near the top rather than getting excluded outright.
    static func suggest(
        remainingProteinG: Double,
        remainingCalories: Double,
        dietPreference: DietPreference,
        count: Int = 4
    ) -> [FoodOption] {
        let fitting = options.filter { $0.fits(dietPreference) }
        guard remainingProteinG > 0 else { return [] }

        func score(_ option: FoodOption) -> Double {
            // How much of the remaining protein gap this closes (capped at
            // 1.0 — overshooting protein isn't a downside worth rewarding
            // further) minus a penalty for blowing past remaining calories.
            let proteinCoverage = min(option.proteinG / remainingProteinG, 1.0)
            let calorieOvershoot = remainingCalories > 0
                ? max(0, (option.calories - remainingCalories) / remainingCalories)
                : 0
            return proteinCoverage - calorieOvershoot * 0.5
        }

        return fitting
            .sorted { score($0) > score($1) }
            .prefix(count)
            .map { $0 }
    }
}
