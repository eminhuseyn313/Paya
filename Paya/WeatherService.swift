import Foundation
import CoreLocation

// MARK: - Weather Service
//
// WeatherKit needs an entitlement tied to the Apple Developer account
// (capability enabled on the App ID on developer.apple.com) — the same
// category of risk as the CloudKit entitlement decision earlier, not
// something to add blind. Open-Meteo is a genuinely free, no-API-key
// weather API (open-meteo.com) that needs nothing beyond a network call,
// so it's the safer path for this feature without asking for developer-
// account changes first.

struct HourlyWeather: Identifiable {
    var id: Int { hour }
    let hour: Int              // 0-23
    let temperatureC: Double
    let weatherCode: Int
    let isDaylight: Bool

    /// WMO weather codes (used by Open-Meteo) — condensed to what's useful
    /// for a "was it sunny" / "should I have walked" glance.
    var isSunny: Bool { isDaylight && (weatherCode == 0 || weatherCode == 1) }

    var conditionLabel: String {
        switch weatherCode {
        case 0: return "Clear"
        case 1: return "Mostly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51...57: return "Drizzle"
        case 61...67: return "Rain"
        case 71...77: return "Snow"
        case 80...82: return "Rain showers"
        case 95...99: return "Thunderstorm"
        default: return "—"
        }
    }

    var systemImage: String {
        if !isDaylight { return "moon.stars.fill" }
        switch weatherCode {
        case 0, 1: return "sun.max.fill"
        case 2: return "cloud.sun.fill"
        case 3, 45, 48: return "cloud.fill"
        case 51...67, 80...82: return "cloud.rain.fill"
        case 71...77: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.fill"
        default: return "cloud.fill"
        }
    }
}

@MainActor
@Observable
final class WeatherService: NSObject {

    static let shared = WeatherService()

    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private let locationManager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    // A personal-health timeline's weather lookups don't need a fresh GPS
    // fix per call — caching one recent fix and sharing it across every
    // concurrent caller fixes a real bug, not just an optimization:
    // `locationContinuation` is a single stored property, so when multiple
    // days build concurrently (buildWeekSummary), each one's call to
    // currentLocation() overwrote the previous call's continuation before
    // CoreLocation answered it — every overwritten continuation was never
    // resumed, so those callers hung forever (not slow — stuck), and the
    // page only ever "finished" once every other blocking step timed out
    // or the whole task tree got cancelled by the view disappearing.
    private var cachedLocation: CLLocation?
    private var cachedLocationAt: Date?
    private var inFlightLocationTask: Task<CLLocation?, Never>?

    private override init() {
        super.init()
        locationManager.delegate = self
        authorizationStatus = locationManager.authorizationStatus
        // City-level accuracy is plenty for "was it sunny" — the default
        // kCLLocationAccuracyBest can hold out for a full GPS lock (slow,
        // especially indoors) when cell/Wi-Fi-based positioning would
        // already answer this in a second or two.
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestAccess() {
        locationManager.requestWhenInUseAuthorization()
    }

    private func currentLocation() async -> CLLocation? {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else { return nil }

        if let cachedLocation, let cachedLocationAt, Date().timeIntervalSince(cachedLocationAt) < 600 {
            return cachedLocation
        }
        if let inFlightLocationTask {
            return await inFlightLocationTask.value
        }

        let task = Task<CLLocation?, Never> { [weak self] in
            await self?.fetchLocationWithTimeout()
        }
        inFlightLocationTask = task
        let result = await task.value
        inFlightLocationTask = nil
        return result
    }

    /// Races the real location request against an 8s timeout so a single
    /// slow/stuck GPS fix can never hang an entire screen — if the timeout
    /// wins, the real request is left running in the background (a checked
    /// continuation isn't cancelled by losing a race) and will still
    /// populate the cache for the next call once CoreLocation answers.
    private func fetchLocationWithTimeout() async -> CLLocation? {
        await withTaskGroup(of: CLLocation?.self) { group in
            group.addTask { [weak self] in
                await self?.requestLocationOnce()
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(8))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private func requestLocationOnce() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    /// Hourly weather for a given day at the device's current location.
    /// Today/future days use the forecast endpoint; past days need the
    /// separate archive endpoint (Open-Meteo splits these, both free, no
    /// key). Returns nil if location access isn't granted or the request
    /// fails — callers should degrade gracefully (the timeline just omits
    /// the weather row).
    func hourlyWeather(for date: Date) async -> [HourlyWeather]? {
        guard let location = await currentLocation() else { return nil }
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        let isPast = date < calendar.startOfDay(for: .now)

        let urlString: String
        if isPast {
            urlString = "https://archive-api.open-meteo.com/v1/archive?latitude=\(lat)&longitude=\(lon)&start_date=\(dateString)&end_date=\(dateString)&hourly=temperature_2m,weathercode,is_day&timezone=auto"
        } else {
            urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&start_date=\(dateString)&end_date=\(dateString)&hourly=temperature_2m,weathercode,is_day&timezone=auto"
        }
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let hourly = decoded.hourly
            guard hourly.time.count == hourly.temperature_2m.count,
                  hourly.time.count == hourly.weathercode.count,
                  hourly.time.count == hourly.is_day.count else { return nil }

            let altFormatter = DateFormatter()
            altFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

            return hourly.time.indices.compactMap { i -> HourlyWeather? in
                guard let parsed = altFormatter.date(from: hourly.time[i]),
                      calendar.isDate(parsed, inSameDayAs: date) else { return nil }
                let hour = calendar.component(.hour, from: parsed)
                return HourlyWeather(
                    hour: hour,
                    temperatureC: hourly.temperature_2m[i],
                    weatherCode: hourly.weathercode[i],
                    isDaylight: hourly.is_day[i] == 1
                )
            }
        } catch {
            return nil
        }
    }

    /// European AQI (0-100+, EU-standard scale) for today at the device's
    /// current location — Open-Meteo's Air Quality API, same free/no-key
    /// provider already used for weather, so no new integration or
    /// developer-account entitlement needed. Air quality is a genuine
    /// respiratory/systemic-inflammation-relevant exposure; this only
    /// covers today/forecast, not historical days, since the correlation
    /// engine builds its own daily history going forward from when this
    /// starts being called rather than backfilling the past.
    func currentAirQualityIndex() async -> Double? {
        guard let location = await currentLocation() else { return nil }
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let urlString = "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=\(lat)&longitude=\(lon)&current=european_aqi"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(AirQualityResponse.self, from: data)
            return decoded.current.european_aqi
        } catch {
            return nil
        }
    }
}

private struct AirQualityResponse: Decodable {
    struct Current: Decodable {
        let european_aqi: Double?
    }
    let current: Current
}

extension WeatherService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let location = locations.first {
                self.cachedLocation = location
                self.cachedLocationAt = Date()
            }
            self.locationContinuation?.resume(returning: locations.first)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in
            self.locationContinuation?.resume(returning: nil)
            self.locationContinuation = nil
        }
    }
}

private struct OpenMeteoResponse: Decodable {
    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double]
        let weathercode: [Int]
        let is_day: [Int]
    }
    let hourly: Hourly
}
