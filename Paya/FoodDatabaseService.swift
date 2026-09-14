import Foundation

// MARK: - Food Database Service
// Free tier: Open Food Facts (3M+ products worldwide, no API key needed)

@MainActor
@Observable
class FoodDatabaseService {

    static let shared = FoodDatabaseService()

    var isSearching: Bool = false
    var searchResults: [FoodProduct] = []
    var lastError: String? = nil

    // MARK: - Food Product

    struct FoodProduct: Identifiable, Hashable {
        let id: String
        let name: String
        let brand: String
        let proteinPer100g: Double
        let caloriesPer100g: Double
        let carbsPer100g: Double
        let fatPer100g: Double
        let servingSize: Double?
        let imageURL: String?
        let barcode: String?
        /// "Open Food Facts" (default, crowdsourced, strong for packaged
        /// products) or "USDA" (government-verified, strong for generic
        /// whole foods) — shown as a badge in search results so the user
        /// knows which kind of source they're looking at.
        var source: String = "Open Food Facts"
        /// Sodium/sugar per 100g — both already present in Open Food
        /// Facts' response, just never extracted before. Used to flag
        /// items against SymptomDietEngine's anti-inflammatory guidance
        /// (refined sugar, high sodium) at the point of logging, not after.
        var sodiumMgPer100g: Double? = nil
        var sugarGPer100g: Double? = nil

        /// FDA "high" threshold is ≥20%DV per serving (≥460mg sodium); WHO
        /// added-sugar guidance caps daily intake around 25g, so ≥15g/100g
        /// is a reasonable "notably high" bar for a single food. Both are
        /// per-100g heuristics (serving size varies and isn't always known
        /// at search time), so this is a caution flag, not a precise
        /// per-serving verdict — resolved to something more exact once a
        /// serving size is chosen.
        var isHighSodium: Bool { (sodiumMgPer100g ?? 0) >= 460 }
        var isHighSugar: Bool { (sugarGPer100g ?? 0) >= 15 }

        var displayName: String {
            brand.isEmpty ? name : "\(brand) — \(name)"
        }

        func nutritionFor(grams: Double) -> (protein: Double, calories: Double) {
            let factor = grams / 100.0
            return (proteinPer100g * factor, caloriesPer100g * factor)
        }
    }

    // MARK: - Barcode Lookup

    func lookupBarcode(_ code: String) async -> FoodProduct? {
        let urlString = "https://world.openfoodfacts.org/api/v2/product/\(code).json"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return parseProduct(from: data)
        } catch {
            lastError = "Network error: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Text Search

    /// `usdaAPIKey` optional — pass it when available (AppState.usdaAPIKey)
    /// to also search USDA FoodData Central in parallel and merge results.
    /// USDA results are listed first: for a generic query like "chicken
    /// breast" they're the more authoritative, lab-verified answer, while
    /// Open Food Facts shines for specific branded products.
    func search(query: String, usdaAPIKey: String = "") async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        searchResults = []

        async let openFoodFacts = searchOpenFoodFacts(query: query)
        async let usda = usdaAPIKey.isEmpty ? [] : searchUSDA(query: query, apiKey: usdaAPIKey)

        let (offResults, usdaResults) = await (openFoodFacts, usda)
        searchResults = usdaResults + offResults

        isSearching = false
    }

    private func searchOpenFoodFacts(query: String) async -> [FoodProduct] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encoded)&search_simple=1&action=process&json=1&page_size=20"
        guard let url = URL(string: urlString) else { return [] }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let products = json["products"] as? [[String: Any]] else { return [] }
            return products.compactMap { parseProductDict($0) }
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    /// USDA FoodData Central — free API, requires a key from
    /// api.data.gov/signup (a real account signup the user does once,
    /// unlike Gemini's key this can't be provisioned automatically).
    /// Foundation/SR-Legacy data types are lab-analyzed government data —
    /// filtered to those two, skipping "Branded" (USDA also mirrors some
    /// branded products, but Open Food Facts already covers that ground
    /// better with fresher crowdsourced data).
    private func searchUSDA(query: String, apiKey: String) async -> [FoodProduct] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://api.nal.usda.gov/fdc/v1/foods/search?query=\(encoded)&dataType=Foundation,SR%20Legacy&pageSize=10&api_key=\(apiKey)"
        guard let url = URL(string: urlString) else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                lastError = http.statusCode == 403 ? "USDA API key was rejected — check it in Settings." : "USDA search failed (HTTP \(http.statusCode))."
                return []
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let foods = json["foods"] as? [[String: Any]] else { return [] }
            return foods.compactMap { parseUSDAFood($0) }
        } catch {
            return [] // best-effort — Open Food Facts results still show even if USDA fails
        }
    }

    private func parseUSDAFood(_ dict: [String: Any]) -> FoodProduct? {
        guard let name = dict["description"] as? String,
              let nutrients = dict["foodNutrients"] as? [[String: Any]] else { return nil }

        func value(forNutrientNumber number: String) -> Double? {
            nutrients.first { ($0["nutrientNumber"] as? String) == number }?["value"] as? Double
        }

        // USDA nutrient numbers (per 100g, standard FDC nutrient IDs):
        // 203 protein, 204 fat, 205 carbohydrate, 208 energy (kcal)
        let protein = value(forNutrientNumber: "203") ?? 0
        let fat = value(forNutrientNumber: "204") ?? 0
        let carbs = value(forNutrientNumber: "205") ?? 0
        let calories = value(forNutrientNumber: "208") ?? 0
        guard protein > 0 || calories > 0 else { return nil }

        let fdcId = dict["fdcId"] as? Int ?? 0
        return FoodProduct(
            id: "usda_\(fdcId)",
            name: name.capitalized,
            brand: "",
            proteinPer100g: protein,
            caloriesPer100g: calories,
            carbsPer100g: carbs,
            fatPer100g: fat,
            servingSize: nil,
            imageURL: nil,
            barcode: nil,
            source: "USDA"
        )
    }

    // MARK: - Parsing

    private func parseProduct(from data: Data) -> FoodProduct? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? Int,
              status == 1,
              let product = json["product"] as? [String: Any] else {
            return nil
        }
        return parseProductDict(product)
    }

    private func parseProductDict(_ dict: [String: Any]) -> FoodProduct? {
        guard let nutriments = dict["nutriments"] as? [String: Any] else { return nil }

        let name = (dict["product_name"] as? String)
            ?? (dict["product_name_en"] as? String)
            ?? "Unknown Product"

        guard !name.isEmpty, name != "Unknown Product" || (dict["code"] as? String) != nil else {
            return nil
        }

        let brand = (dict["brands"] as? String)?.components(separatedBy: ",").first?
            .trimmingCharacters(in: .whitespaces) ?? ""

        let protein = (nutriments["proteins_100g"] as? Double) ?? 0
        let calories = (nutriments["energy-kcal_100g"] as? Double) ?? 0
        let carbs = (nutriments["carbohydrates_100g"] as? Double) ?? 0
        let fat = (nutriments["fat_100g"] as? Double) ?? 0
        // OFF reports sodium in grams — convert to mg to match how sodium
        // is expressed everywhere else in this app (MealLog.sodiumMg etc.).
        let sodiumMg = (nutriments["sodium_100g"] as? Double).map { $0 * 1000 }
        let sugarG = nutriments["sugars_100g"] as? Double

        // Skip products with no useful nutrition data
        guard protein > 0 || calories > 0 else { return nil }

        let servingSize: Double? = {
            if let serving = dict["serving_quantity"] as? Double { return serving }
            if let servingStr = dict["serving_quantity"] as? String,
               let val = Double(servingStr) { return val }
            return nil
        }()

        return FoodProduct(
            id: (dict["code"] as? String) ?? UUID().uuidString,
            name: name,
            brand: brand,
            proteinPer100g: protein,
            caloriesPer100g: calories,
            carbsPer100g: carbs,
            fatPer100g: fat,
            servingSize: servingSize,
            imageURL: dict["image_front_thumb_url"] as? String
                ?? dict["image_thumb_url"] as? String,
            barcode: dict["code"] as? String,
            sodiumMgPer100g: sodiumMg,
            sugarGPer100g: sugarG
        )
    }

    // MARK: - Clear

    func clearResults() {
        searchResults = []
        lastError = nil
    }
}
