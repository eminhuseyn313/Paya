import SwiftUI
import SwiftData

// MARK: - Flare Risk Factors Card
//
// Barometric pressure and air quality were already captured daily
// (EnvironmentalReadingCapture) and fed into CorrelationEngine — but only
// ever surfaced if a correlation happened to clear the moderate-effect-size
// threshold across weeks of data. That's backwards for someone managing a
// chronic condition day to day: they want to know TODAY's risk factors
// before a pattern has even had time to prove itself statistically. This
// reads today's numbers directly against established thresholds instead of
// waiting on a coefficient.

struct FlareRiskFactorsCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var todayPressure: Double? = nil
    @State private var yesterdayPressure: Double? = nil
    @State private var aqi: Double? = nil
    @State private var noiseDb: Double? = nil
    @State private var loaded = false

    private var pressureDropKPa: Double? {
        guard let today = todayPressure, let yesterday = yesterdayPressure else { return nil }
        return yesterday - today
    }

    private struct Factor: Identifiable {
        let id: String
        let icon: String
        let label: String
        let value: String
        let elevated: Bool
        let note: String
    }

    private var factors: [Factor] {
        var result: [Factor] = []

        if let drop = pressureDropKPa {
            // A ≥1 kPa (~10 hPa) drop in 24h is the threshold used in
            // weather-arthritis pain studies (Timmermans EJ, et al. "Weather
            // Conditions and Joint Pain in Older People." Pain Medicine,
            // 2015) as a meaningfully sharp pressure change, not just normal
            // day-to-day drift.
            result.append(Factor(
                id: "pressure",
                icon: "barometer",
                label: "Barometric pressure",
                value: drop > 0 ? String(format: "↓ %.1f kPa vs yesterday", drop) : String(format: "↑ %.1f kPa vs yesterday", -drop),
                elevated: drop >= 1.0,
                note: "Sharp pressure drops are linked to joint pain flares in older adults (Timmermans et al., 2015)."
            ))
        }
        if let aqi {
            // EPA Air Quality Index bands.
            let elevated = aqi > 100
            result.append(Factor(
                id: "aqi",
                icon: "aqi.medium",
                label: "Air quality",
                value: "AQI \(Int(aqi))",
                elevated: elevated,
                note: aqi > 150 ? "Unhealthy — consider limiting time outdoors." : (elevated ? "Unhealthy for sensitive groups." : "Good to moderate.")
            ))
        }
        if let noiseDb {
            // WHO environmental noise guidelines flag sustained exposure
            // above ~65-70 dB as a stress/sleep-disruption risk.
            let elevated = noiseDb >= 70
            result.append(Factor(
                id: "noise",
                icon: "waveform",
                label: "Ambient noise",
                value: String(format: "%.0f dB avg", noiseDb),
                elevated: elevated,
                note: "WHO guidance flags sustained exposure above ~70dB as a stress and sleep-disruption risk."
            ))
        }
        return result
    }

    var body: some View {
        Group {
            if loaded && !factors.isEmpty {
                content
            }
        }
        .task { await load() }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(Color(hex: "B45309"))
                Text("Today's Flare Risk Factors")
                    .font(.subheadline.weight(.semibold))
                CardInfoButton(
                    title: "Flare Risk Factors",
                    explanation: "Environmental factors read against published thresholds, shown today rather than waiting for a correlation to prove itself over weeks. Not a diagnosis — a heads-up worth weighing against how you actually feel."
                )
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(factors) { factor in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: factor.icon)
                            .font(.caption)
                            .foregroundColor(factor.elevated ? Color(hex: "B45309") : Color(hex: "059669"))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(factor.label).font(.caption.weight(.semibold))
                                Spacer()
                                Text(factor.value).font(.caption.weight(.bold)).monospacedDigit()
                                    .foregroundColor(factor.elevated ? Color(hex: "B45309") : .primary)
                            }
                            Text(factor.note)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .payaCard(padding: 14)
    }

    private func load() async {
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay

        let descriptor = FetchDescriptor<EnvironmentalReading>(
            predicate: #Predicate<EnvironmentalReading> { $0.date >= yesterdayStart && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        let readings = (try? modelContext.fetch(descriptor)) ?? []
        todayPressure = readings.last { $0.date >= startOfDay }?.barometricPressureKPa
        yesterdayPressure = readings.last { $0.date < startOfDay }?.barometricPressureKPa
        aqi = readings.last { $0.date >= startOfDay }?.airQualityIndex

        let noiseByDay = await HealthKitManager.shared.fetchDailyEnvironmentalNoise(daysBack: 1)
        noiseDb = noiseByDay[startOfDay]

        loaded = true
    }
}
