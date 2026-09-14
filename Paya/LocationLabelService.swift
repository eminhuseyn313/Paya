import Foundation

// MARK: - Location Label Service
//
// OpenStreetMap Nominatim reverse geocoding — free, no API key. Turns a
// bare coordinate pair into a human-readable place name ("near Downtown")
// for anything location-tied that would otherwise only ever show raw
// lat/lon (Doctor Report, trend journal entries referencing an
// environmental reading).
//
// Nominatim's usage policy for the shared public instance requires a
// descriptive User-Agent and caps usage at ~1 request/second — this app's
// usage (a handful of lookups per report generation, not per-request) is
// well within that, but the header is included to be a good citizen of a
// free shared resource.

enum LocationLabelService {

    private static var cache: [String: String] = [:] // "lat,lon" (rounded) → label

    /// Coarse label — suburb/neighborhood level (zoom 14), not street
    /// address. Deliberately imprecise: this is for "roughly where," not
    /// pinpointing a home address in an exported report.
    static func label(latitude: Double, longitude: Double) async -> String? {
        // Round to ~1km precision for cache-key purposes — repeat lookups
        // from roughly the same place (home, work) shouldn't re-hit the
        // network every time.
        let key = String(format: "%.2f,%.2f", latitude, longitude)
        if let cached = cache[key] { return cached }

        guard let url = URL(string: "https://nominatim.openstreetmap.org/reverse?format=json&lat=\(latitude)&lon=\(longitude)&zoom=14&addressdetails=1") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Paya Health App (contact via app store listing)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let address = json["address"] as? [String: Any] else { return nil }

            // Prefer neighborhood/suburb, fall back progressively to
            // broader levels — Nominatim's address fields vary by region.
            let label = (address["suburb"] as? String)
                ?? (address["neighbourhood"] as? String)
                ?? (address["city_district"] as? String)
                ?? (address["town"] as? String)
                ?? (address["city"] as? String)
                ?? (address["county"] as? String)

            cache[key] = label
            return label
        } catch {
            return nil
        }
    }
}
