import Foundation
import CoreLocation
import UserNotifications

// MARK: - Air Quality Location Monitor
//
// Background, opt-in: alerts when you move somewhere with poor air quality,
// even with the app closed. Uses CLLocationManager's significant-change
// monitoring (~500m+ moves, cell/Wi-Fi based, not continuous GPS) rather
// than standard location updates — the same battery-friendly mechanism
// Apple designed specifically for "wake me up when the user has moved
// somewhere new," which is exactly this use case. Requires "Always"
// location authorization, a real privacy step up from the "When In Use"
// access the rest of the app uses — gated behind an explicit Settings
// toggle, off by default, never started implicitly.
//
// Air quality via Open-Meteo (WeatherService.airQualityIndex) — same free,
// no-key provider already used for weather/AQI elsewhere in the app.

@MainActor
@Observable
final class AirQualityLocationMonitor: NSObject {

    static let shared = AirQualityLocationMonitor()

    private let locationManager = CLLocationManager()
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isMonitoring: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    private static let enabledKeyRaw = "air_quality_monitoring_enabled"
    private var enabledKey: String { Self.enabledKeyRaw }
    private static let lastAlertLocationKey = "aqi_last_alert_lat_lon"
    private static let lastAlertDateKey = "aqi_last_alert_date"

    /// EAQI "Poor" band and up — same threshold FlareDetectionEngine's
    /// air-quality signal uses, so the alert and the health signal agree.
    private let alertThreshold: Double = 60
    /// Don't re-alert for the same lingering episode — only after either
    /// enough time has passed or the person has moved meaningfully further.
    private let minHoursBetweenAlerts: Double = 3
    private let minKmForNewAlert: Double = 2

    private override init() {
        super.init()
        locationManager.delegate = self
        authorizationStatus = locationManager.authorizationStatus
    }

    /// Called from the Settings toggle. Requests "Always" authorization if
    /// needed, then starts significant-change monitoring. Does nothing
    /// silently on its own — must be explicitly invoked by the user turning
    /// the feature on.
    func enable() {
        UserDefaults.standard.set(true, forKey: enabledKey)
        if authorizationStatus == .authorizedAlways {
            locationManager.startMonitoringSignificantLocationChanges()
        } else {
            locationManager.requestAlwaysAuthorization()
            // Actual monitoring starts once didChangeAuthorization fires
            // with .authorizedAlways, below.
        }
    }

    func disable() {
        UserDefaults.standard.set(false, forKey: enabledKey)
        locationManager.stopMonitoringSignificantLocationChanges()
    }

    private func checkAirQuality(at location: CLLocation) async {
        guard let aqi = await WeatherService.shared.airQualityIndex(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        ) else { return }
        guard aqi >= alertThreshold else { return }
        guard shouldAlert(for: location) else { return }

        recordAlert(location: location)

        let content = UNMutableNotificationContent()
        content.title = aqi >= 80 ? "Very poor air quality nearby" : "Poor air quality nearby"
        content.body = String(format: "AQI %.0f where you are right now — consider limiting time outdoors.", aqi)
        content.sound = .default
        content.userInfo = ["destination": NotificationDestination.health.rawValue]

        let request = UNNotificationRequest(
            identifier: "aqi_location_alert_\(UUID().uuidString)",
            content: content,
            trigger: nil // deliver immediately
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func shouldAlert(for location: CLLocation) -> Bool {
        let defaults = UserDefaults.standard
        guard let lastDate = defaults.object(forKey: Self.lastAlertDateKey) as? Date else { return true }
        let hoursSince = Date().timeIntervalSince(lastDate) / 3600
        if hoursSince >= minHoursBetweenAlerts { return true }

        guard let lastLatLon = defaults.string(forKey: Self.lastAlertLocationKey) else { return true }
        let parts = lastLatLon.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2 else { return true }
        let lastLocation = CLLocation(latitude: parts[0], longitude: parts[1])
        let distanceKm = location.distance(from: lastLocation) / 1000
        return distanceKm >= minKmForNewAlert
    }

    private func recordAlert(location: CLLocation) {
        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: Self.lastAlertDateKey)
        defaults.set("\(location.coordinate.latitude),\(location.coordinate.longitude)", forKey: Self.lastAlertLocationKey)
    }
}

extension AirQualityLocationMonitor: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            // If the user enabled the feature and authorization just
            // resolved to Always, start monitoring now — closes the loop
            // for the request made in enable() above.
            if self.authorizationStatus == .authorizedAlways && self.isMonitoring {
                self.locationManager.startMonitoringSignificantLocationChanges()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            guard self.isMonitoring else { return }
            await self.checkAirQuality(at: location)
        }
    }
}
