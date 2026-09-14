import Foundation

// MARK: - Turkish Foods Library
// Curated staples for one-tap quick add. Macros per 100g from TürKomp
// (Turkish Food Composition Database, tubitak.gov.tr) and USDA cross-refs.

struct TrFood: Identifiable, Hashable {
    let id: String
    let name: String
    let nameTr: String
    let category: Category
    let proteinPer100g: Double
    let caloriesPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    let typicalPortionG: Double
    let portionLabel: String

    enum Category: String, CaseIterable {
        case protein = "Protein"
        case dairy = "Süt Ürünleri"
        case grains = "Tahıllar"
        case vegetables = "Sebze & Salata"
        case fruitsNuts = "Meyve & Kuruyemiş"
        case soups = "Çorbalar"
        case breakfast = "Kahvaltı"

        var icon: String {
            switch self {
            case .protein:    return "fish"
            case .dairy:      return "cup.and.saucer"
            case .grains:     return "leaf"
            case .vegetables: return "carrot"
            case .fruitsNuts: return "tree"
            case .soups:      return "takeoutbag.and.cup.and.straw"
            case .breakfast:  return "sun.horizon"
            }
        }
    }

    func nutrition(grams: Double) -> (protein: Double, calories: Double, carbs: Double, fat: Double) {
        let f = grams / 100.0
        return (proteinPer100g * f, caloriesPer100g * f, carbsPer100g * f, fatPer100g * f)
    }
}

enum TrFoodsData {

    static let all: [TrFood] = [

        // ── PROTEIN ──
        TrFood(id: "tr_chicken_breast", name: "Grilled Chicken Breast", nameTr: "Izgara tavuk göğsü",
               category: .protein, proteinPer100g: 31, caloriesPer100g: 165, carbsPer100g: 0, fatPer100g: 3.6,
               typicalPortionG: 150, portionLabel: "1 porsiyon"),
        TrFood(id: "tr_kofte", name: "Grilled Köfte", nameTr: "Izgara köfte",
               category: .protein, proteinPer100g: 18, caloriesPer100g: 235, carbsPer100g: 5, fatPer100g: 16,
               typicalPortionG: 120, portionLabel: "3 adet"),
        TrFood(id: "tr_adana", name: "Adana Kebab", nameTr: "Adana kebabı",
               category: .protein, proteinPer100g: 17, caloriesPer100g: 250, carbsPer100g: 2, fatPer100g: 19,
               typicalPortionG: 150, portionLabel: "1 şiş"),
        TrFood(id: "tr_fish_sea_bass", name: "Grilled Sea Bass", nameTr: "Izgara levrek",
               category: .protein, proteinPer100g: 21, caloriesPer100g: 110, carbsPer100g: 0, fatPer100g: 3,
               typicalPortionG: 200, portionLabel: "1 porsiyon"),
        TrFood(id: "tr_eggs", name: "Boiled Eggs", nameTr: "Haşlanmış yumurta",
               category: .protein, proteinPer100g: 13, caloriesPer100g: 155, carbsPer100g: 1.1, fatPer100g: 11,
               typicalPortionG: 100, portionLabel: "2 adet"),
        TrFood(id: "tr_kuru_fasulye", name: "White Bean Stew", nameTr: "Kuru fasulye",
               category: .protein, proteinPer100g: 6, caloriesPer100g: 100, carbsPer100g: 14, fatPer100g: 2,
               typicalPortionG: 250, portionLabel: "1 porsiyon"),

        // ── DAIRY ──
        TrFood(id: "tr_yogurt", name: "Plain Yogurt", nameTr: "Yoğurt",
               category: .dairy, proteinPer100g: 3.5, caloriesPer100g: 60, carbsPer100g: 4.5, fatPer100g: 3.2,
               typicalPortionG: 200, portionLabel: "1 kase"),
        TrFood(id: "tr_ayran", name: "Ayran", nameTr: "Ayran",
               category: .dairy, proteinPer100g: 1.7, caloriesPer100g: 24, carbsPer100g: 2.2, fatPer100g: 1,
               typicalPortionG: 250, portionLabel: "1 bardak"),
        TrFood(id: "tr_beyaz_peynir", name: "White Cheese (Feta-style)", nameTr: "Beyaz peynir",
               category: .dairy, proteinPer100g: 17, caloriesPer100g: 260, carbsPer100g: 1, fatPer100g: 21,
               typicalPortionG: 50, portionLabel: "2 dilim"),
        TrFood(id: "tr_kasar", name: "Kaşar Cheese", nameTr: "Kaşar peyniri",
               category: .dairy, proteinPer100g: 25, caloriesPer100g: 340, carbsPer100g: 0.5, fatPer100g: 27,
               typicalPortionG: 30, portionLabel: "2 dilim"),
        TrFood(id: "tr_lor", name: "Lor Cheese (low-fat)", nameTr: "Lor peyniri",
               category: .dairy, proteinPer100g: 12, caloriesPer100g: 80, carbsPer100g: 2.5, fatPer100g: 2,
               typicalPortionG: 100, portionLabel: "3 yemek kaşığı"),

        // ── GRAINS ──
        TrFood(id: "tr_bulgur", name: "Bulgur Pilav", nameTr: "Bulgur pilavı",
               category: .grains, proteinPer100g: 3.5, caloriesPer100g: 120, carbsPer100g: 24, fatPer100g: 1.5,
               typicalPortionG: 200, portionLabel: "1 porsiyon"),
        TrFood(id: "tr_pilav", name: "Rice Pilaf", nameTr: "Pirinç pilavı",
               category: .grains, proteinPer100g: 2.7, caloriesPer100g: 140, carbsPer100g: 28, fatPer100g: 2,
               typicalPortionG: 200, portionLabel: "1 porsiyon"),
        TrFood(id: "tr_ekmek", name: "Whole Wheat Bread", nameTr: "Tam buğday ekmeği",
               category: .grains, proteinPer100g: 10, caloriesPer100g: 250, carbsPer100g: 46, fatPer100g: 3.5,
               typicalPortionG: 50, portionLabel: "1 dilim"),
        TrFood(id: "tr_simit", name: "Simit (sesame ring)", nameTr: "Simit",
               category: .grains, proteinPer100g: 10, caloriesPer100g: 310, carbsPer100g: 55, fatPer100g: 5,
               typicalPortionG: 120, portionLabel: "1 adet"),
        TrFood(id: "tr_gozleme", name: "Gözleme (spinach)", nameTr: "Ispanaklı gözleme",
               category: .grains, proteinPer100g: 7, caloriesPer100g: 220, carbsPer100g: 30, fatPer100g: 8,
               typicalPortionG: 150, portionLabel: "1 adet"),

        // ── VEG & SALAD ──
        TrFood(id: "tr_coban", name: "Shepherd's Salad", nameTr: "Çoban salatası",
               category: .vegetables, proteinPer100g: 1.2, caloriesPer100g: 45, carbsPer100g: 4, fatPer100g: 2.8,
               typicalPortionG: 200, portionLabel: "1 porsiyon"),
        TrFood(id: "tr_zeytinyagli", name: "Green Beans (olive oil)", nameTr: "Zeytinyağlı fasulye",
               category: .vegetables, proteinPer100g: 2, caloriesPer100g: 65, carbsPer100g: 6, fatPer100g: 3.5,
               typicalPortionG: 200, portionLabel: "1 porsiyon"),
        TrFood(id: "tr_mercimek_cig", name: "Lentil Bulgur Balls", nameTr: "Mercimek köftesi",
               category: .vegetables, proteinPer100g: 6, caloriesPer100g: 140, carbsPer100g: 22, fatPer100g: 3,
               typicalPortionG: 120, portionLabel: "6 adet"),

        // ── BREAKFAST ──
        TrFood(id: "tr_menemen", name: "Menemen (eggs & peppers)", nameTr: "Menemen",
               category: .breakfast, proteinPer100g: 7, caloriesPer100g: 110, carbsPer100g: 5, fatPer100g: 7,
               typicalPortionG: 200, portionLabel: "1 porsiyon"),
        TrFood(id: "tr_sucuklu_yumurta", name: "Sucuk & Eggs", nameTr: "Sucuklu yumurta",
               category: .breakfast, proteinPer100g: 14, caloriesPer100g: 240, carbsPer100g: 2, fatPer100g: 19,
               typicalPortionG: 150, portionLabel: "1 porsiyon"),
        TrFood(id: "tr_acma", name: "Açma (soft roll)", nameTr: "Açma",
               category: .breakfast, proteinPer100g: 7, caloriesPer100g: 320, carbsPer100g: 42, fatPer100g: 14,
               typicalPortionG: 80, portionLabel: "1 adet"),

        // ── FRUITS & NUTS ──
        TrFood(id: "tr_fig", name: "Fresh Fig", nameTr: "Taze incir",
               category: .fruitsNuts, proteinPer100g: 0.8, caloriesPer100g: 74, carbsPer100g: 19, fatPer100g: 0.3,
               typicalPortionG: 120, portionLabel: "3 adet"),
        TrFood(id: "tr_cherry", name: "Cherries", nameTr: "Kiraz",
               category: .fruitsNuts, proteinPer100g: 1, caloriesPer100g: 63, carbsPer100g: 16, fatPer100g: 0.2,
               typicalPortionG: 150, portionLabel: "1 avuç"),
        TrFood(id: "tr_pistachios", name: "Pistachios (Antep)", nameTr: "Antep fıstığı",
               category: .fruitsNuts, proteinPer100g: 20, caloriesPer100g: 560, carbsPer100g: 28, fatPer100g: 45,
               typicalPortionG: 30, portionLabel: "1 avuç"),
        TrFood(id: "tr_dried_mulberry", name: "Dried Mulberries", nameTr: "Dut kurusu",
               category: .fruitsNuts, proteinPer100g: 4, caloriesPer100g: 340, carbsPer100g: 80, fatPer100g: 1.5,
               typicalPortionG: 30, portionLabel: "1 avuç"),

        // ── SOUPS ──
        TrFood(id: "tr_mercimek", name: "Red Lentil Soup", nameTr: "Mercimek çorbası",
               category: .soups, proteinPer100g: 4, caloriesPer100g: 65, carbsPer100g: 10, fatPer100g: 1.5,
               typicalPortionG: 300, portionLabel: "1 kase"),
        TrFood(id: "tr_tarhana", name: "Tarhana Soup", nameTr: "Tarhana çorbası",
               category: .soups, proteinPer100g: 2, caloriesPer100g: 45, carbsPer100g: 8, fatPer100g: 1,
               typicalPortionG: 300, portionLabel: "1 kase"),
        TrFood(id: "tr_iskembe", name: "Tripe Soup", nameTr: "İşkembe çorbası",
               category: .soups, proteinPer100g: 6, caloriesPer100g: 80, carbsPer100g: 4, fatPer100g: 4,
               typicalPortionG: 300, portionLabel: "1 kase")
    ]

    static func byCategory(_ category: TrFood.Category) -> [TrFood] {
        all.filter { $0.category == category }
    }
}
