import SwiftUI
import Charts

struct ReadinessDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let report: ReadinessEngine.Report

    private var color: Color { Color(hex: report.band.colorHex) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    scoreHeader
                    recommendationBanner

                    Text("WHAT'S DRIVING IT")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.secondary)

                    VStack(spacing: 10) {
                        ForEach(report.drivers) { driver in
                            DriverCard(driver: driver, bandColor: color)
                        }
                    }

                    if !report.journeyNotes.isEmpty {
                        journeySection
                    }

                    methodologyNote
                }
                .padding(16)
            }
            .navigationTitle("Readiness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Score Header

    private var scoreHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 10)
                    .frame(width: 72, height: 72)
                Circle()
                    .trim(from: 0, to: Double(report.score) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                HeroNumberText(value: "\(report.score)", size: 28, color: color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(report.band.rawValue)
                    .font(.title3.weight(.bold))
                    .foregroundColor(color)
                Text("Composite of all drivers below, weighted by how reliably each predicts recovery")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .payaCard(padding: 16)
    }

    // MARK: - Recommendation

    private var recommendationBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: bandIcon)
                    .foregroundColor(color)
                Text("Today's recommendation")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
            }
            Text(report.recommendation)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: PayaRadius.card))
    }

    private var bandIcon: String {
        switch report.band {
        case .primed: return "bolt.fill"
        case .steady: return "checkmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .recover: return "bed.double.fill"
        }
    }

    // MARK: - Journey

    private var journeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TODAY'S STORY")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(report.journeyNotes, id: \.self) { note in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                            .padding(.top, 6)
                        Text(note)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Methodology

    private var methodologyNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HOW THIS WORKS")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)

            Text("Each driver is scored against YOUR rolling 30-day baseline via z-score (standard deviations from your mean), not a population average — the same methodology WHOOP's Recovery and Oura's Readiness scores use. Weights: HRV 40%, Resting HR 25%, Sleep 25%, Training Load 10%, Check-in 15%. A flagged symptom caps the band regardless of biometrics.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color(.tertiarySystemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: PayaRadius.card))
    }
}

// MARK: - Driver Card

struct DriverCard: View {
    let driver: ReadinessEngine.Driver
    let bandColor: Color

    private var driverColor: Color {
        switch driver.score {
        case 70...: return Color(hex: "059669")
        case 50..<70: return Color(hex: "F59E0B")
        default: return Color(hex: "DC2626")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(driverColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(driverColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(driver.label)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        HStack(spacing: 4) {
                            Text("\(Int(driver.score))")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(driverColor)
                            Text("/100")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text(driver.detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Score bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.tertiarySystemBackground))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(driverColor)
                        .frame(width: geo.size.width * CGFloat(driver.score / 100))
                }
            }
            .frame(height: 6)

            // Context explanation
            Text(explanation)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Actionable advice when score is low
            if driver.score < 60 {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "F59E0B"))
                    Text(actionAdvice)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "F59E0B").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .payaCard(padding: 12)
    }

    private var icon: String {
        switch driver.id {
        case "hrv": return "waveform.path.ecg"
        case "rhr": return "heart.fill"
        case "sleep": return "moon.fill"
        case "load": return "flame.fill"
        case "checkin": return "figure.mind.and.body"
        default: return "circle.fill"
        }
    }

    private var explanation: String {
        switch driver.id {
        case "hrv": return "Heart-rate variability — the most sensitive marker of nervous system recovery. Weighted heaviest (40%) because it reflects parasympathetic reactivation faster than resting HR or sleep alone."
        case "rhr": return "Resting heart rate — when elevated above your baseline, your body is still working to recover from training, stress, illness, or poor sleep."
        case "sleep": return "Last night's sleep, scored against both the 7-9h adult range (National Sleep Foundation) and your own typical pattern."
        case "load": return "Yesterday's training volume vs. your 7-day average — a much harder session than usual costs readiness today."
        case "checkin": return "Your morning self-report — soreness and energy, the subjective signals biometrics alone can't see."
        default: return ""
        }
    }

    private var actionAdvice: String {
        switch driver.id {
        case "hrv":
            return "Low HRV suggests your autonomic nervous system hasn't fully recovered. Consider lighter intensity today, prioritize sleep tonight, and limit alcohol/caffeine."
        case "rhr":
            return "Elevated resting HR above your norm. Common causes: poor sleep, stress, dehydration, or cumulative training fatigue. An easy day lets it settle."
        case "sleep":
            return "Sleep was short or disrupted. If training today, keep volume moderate. Napping 20-30min this afternoon can partially compensate."
        case "load":
            return "Yesterday's session was heavier than your recent average. Your muscles and nervous system need more recovery — active mobility or lighter work today."
        case "checkin":
            return "You reported feeling below average. Trust that signal — subjective readiness predicts session quality better than any single biometric."
        default:
            return ""
        }
    }
}
