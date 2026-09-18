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
        return await airQualityIndex(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    /// Same Open-Meteo air-quality endpoint, but for an arbitrary
    /// coordinate rather than the device's current GPS fix — used by
    /// AirQualityLocationMonitor's significant-location-change callback,
    /// which already has a CLLocation from CoreLocation and shouldn't
    /// trigger a second, redundant location request through
    /// `currentLocation()`.
    /// PM2.5 at the device's current location — see `pm25(latitude:longitude:)`.
    func currentPM25() async -> Double? {
        guard let location = await currentLocation() else { return nil }
        return await pm25(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    /// Peak pollen count at the device's current location — see
    /// `peakPollenCount(latitude:longitude:)`.
    func currentPollen() async -> Double? {
        guard let location = await currentLocation() else { return nil }
        return await peakPollenCount(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    func airQualityIndex(latitude: Double, longitude: Double) async -> Double? {
        let urlString = "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=\(latitude)&longitude=\(longitude)&current=european_aqi"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(AirQualityResponse.self, from: data)
            return decoded.current.european_aqi
        } catch {
            return nil
        }
    }

    /// Fine particulate matter (PM2.5, µg/m³) specifically — the composite
    /// European AQI blends several pollutants into one score, but the
    /// actual pollution-inflammation research (Zhao et al. 2020, cited in
    /// FlareDetectionEngine's air-quality signal) measures PM2.5 directly.
    /// WHO's 2021 guideline threshold is 15 µg/m³ (24h mean) as the point
    /// above which health effects become a real concern.
    func pm25(latitude: Double, longitude: Double) async -> Double? {
        let urlString = "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=\(latitude)&longitude=\(longitude)&current=pm2_5"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(PM25Response.self, from: data)
            return decoded.current.pm2_5
        } catch {
            return nil
        }
    }

    /// Pollen counts — Open-Meteo's CAMS European regional model only
    /// (returns nil outside Europe; that's a real coverage limit of the
    /// free data source, not a bug — callers should treat nil as "not
    /// available here" and skip the signal, not as an error). Returns the
    /// highest of the 6 tracked pollen types (grains/m³) as a single
    /// "how bad is pollen today" number, since most users care about
    /// overall pollen burden, not which specific plant.
    func peakPollenCount(latitude: Double, longitude: Double) async -> Double? {
        let types = "alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen"
        let urlString = "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=\(latitude)&longitude=\(longitude)&current=\(types)"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(PollenResponse.self, from: data)
            let values = [
                decoded.current.alder_pollen, decoded.current.birch_pollen,
                decoded.current.grass_pollen, decoded.current.mugwort_pollen,
                decoded.current.olive_pollen, decoded.current.ragweed_pollen,
            ].compactMap { $0 }
            return values.max()
        } catch {
            return nil
        }
    }

    /// Multi-day barometric pressure forecast (device's current location) —
    /// extends the same-day pressure-drop signal FlareDetectionEngine
    /// already uses into a forward-looking one: "a significant drop is
    /// coming in the next 48h," not just "one already happened." Same
    /// forecast-vs-snapshot upgrade FlareForecastEngine already applied to
    /// the biometric signals, applied here to weather specifically.
    func pressureForecast(hoursAhead: Int = 48) async -> [(date: Date, pressureKPa: Double)]? {
        guard let location = await currentLocation() else { return nil }
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let days = max(1, Int(ceil(Double(hoursAhead) / 24.0))) + 1
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&hourly=surface_pressure&forecast_days=\(days)&timezone=auto"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(PressureForecastResponse.self, from: data)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            formatter.timeZone = TimeZone.current
            let now = Date()
            let cutoff = now.addingTimeInterval(Double(hoursAhead) * 3600)
            var results: [(Date, Double)] = []
            for i in decoded.hourly.time.indices {
                guard let date = formatter.date(from: decoded.hourly.time[i]),
                      date >= now, date <= cutoff,
                      i < decoded.hourly.surface_pressure.count else { continue }
                // Open-Meteo reports hPa — convert to kPa to match
                // EnvironmentalReading.barometricPressureKPa's existing unit.
                results.append((date, decoded.hourly.surface_pressure[i] / 10.0))
            }
            return results.isEmpty ? nil : results
        } catch {
            return nil
        }
    }

    /// Device's current coordinates, if location access is granted — public
    /// wrapper around the private cached/coalesced `currentLocation()` so
    /// other services (EnvironmentalReadingCapture, for reverse geocoding)
    /// can reuse the same caching/timeout behavior instead of standing up
    /// their own CLLocationManager.
    func currentCoordinates() async -> (latitude: Double, longitude: Double)? {
        guard let location = await currentLocation() else { return nil }
        return (location.coordinate.latitude, location.coordinate.longitude)
    }

    /// Current relative humidity (%) at the device's location — same free
    /// Open-Meteo forecast endpoint, one more field. Patient-reported joint
    /// sensitivity to humidity is common but the evidence for it is mixed
    /// (unlike barometric pressure, which has firmer research behind it) —
    /// used for personal pattern-spotting (does YOUR data show it), not
    /// asserted as a universal effect.
    func currentHumidity() async -> Double? {
        guard let location = await currentLocation() else { return nil }
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=relative_humidity_2m"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(HumidityResponse.self, from: data)
            return decoded.current.relative_humidity_2m
        } catch {
            return nil
        }
    }

    /// Today's sunrise/sunset (device's current location) and peak UV
    /// index — both free fields on the same Open-Meteo forecast endpoint
    /// already used for hourly weather, so no new API integration or key.
    /// Real local sunrise/sunset replaces whatever fixed-hour estimate
    /// CircadianEngine was using before; UV max feeds a same-day outdoor-
    /// time safety check.
    struct SunAndUV {
        let sunrise: Date
        let sunset: Date
        let uvIndexMax: Double?
    }

    func todaySunAndUV() async -> SunAndUV? {
        guard let location = await currentLocation() else { return nil }
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&daily=sunrise,sunset,uv_index_max&timezone=auto&forecast_days=1"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(SunResponse.self, from: data)
            guard let sunriseStr = decoded.daily.sunrise.first,
                  let sunsetStr = decoded.daily.sunset.first else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            formatter.timeZone = TimeZone.current
            guard let sunrise = formatter.date(from: sunriseStr),
                  let sunset = formatter.date(from: sunsetStr) else { return nil }
            return SunAndUV(sunrise: sunrise, sunset: sunset, uvIndexMax: decoded.daily.uv_index_max.first ?? nil)
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

private struct PM25Response: Decodable {
    struct Current: Decodable {
        let pm2_5: Double?
    }
    let current: Current
}

private struct PollenResponse: Decodable {
    struct Current: Decodable {
        let alder_pollen: Double?
        let birch_pollen: Double?
        let grass_pollen: Double?
        let mugwort_pollen: Double?
        let olive_pollen: Double?
        let ragweed_pollen: Double?
    }
    let current: Current
}

private struct HumidityResponse: Decodable {
    struct Current: Decodable {
        let relative_humidity_2m: Double?
    }
    let current: Current
}

private struct PressureForecastResponse: Decodable {
    struct Hourly: Decodable {
        let time: [String]
        let surface_pressure: [Double]
    }
    let hourly: Hourly
}

private struct SunResponse: Decodable {
    struct Daily: Decodable {
        let sunrise: [String]
        let sunset: [String]
        let uv_index_max: [Double?]
    }
    let daily: Daily
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
