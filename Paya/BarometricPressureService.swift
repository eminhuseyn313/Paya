import Foundation
import CoreMotion

// MARK: - Barometric Pressure Service
//
// Reads the iPhone's built-in barometer (CMAltimeter) — no location or
// motion-usage permission needed for this specific API. The weather/joint-
// pain link is a long-studied but still genuinely debated hypothesis in
// rheumatology research (results across studies are mixed, not a settled
// fact) — this doesn't assert a connection, it just makes local pressure
// available as one more input to the correlation builder so it can be
// checked against your own data instead of assumed.

@MainActor
enum BarometricPressureService {

    private static let altimeter = CMAltimeter()

    static var isAvailable: Bool { CMAltimeter.isRelativeAltitudeAvailable() }

    /// One-shot current pressure reading in kPa, or nil if the barometer
    /// isn't available (e.g. simulator, older devices) or times out.
    static func currentPressureKPa() async -> Double? {
        guard isAvailable else { return nil }
        return await withCheckedContinuation { continuation in
            var resumed = false
            altimeter.startRelativeAltitudeUpdates(to: .main) { data, error in
                guard !resumed else { return }
                resumed = true
                altimeter.stopRelativeAltitudeUpdates()
                guard let data, error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                // CMAltitudeData.pressure is in kPa despite the API's
                // "relative altitude" framing — it's the actual measured
                // atmospheric pressure at the device.
                continuation.resume(returning: data.pressure.doubleValue)
            }
            // Guard against a hung callback (e.g. a device with a flaky
            // barometer) — after 3s, resolve nil instead of leaking the
            // continuation forever.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                guard !resumed else { return }
                resumed = true
                altimeter.stopRelativeAltitudeUpdates()
                continuation.resume(returning: nil)
            }
        }
    }
}
