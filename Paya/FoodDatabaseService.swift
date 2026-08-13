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

    func search(query: String) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        searchResults = []

        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encoded)&search_simple=1&action=process&json=1&page_size=20"

        guard let url = URL(string: urlString) else {
            isSearching = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let products = json["products"] as? [[String: Any]] {
                searchResults = products.compactMap { dict in
                    parseProductDict(dict)
                }
            }
        } catch {
            lastError = error.localizedDescription
        }

        isSearching = false
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
            barcode: dict["code"] as? String
        )
    }

    // MARK: - Clear

    func clearResults() {
        searchResults = []
        lastError = nil
    }
}
