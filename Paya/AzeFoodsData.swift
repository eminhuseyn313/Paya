import Foundation

// MARK: - Azerbaijani Healthy Foods Library
// Curated staples for one-tap quick add. Macros per 100g; typical portion included.

struct AzeFood: Identifiable, Hashable {
    let id: String
    let name: String
    let nameAz: String
    let category: Category
    let proteinPer100g: Double
    let caloriesPer100g: Double
    let carbsPer100g: Double
    let fatPer100g: Double
    let typicalPortionG: Double
    let portionLabel: String

    enum Category: String, CaseIterable {
        case protein = "Protein"
        case dairy = "Dairy"
        case grains = "Grains"
        case vegetables = "Veg & Salad"
        case fruitsNuts = "Fruits & Nuts"
        case soups = "Soups"

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

enum AzeFoodsData {

    static let all: [AzeFood] = [

        // ── PROTEIN ──
        AzeFood(id: "az_chicken_breast", name: "Grilled Chicken Breast", nameAz: "Toyuq filesi",
                category: .protein, proteinPer100g: 31, caloriesPer100g: 165, carbsPer100g: 0, fatPer100g: 3.6,
                typicalPortionG: 150, portionLabel: "1 fillet"),
        AzeFood(id: "az_beef_lean", name: "Lean Beef (boiled/grilled)", nameAz: "Mal əti",
                category: .protein, proteinPer100g: 26, caloriesPer100g: 250, carbsPer100g: 0, fatPer100g: 15,
                typicalPortionG: 120, portionLabel: "1 serving"),
        AzeFood(id: "az_lamb_kebab", name: "Lamb Kebab (lean)", nameAz: "Tikə kabab",
                category: .protein, proteinPer100g: 25, caloriesPer100g: 260, carbsPer100g: 0, fatPer100g: 17,
                typicalPortionG: 150, portionLabel: "1 skewer"),
        AzeFood(id: "az_lule_chicken", name: "Chicken Lula Kebab", nameAz: "Toyuq lüləsi",
                category: .protein, proteinPer100g: 20, caloriesPer100g: 190, carbsPer100g: 2, fatPer100g: 11,
                typicalPortionG: 130, portionLabel: "1 skewer"),
        AzeFood(id: "az_fish_kutum", name: "Caspian Fish (grilled)", nameAz: "Kütüm balığı",
                category: .protein, proteinPer100g: 19, caloriesPer100g: 120, carbsPer100g: 0, fatPer100g: 4.5,
                typicalPortionG: 180, portionLabel: "1 fillet"),
        AzeFood(id: "az_eggs", name: "Boiled Eggs", nameAz: "Yumurta",
                category: .protein, proteinPer100g: 13, caloriesPer100g: 155, carbsPer100g: 1.1, fatPer100g: 11,
                typicalPortionG: 100, portionLabel: "2 eggs"),
        AzeFood(id: "az_kuku", name: "Kükü (herb omelette)", nameAz: "Kükü",
                category: .protein, proteinPer100g: 10, caloriesPer100g: 150, carbsPer100g: 4, fatPer100g: 11,
                typicalPortionG: 150, portionLabel: "1 slice"),

        // ── DAIRY ──
        AzeFood(id: "az_suzme", name: "Süzmə (strained yogurt)", nameAz: "Süzmə",
                category: .dairy, proteinPer100g: 8.5, caloriesPer100g: 90, carbsPer100g: 4, fatPer100g: 5,
                typicalPortionG: 100, portionLabel: "3 tbsp"),
        AzeFood(id: "az_qatiq", name: "Qatıq (plain yogurt)", nameAz: "Qatıq",
                category: .dairy, proteinPer100g: 3.5, caloriesPer100g: 60, carbsPer100g: 4.5, fatPer100g: 3.2,
                typicalPortionG: 200, portionLabel: "1 bowl"),
        AzeFood(id: "az_ayran", name: "Ayran", nameAz: "Ayran",
                category: .dairy, proteinPer100g: 1.7, caloriesPer100g: 24, carbsPer100g: 2.2, fatPer100g: 1,
                typicalPortionG: 250, portionLabel: "1 glass"),
        AzeFood(id: "az_motal", name: "Motal Cheese", nameAz: "Motal pendiri",
                category: .dairy, proteinPer100g: 22, caloriesPer100g: 290, carbsPer100g: 1, fatPer100g: 22,
                typicalPortionG: 40, portionLabel: "small piece"),
        AzeFood(id: "az_white_cheese", name: "White Cheese (brynza)", nameAz: "Ağ pendir",
                category: .dairy, proteinPer100g: 17, caloriesPer100g: 260, carbsPer100g: 1, fatPer100g: 21,
                typicalPortionG: 50, portionLabel: "1 slice"),
        AzeFood(id: "az_cottage", name: "Cottage Cheese", nameAz: "Kəsmik",
                category: .dairy, proteinPer100g: 16, caloriesPer100g: 100, carbsPer100g: 3, fatPer100g: 2.5,
                typicalPortionG: 200, portionLabel: "1 bowl"),

        // ── GRAINS ──
        AzeFood(id: "az_plov_rice", name: "Plain Rice (plov base)", nameAz: "Düyü",
                category: .grains, proteinPer100g: 2.7, caloriesPer100g: 130, carbsPer100g: 28, fatPer100g: 0.3,
                typicalPortionG: 200, portionLabel: "1 serving"),
        AzeFood(id: "az_buckwheat", name: "Buckwheat", nameAz: "Qarabaşaq",
                category: .grains, proteinPer100g: 4.5, caloriesPer100g: 110, carbsPer100g: 21, fatPer100g: 1.1,
                typicalPortionG: 200, portionLabel: "1 bowl"),
        AzeFood(id: "az_lavash", name: "Lavash (thin bread)", nameAz: "Lavaş",
                category: .grains, proteinPer100g: 9, caloriesPer100g: 280, carbsPer100g: 56, fatPer100g: 1.5,
                typicalPortionG: 60, portionLabel: "1 sheet"),
        AzeFood(id: "az_tandir", name: "Tandir Bread", nameAz: "Təndir çörəyi",
                category: .grains, proteinPer100g: 8.5, caloriesPer100g: 270, carbsPer100g: 54, fatPer100g: 2,
                typicalPortionG: 80, portionLabel: "1 piece"),
        AzeFood(id: "az_oats", name: "Oatmeal (cooked)", nameAz: "Yulaf sıyığı",
                category: .grains, proteinPer100g: 2.5, caloriesPer100g: 70, carbsPer100g: 12, fatPer100g: 1.4,
                typicalPortionG: 250, portionLabel: "1 bowl"),

        // ── VEG & SALAD ──
        AzeFood(id: "az_choban", name: "Choban Salad", nameAz: "Çoban salatı",
                category: .vegetables, proteinPer100g: 1.2, caloriesPer100g: 45, carbsPer100g: 4, fatPer100g: 2.8,
                typicalPortionG: 200, portionLabel: "1 bowl"),
        AzeFood(id: "az_greens", name: "Fresh Herbs Plate", nameAz: "Göyərti",
                category: .vegetables, proteinPer100g: 3, caloriesPer100g: 35, carbsPer100g: 5, fatPer100g: 0.5,
                typicalPortionG: 60, portionLabel: "1 handful"),
        AzeFood(id: "az_grilled_veg", name: "Grilled Vegetables (mangal)", nameAz: "Manqal tərəvəzi",
                category: .vegetables, proteinPer100g: 1.5, caloriesPer100g: 55, carbsPer100g: 8, fatPer100g: 2,
                typicalPortionG: 200, portionLabel: "1 plate"),
        AzeFood(id: "az_badimjan", name: "Eggplant Rolls (light)", nameAz: "Badımcan dolması",
                category: .vegetables, proteinPer100g: 3, caloriesPer100g: 90, carbsPer100g: 7, fatPer100g: 6,
                typicalPortionG: 150, portionLabel: "3 rolls"),

        // ── FRUITS & NUTS ──
        AzeFood(id: "az_pomegranate", name: "Pomegranate", nameAz: "Nar",
                category: .fruitsNuts, proteinPer100g: 1.7, caloriesPer100g: 83, carbsPer100g: 19, fatPer100g: 1.2,
                typicalPortionG: 150, portionLabel: "1/2 fruit"),
        AzeFood(id: "az_walnuts", name: "Walnuts", nameAz: "Qoz",
                category: .fruitsNuts, proteinPer100g: 15, caloriesPer100g: 654, carbsPer100g: 14, fatPer100g: 65,
                typicalPortionG: 30, portionLabel: "1 handful"),
        AzeFood(id: "az_hazelnuts", name: "Hazelnuts", nameAz: "Fındıq",
                category: .fruitsNuts, proteinPer100g: 15, caloriesPer100g: 628, carbsPer100g: 17, fatPer100g: 61,
                typicalPortionG: 30, portionLabel: "1 handful"),
        AzeFood(id: "az_dried_apricot", name: "Dried Apricots", nameAz: "Qurudulmuş ərik",
                category: .fruitsNuts, proteinPer100g: 3.4, caloriesPer100g: 241, carbsPer100g: 63, fatPer100g: 0.5,
                typicalPortionG: 40, portionLabel: "5 pieces"),
        AzeFood(id: "az_apple", name: "Apple", nameAz: "Alma",
                category: .fruitsNuts, proteinPer100g: 0.3, caloriesPer100g: 52, carbsPer100g: 14, fatPer100g: 0.2,
                typicalPortionG: 180, portionLabel: "1 apple"),
        AzeFood(id: "az_feijoa", name: "Feijoa", nameAz: "Feyxoa",
                category: .fruitsNuts, proteinPer100g: 1, caloriesPer100g: 55, carbsPer100g: 13, fatPer100g: 0.6,
                typicalPortionG: 100, portionLabel: "3 fruits"),

        // ── SOUPS ──
        AzeFood(id: "az_merci", name: "Lentil Soup", nameAz: "Mərci şorbası",
                category: .soups, proteinPer100g: 4.5, caloriesPer100g: 70, carbsPer100g: 10, fatPer100g: 1.5,
                typicalPortionG: 300, portionLabel: "1 bowl"),
        AzeFood(id: "az_dovga", name: "Dovga (yogurt herb soup)", nameAz: "Dovğa",
                category: .soups, proteinPer100g: 3, caloriesPer100g: 55, carbsPer100g: 6, fatPer100g: 2,
                typicalPortionG: 300, portionLabel: "1 bowl"),
        AzeFood(id: "az_chicken_soup", name: "Chicken Broth Soup", nameAz: "Toyuq şorbası",
                category: .soups, proteinPer100g: 6, caloriesPer100g: 60, carbsPer100g: 4, fatPer100g: 2,
                typicalPortionG: 300, portionLabel: "1 bowl")
    ]

    static func byCategory(_ category: AzeFood.Category) -> [AzeFood] {
        all.filter { $0.category == category }
    }
}
//
//  AzeFoodsData.swift
//  Paya
//
//  Created by Emin Huseynzade on 11.07.26.
//

