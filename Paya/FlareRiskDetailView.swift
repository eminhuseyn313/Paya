import SwiftUI
import SwiftData

// MARK: - Flare Risk Detail
//
// FlareDetectionEngine has always computed a real list of contributing
// factors (elevated resting HR, suppressed HRV, joint pain, poor sleep,
// pattern match to prior flares) — this data existed but was never shown
// anywhere; the Dashboard card only ever displayed the risk level and one
// generic recommendation sentence, with no way to see the actual reasoning
// behind it. This is the explanation the user has to tap to get to.

struct FlareRiskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let assessment: FlareRiskAssessment
    var forecast: FlareForecastEngine.Forecast? = nil
    // Reverse-geocoded (OpenStreetMap, free) label for an Air Quality/
    // Barometric Pressure factor — "near Downtown" instead of a bare
    // observation with no sense of where it applies.
    @State private var locationLabel: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(assessment.level.color.opacity(0.15))
                                .frame(width: 56, height: 56)
                            Image(systemName: assessment.level.icon)
                                .font(.title2)
                                .foregroundColor(assessment.level.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Flare Risk · \(assessment.level.displayName)")
                                .font(.headline)
                            Text("Score \(assessment.score)/100 — \(assessment.confidence.displayName)")
                                .font(.caption)
                                .foregroundColor(Pulse.textTertiary)
                        }
                        Spacer()
                    }

                    Text(assessment.recommendation)
                        .font(.subheadline.weight(.semibold))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(assessment.level.color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    if let forecast {
                        forecastSection(forecast)
                    }

                    if assessment.factors.isEmpty {
                        Text("Nothing stands out today — this score reflects normal ranges across the board.")
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                    } else {
                        Text("WHY")
                            .font(.caption.weight(.bold))
                            .foregroundColor(Pulse.textTertiary)

                        VStack(spacing: 10) {
                            ForEach(assessment.factors) { factor in
                                HStack(spacing: 12) {
                                    Image(systemName: factor.icon)
                                        .font(.subheadline)
                                        .foregroundColor(severityColor(factor.severity))
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(factor.name)
                                            .font(.subheadline.weight(.semibold))
                                        Text(factor.observation)
                                            .font(.caption)
                                            .foregroundColor(Pulse.textTertiary)
                                        if let locationLabel, factor.name == "Air Quality" || factor.name == "Barometric Pressure" || factor.name == "Fine Particulates" {
                                            Text("Near \(locationLabel)")
                                                .font(.caption2)
                                                .foregroundColor(Pulse.textTertiary.opacity(0.7))
                                        }
                                    }
                                    Spacer()
                                }
                                .payaCard(padding: 12)
                            }
                        }
                    }

                    Text("\(assessment.confidence.subtitle) — this is pattern-spotting from your own data, not a diagnosis.")
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                }
                .padding(16)
            }
            .navigationTitle("Flare Risk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            guard assessment.factors.contains(where: { $0.name == "Air Quality" || $0.name == "Barometric Pressure" || $0.name == "Fine Particulates" }) else { return }
            let pid = ActiveProfile.id
            let startOfDay = Calendar.current.startOfDay(for: .now)
            let descriptor = FetchDescriptor<EnvironmentalReading>(
                predicate: #Predicate<EnvironmentalReading> { $0.date >= startOfDay && $0.profileId == pid }
            )
            guard let reading = (try? modelContext.fetch(descriptor))?.first,
                  let lat = reading.latitude, let lon = reading.longitude else { return }
            locationLabel = await LocationLabelService.label(latitude: lat, longitude: lon)
        }
    }

    // MARK: - Forecast

    private func forecastSection(_ forecast: FlareForecastEngine.Forecast) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundColor(Pulse.ai)
                Text("NEXT 24-48H")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Pulse.textTertiary)
                Spacer()
                Text(forecast.trajectory.rawValue)
                    .font(.caption.weight(.bold))
                    .foregroundColor(trajectoryColor(forecast.trajectory))
            }

            Text(forecast.summary)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            if !forecast.drivers.isEmpty {
                VStack(spacing: 6) {
                    ForEach(forecast.drivers) { driver in
                        HStack(spacing: 8) {
                            Image(systemName: driver.icon)
                                .font(.caption)
                                .foregroundColor(Pulse.warning)
                                .frame(width: 18)
                            Text(driver.label)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(driver.detail)
                                .font(.caption2)
                                .foregroundColor(Pulse.textTertiary)
                        }
                    }
                }
                .padding(.top, 2)
            }

            Text(forecast.confidence.subtitle)
                .font(.caption2)
                .foregroundColor(Pulse.textTertiary)
        }
        .payaCard(padding: 14)
    }

    private func trajectoryColor(_ trajectory: FlareForecastEngine.Trajectory) -> Color {
        switch trajectory {
        case .worsening: return Pulse.critical
        case .stable: return Pulse.textTertiary
        case .improving: return Pulse.positive
        }
    }

    private func severityColor(_ severity: Int) -> Color {
        switch severity {
        case 0...1: return Pulse.warning
        case 2: return Color(hex: "EA580C")
        default: return Pulse.critical
        }
    }
}
