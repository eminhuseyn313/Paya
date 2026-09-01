import Foundation

// MARK: - Russian / CIS Foods Library
// Curated staples for one-tap quick add. Macros per 100g from
// Russian Ministry of Agriculture nutrient tables and USDA cross-refs.

struct RuFood: Identifiable, Hashable {
    let id: String
    let name: String
    let nameRu: String
    let category: Category
    let proteinPer100g: Double
    let caloriesPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    let typicalPortionG: Double
    let portionLabel: String

    enum Category: String, CaseIterable {
        case protein = "Protein"
        case dairy = "Молочное"
        case grains = "Крупы и хлеб"
        case vegetables = "Овощи и салаты"
        case fruitsNuts = "Фрукты и орехи"
        case soups = "Супы"

        var icon: String {
            switch self {
            case .protein:    return "fish"
            case .dairy:      return "cup.and.saucer"
            case .grains:     return "leaf"
            case .vegetables: return "carrot"
            case .fruitsNuts: return "apple.logo"
            case .soups:      return "takeoutbag.and.cup.and.straw"
            }
        }
    }

    func nutrition(grams: Double) -> (protein: Double, calories: Double, carbs: Double, fat: Double) {
        let f = grams / 100.0
        return (proteinPer100g * f, caloriesPer100g * f, carbsPer100g * f, fatPer100g * f)
    }
}

enum RuFoodsData {

    static let all: [RuFood] = [

        // ── PROTEIN ──
        RuFood(id: "ru_chicken_breast", name: "Chicken Breast (boiled)", nameRu: "Куриная грудка",
               category: .protein, proteinPer100g: 29, caloriesPer100g: 137, carbsPer100g: 0, fatPer100g: 1.8,
               typicalPortionG: 150, portionLabel: "1 порция"),
        RuFood(id: "ru_beef_stew", name: "Beef Stew", nameRu: "Тушёная говядина",
               category: .protein, proteinPer100g: 20, caloriesPer100g: 180, carbsPer100g: 3, fatPer100g: 10,
               typicalPortionG: 200, portionLabel: "1 порция"),
        RuFood(id: "ru_pelmeni", name: "Pelmeni (meat dumplings)", nameRu: "Пельмени",
               category: .protein, proteinPer100g: 12, caloriesPer100g: 220, carbsPer100g: 25, fatPer100g: 8,
               typicalPortionG: 200, portionLabel: "15 шт"),
        RuFood(id: "ru_salmon", name: "Baked Salmon", nameRu: "Запечённый лосось",
               category: .protein, proteinPer100g: 22, caloriesPer100g: 180, carbsPer100g: 0, fatPer100g: 10,
               typicalPortionG: 150, portionLabel: "1 стейк"),
        RuFood(id: "ru_eggs", name: "Boiled Eggs", nameRu: "Варёные яйца",
               category: .protein, proteinPer100g: 13, caloriesPer100g: 155, carbsPer100g: 1.1, fatPer100g: 11,
               typicalPortionG: 100, portionLabel: "2 шт"),
        RuFood(id: "ru_kotlety", name: "Cutlets (chicken)", nameRu: "Куриные котлеты",
               category: .protein, proteinPer100g: 18, caloriesPer100g: 195, carbsPer100g: 8, fatPer100g: 10,
               typicalPortionG: 120, portionLabel: "2 шт"),

        // ── DAIRY ──
        RuFood(id: "ru_tvorog", name: "Tvorog (cottage cheese)", nameRu: "Творог 5%",
               category: .dairy, proteinPer100g: 17, caloriesPer100g: 120, carbsPer100g: 2, fatPer100g: 5,
               typicalPortionG: 200, portionLabel: "1 пачка"),
        RuFood(id: "ru_kefir", name: "Kefir 1%", nameRu: "Кефир 1%",
               category: .dairy, proteinPer100g: 3, caloriesPer100g: 40, carbsPer100g: 4, fatPer100g: 1,
               typicalPortionG: 250, portionLabel: "1 стакан"),
        RuFood(id: "ru_ryazhenka", name: "Ryazhenka (baked milk)", nameRu: "Ряженка",
               category: .dairy, proteinPer100g: 3, caloriesPer100g: 55, carbsPer100g: 4, fatPer100g: 3,
               typicalPortionG: 250, portionLabel: "1 стакан"),
        RuFood(id: "ru_smetana", name: "Smetana (sour cream) 15%", nameRu: "Сметана 15%",
               category: .dairy, proteinPer100g: 2.5, caloriesPer100g: 160, carbsPer100g: 3, fatPer100g: 15,
               typicalPortionG: 30, portionLabel: "2 ст. ложки"),
        RuFood(id: "ru_adygeysky", name: "Adyghe Cheese", nameRu: "Адыгейский сыр",
               category: .dairy, proteinPer100g: 18, caloriesPer100g: 240, carbsPer100g: 2, fatPer100g: 16,
               typicalPortionG: 60, portionLabel: "2 ломтика"),

        // ── GRAINS ──
        RuFood(id: "ru_buckwheat", name: "Buckwheat (cooked)", nameRu: "Гречневая каша",
               category: .grains, proteinPer100g: 4.5, caloriesPer100g: 110, carbsPer100g: 21, fatPer100g: 1.1,
               typicalPortionG: 200, portionLabel: "1 порция"),
        RuFood(id: "ru_ovsyanka", name: "Oatmeal (cooked)", nameRu: "Овсяная каша",
               category: .grains, proteinPer100g: 2.5, caloriesPer100g: 70, carbsPer100g: 12, fatPer100g: 1.4,
               typicalPortionG: 250, portionLabel: "1 тарелка"),
        RuFood(id: "ru_black_bread", name: "Dark Rye Bread", nameRu: "Чёрный хлеб",
               category: .grains, proteinPer100g: 6.5, caloriesPer100g: 220, carbsPer100g: 42, fatPer100g: 1.5,
               typicalPortionG: 40, portionLabel: "1 ломтик"),
        RuFood(id: "ru_rice", name: "Rice (cooked)", nameRu: "Рис отварной",
               category: .grains, proteinPer100g: 2.7, caloriesPer100g: 130, carbsPer100g: 28, fatPer100g: 0.3,
               typicalPortionG: 200, portionLabel: "1 порция"),
        RuFood(id: "ru_blini", name: "Blini (thin pancakes)", nameRu: "Блины",
               category: .grains, proteinPer100g: 6, caloriesPer100g: 190, carbsPer100g: 28, fatPer100g: 6,
               typicalPortionG: 100, portionLabel: "2 шт"),

        // ── VEG & SALAD ──
        RuFood(id: "ru_vinegret", name: "Vinegret (beet salad)", nameRu: "Винегрет",
               category: .vegetables, proteinPer100g: 1.5, caloriesPer100g: 75, carbsPer100g: 10, fatPer100g: 3,
               typicalPortionG: 200, portionLabel: "1 порция"),
        RuFood(id: "ru_olivye", name: "Olivye Salad", nameRu: "Оливье",
               category: .vegetables, proteinPer100g: 4, caloriesPer100g: 140, carbsPer100g: 8, fatPer100g: 10,
               typicalPortionG: 200, portionLabel: "1 порция"),
        RuFood(id: "ru_svekolnik", name: "Fresh Vegetables Plate", nameRu: "Овощная нарезка",
               category: .vegetables, proteinPer100g: 1.5, caloriesPer100g: 30, carbsPer100g: 5, fatPer100g: 0.3,
               typicalPortionG: 150, portionLabel: "1 тарелка"),
        RuFood(id: "ru_kapusta", name: "Sauerkraut", nameRu: "Квашеная капуста",
               category: .vegetables, proteinPer100g: 1, caloriesPer100g: 20, carbsPer100g: 4, fatPer100g: 0.1,
               typicalPortionG: 100, portionLabel: "1 порция"),

        // ── FRUITS & NUTS ──
        RuFood(id: "ru_apple", name: "Apple", nameRu: "Яблоко",
               category: .fruitsNuts, proteinPer100g: 0.3, caloriesPer100g: 52, carbsPer100g: 14, fatPer100g: 0.2,
               typicalPortionG: 180, portionLabel: "1 шт"),
        RuFood(id: "ru_berries", name: "Mixed Berries", nameRu: "Ягоды (смесь)",
               category: .fruitsNuts, proteinPer100g: 1, caloriesPer100g: 50, carbsPer100g: 12, fatPer100g: 0.3,
               typicalPortionG: 100, portionLabel: "1 горсть"),
        RuFood(id: "ru_sunflower_seeds", name: "Sunflower Seeds", nameRu: "Семечки",
               category: .fruitsNuts, proteinPer100g: 21, caloriesPer100g: 580, carbsPer100g: 20, fatPer100g: 51,
               typicalPortionG: 30, portionLabel: "1 горсть"),
        RuFood(id: "ru_cedar_nuts", name: "Pine Nuts", nameRu: "Кедровые орехи",
               category: .fruitsNuts, proteinPer100g: 14, caloriesPer100g: 670, carbsPer100g: 13, fatPer100g: 68,
               typicalPortionG: 20, portionLabel: "1 ст. ложка"),

        // ── SOUPS ──
        RuFood(id: "ru_borsch", name: "Borscht", nameRu: "Борщ",
               category: .soups, proteinPer100g: 3, caloriesPer100g: 50, carbsPer100g: 5, fatPer100g: 2,
               typicalPortionG: 350, portionLabel: "1 тарелка"),
        RuFood(id: "ru_shchi", name: "Shchi (cabbage soup)", nameRu: "Щи",
               category: .soups, proteinPer100g: 2, caloriesPer100g: 35, carbsPer100g: 4, fatPer100g: 1.5,
               typicalPortionG: 350, portionLabel: "1 тарелка"),
        RuFood(id: "ru_solyanka", name: "Solyanka (mixed meat soup)", nameRu: "Солянка",
               category: .soups, proteinPer100g: 5, caloriesPer100g: 70, carbsPer100g: 3, fatPer100g: 4,
               typicalPortionG: 350, portionLabel: "1 тарелка"),
        RuFood(id: "ru_ukha", name: "Ukha (fish soup)", nameRu: "Уха",
               category: .soups, proteinPer100g: 5, caloriesPer100g: 45, carbsPer100g: 3, fatPer100g: 1.5,
               typicalPortionG: 350, portionLabel: "1 тарелка")
    ]

    static func byCategory(_ category: RuFood.Category) -> [RuFood] {
        all.filter { $0.category == category }
    }
}
