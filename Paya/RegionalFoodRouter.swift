import Foundation

// MARK: - Regional Food Router
// Selects the local food database based on the user's device language.
// Falls back to the Azerbaijani database when the locale is unrecognised,
// since the app's primary market is Azerbaijan.

enum SupportedRegion: String, CaseIterable {
    case az = "az"   // Azerbaijani
    case tr = "tr"   // Turkish
    case ru = "ru"   // Russian / CIS
    case en = "en"   // English — no regional food DB, uses generic quick-add

    var displayName: String {
        switch self {
        case .az: return "Azərbaycan"
        case .tr: return "Türkiye"
        case .ru: return "Россия / СНГ"
        case .en: return "International"
        }
    }
}

enum RegionalFoodRouter {

    /// Detect the user's region from Locale. Priority:
    /// 1. Explicit app language override (future: UserDefaults key)
    /// 2. Device preferred language
    /// 3. Fallback: .az
    static var currentRegion: SupportedRegion {
        let preferred = Locale.preferredLanguages.first ?? "en"
        let code = String(preferred.prefix(2))
        return SupportedRegion(rawValue: code) ?? .az
    }

    // MARK: - Unified food item

    struct RegionalFood: Identifiable, Hashable {
        let id: String
        let name: String
        let localName: String
        let categoryIcon: String
        let categoryLabel: String
        let proteinPer100g: Double
        let caloriesPer100g: Double
        let carbsPer100g: Double
        let fatPer100g: Double
        let typicalPortionG: Double
        let portionLabel: String

        func nutrition(grams: Double) -> (protein: Double, calories: Double, carbs: Double, fat: Double) {
            let f = grams / 100.0
            return (proteinPer100g * f, caloriesPer100g * f, carbsPer100g * f, fatPer100g * f)
        }
    }

    /// Returns all regional foods for the given (or current) region.
    static func foods(for region: SupportedRegion? = nil) -> [RegionalFood] {
        let r = region ?? currentRegion
        switch r {
        case .az: return azFoods
        case .tr: return trFoods
        case .ru: return ruFoods
        case .en: return azFoods // fallback
        }
    }

    // MARK: - Adapters

    private static var azFoods: [RegionalFood] {
        AzeFoodsData.all.map { f in
            RegionalFood(
                id: f.id, name: f.name, localName: f.nameAz,
                categoryIcon: f.category.icon, categoryLabel: f.category.rawValue,
                proteinPer100g: f.proteinPer100g, caloriesPer100g: f.caloriesPer100g,
                carbsPer100g: f.carbsPer100g, fatPer100g: f.fatPer100g,
                typicalPortionG: f.typicalPortionG, portionLabel: f.portionLabel
            )
        }
    }

    private static var trFoods: [RegionalFood] {
        TrFoodsData.all.map { f in
            RegionalFood(
                id: f.id, name: f.name, localName: f.nameTr,
                categoryIcon: f.category.icon, categoryLabel: f.category.rawValue,
                proteinPer100g: f.proteinPer100g, caloriesPer100g: f.caloriesPer100g,
                carbsPer100g: f.carbsPer100g, fatPer100g: f.fatPer100g,
                typicalPortionG: f.typicalPortionG, portionLabel: f.portionLabel
            )
        }
    }

    private static var ruFoods: [RegionalFood] {
        RuFoodsData.all.map { f in
            RegionalFood(
                id: f.id, name: f.name, localName: f.nameRu,
                categoryIcon: f.category.icon, categoryLabel: f.category.rawValue,
                proteinPer100g: f.proteinPer100g, caloriesPer100g: f.caloriesPer100g,
                carbsPer100g: f.carbsPer100g, fatPer100g: f.fatPer100g,
                typicalPortionG: f.typicalPortionG, portionLabel: f.portionLabel
            )
        }
    }
}
