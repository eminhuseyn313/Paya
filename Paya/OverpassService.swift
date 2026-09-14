import Foundation

// MARK: - Overpass Service
//
// OpenStreetMap Overpass API — free, no key, community map data. Used for
// "what's actually nearby" queries the app has no other way to answer:
// parks/trails (lower-friction outdoor-time nudge than a bare minute
// counter) and pharmacies (convenience when a medication needs refilling).

enum OverpassService {

    struct Place {
        let name: String
        let latitude: Double
        let longitude: Double
        let distanceMeters: Double
    }

    private static let endpoint = "https://overpass-api.de/api/interpreter"

    /// Nearest parks/green spaces within `radiusMeters` of a coordinate.
    static func nearbyParks(latitude: Double, longitude: Double, radiusMeters: Int = 2000) async -> [Place] {
        let query = """
        [out:json][timeout:15];
        (
          node["leisure"="park"](around:\(radiusMeters),\(latitude),\(longitude));
          way["leisure"="park"](around:\(radiusMeters),\(latitude),\(longitude));
        );
        out center 10;
        """
        return await run(query: query, origin: (latitude, longitude))
    }

    /// Nearest pharmacies within `radiusMeters` of a coordinate.
    static func nearbyPharmacies(latitude: Double, longitude: Double, radiusMeters: Int = 3000) async -> [Place] {
        let query = """
        [out:json][timeout:15];
        (
          node["amenity"="pharmacy"](around:\(radiusMeters),\(latitude),\(longitude));
        );
        out center 10;
        """
        return await run(query: query, origin: (latitude, longitude))
    }

    private static func run(query: String, origin: (lat: Double, lon: Double)) async -> [Place] {
        guard let url = URL(string: endpoint) else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "data=" + (query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return [] }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let elements = json["elements"] as? [[String: Any]] else { return [] }

            var places: [Place] = []
            for el in elements {
                let tags = el["tags"] as? [String: Any]
                let name = (tags?["name"] as? String) ?? "Unnamed"
                let lat = (el["lat"] as? Double) ?? ((el["center"] as? [String: Any])?["lat"] as? Double)
                let lon = (el["lon"] as? Double) ?? ((el["center"] as? [String: Any])?["lon"] as? Double)
                guard let lat, let lon else { continue }
                let distance = haversineMeters(lat1: origin.lat, lon1: origin.lon, lat2: lat, lon2: lon)
                places.append(Place(name: name, latitude: lat, longitude: lon, distanceMeters: distance))
            }
            return places.sorted { $0.distanceMeters < $1.distanceMeters }
        } catch {
            return []
        }
    }

    private static func haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}
