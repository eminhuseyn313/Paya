import Foundation
import SwiftData

// MARK: - Environmental Reading Capture
//
// Called once per app-open (from the Dashboard) to opportunistically record
// today's barometric pressure + air quality — see EnvironmentalReading's
// comment for why this can't backfill history the way weather/HealthKit
// data can. Cheap no-op if today's row already exists.

@MainActor
enum EnvironmentalReadingCapture {

    static func captureIfNeeded(context: ModelContext) async {
        let pid = ActiveProfile.id
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<EnvironmentalReading>(
            predicate: #Predicate<EnvironmentalReading> { $0.date >= startOfDay && $0.profileId == pid }
        )
        guard (try? context.fetch(descriptor))?.isEmpty ?? true else { return }

        async let pressure = BarometricPressureService.currentPressureKPa()
        async let aqi = WeatherService.shared.currentAirQualityIndex()

        let reading = EnvironmentalReading(
            barometricPressureKPa: await pressure,
            airQualityIndex: await aqi
        )
        reading.profileId = pid
        guard reading.barometricPressureKPa != nil || reading.airQualityIndex != nil else { return }

        context.insert(reading)
        try? context.save()
    }
}
