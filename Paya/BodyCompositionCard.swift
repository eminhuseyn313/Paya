import SwiftUI
import SwiftData
import Charts

// MARK: - Body Composition Estimation Card
// Uses the U.S. Navy circumference method to estimate body fat percentage
// from measurements the user already logs in BodyMeasurementLog.
//
// Grounded in: Hodgdon & Beckett (1984) — the Navy body-fat formula,
// validated against hydrostatic weighing with ±3-4% error, adopted as the
// DoD standard. Requires only neck, waist (and hip for females).
//
// Male:   %BF = 86.010 × log10(waist - neck) − 70.041 × log10(height) + 36.76
// Female: %BF = 163.205 × log10(waist + hip - neck) − 97.684 × log10(height) + 36.76
//
// Lean mass = weight × (1 - %BF/100)
// Fat mass  = weight × (%BF/100)
//
// ACE body-fat classification (male):
//   Essential: 2-5%  |  Athletic: 6-13%  |  Fit: 14-17%
//   Average: 18-24%  |  Obese: 25%+
// ACE body-fat classification (female):
//   Essential: 10-13%  |  Athletic: 14-20%  |  Fit: 21-24%
//   Average: 25-31%  |  Obese: 32%+

struct BodyCompositionCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var currentBF: Double?
    @State private var leanMass: Double?
    @State private var fatMass: Double?
    @State private var category: String?
    @State private var categoryColor: Color = .secondary
    @State private var history: [(date: Date, bf: Double)] = []
    @State private var hasSufficientData = false

    var body: some View {
        Group {
            if hasSufficientData {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "figure.stand")
                            .foregroundColor(Pulse.recovery)
                        Text("Body composition")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if let cat = category {
                            Text(cat)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(categoryColor)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 16) {
                        // Body fat gauge
                        if let bf = currentBF {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .stroke(categoryColor.opacity(0.15), lineWidth: 7)
                                        .frame(width: 60, height: 60)
                                    Circle()
                                        .trim(from: 0, to: min(1, bf / 40))
                                        .stroke(categoryColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                                        .frame(width: 60, height: 60)
                                        .rotationEffect(.degrees(-90))
                                    VStack(spacing: 0) {
                                        Text(String(format: "%.1f", bf))
                                            .font(.system(size: 18, weight: .bold, design: .rounded))
                                        Text("%")
                                            .font(.system(size: 9))
                                            .foregroundColor(Pulse.textTertiary)
                                    }
                                }
                                Text("Body fat")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Pulse.textTertiary)
                            }
                        }

                        // Lean vs fat mass
                        VStack(alignment: .leading, spacing: 8) {
                            if let lean = leanMass {
                                massRow(
                                    label: "Lean mass",
                                    value: lean,
                                    color: Pulse.positive
                                )
                            }
                            if let fat = fatMass {
                                massRow(
                                    label: "Fat mass",
                                    value: fat,
                                    color: Pulse.nutrition
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Trend chart
                    if history.count >= 2 {
                        Chart(history, id: \.date) { entry in
                            LineMark(
                                x: .value("Date", entry.date),
                                y: .value("BF%", entry.bf)
                            )
                            .foregroundStyle(Pulse.recovery)
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Date", entry.date),
                                y: .value("BF%", entry.bf)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Pulse.recovery.opacity(0.2), .clear],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)

                            PointMark(
                                x: .value("Date", entry.date),
                                y: .value("BF%", entry.bf)
                            )
                            .foregroundStyle(Pulse.recovery)
                            .symbolSize(12)
                        }
                        .frame(height: 60)
                        .chartYScale(domain: .automatic(includesZero: false))
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .month)) {
                                AxisValueLabel(format: .dateTime.month(.abbreviated))
                                    .font(.system(size: 8))
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                                AxisValueLabel()
                                    .font(.system(size: 8))
                            }
                        }
                    }

                    Text("Hodgdon & Beckett (1984) Navy circumference method — ±3-4% vs hydrostatic weighing. Log neck + waist measurements regularly for best tracking.")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func massRow(label: String, value: Double, color: Color) -> some View {
        let useLbs = appState.profile.prefersLbs
        let display = useLbs ? value * 2.20462 : value
        let unit = useLbs ? "lbs" : "kg"

        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Pulse.textTertiary)
            Spacer()
            Text(String(format: "%.1f %@", display, unit))
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
    }

    private func compute() {
        let pid = ActiveProfile.id
        let isMale = appState.profile.sexRaw == "male"
        let heightCm = appState.profile.heightCm

        guard heightCm > 0 else { return }

        // Fetch all measurements with neck + waist
        let descriptor = FetchDescriptor<BodyMeasurementLog>(
            predicate: #Predicate<BodyMeasurementLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let logs = try? modelContext.fetch(descriptor) else { return }

        // Build history of valid BF% estimates
        var bfHistory: [(date: Date, bf: Double)] = []
        for log in logs {
            if let bf = computeBF(log: log, isMale: isMale, heightCm: heightCm) {
                bfHistory.append((log.date, bf))
            }
        }

        guard !bfHistory.isEmpty else { return }

        hasSufficientData = true
        history = bfHistory.reversed() // chronological for chart

        let latestBF = bfHistory[0].bf
        currentBF = latestBF

        // Get current weight for mass calculations
        let weightKg = appState.profile.currentWeightKg
        if weightKg > 0 {
            fatMass = weightKg * (latestBF / 100)
            leanMass = weightKg * (1 - latestBF / 100)
        }

        // Classify
        let (cat, col) = classify(bf: latestBF, isMale: isMale)
        category = cat
        categoryColor = col
    }

    private func computeBF(log: BodyMeasurementLog, isMale: Bool, heightCm: Double) -> Double? {
        guard let neck = log.neckCm, neck > 0,
              let waist = log.waistCm, waist > 0 else { return nil }

        if isMale {
            let diff = waist - neck
            guard diff > 0 else { return nil }
            let bf = 86.010 * log10(diff) - 70.041 * log10(heightCm) + 36.76
            return max(2, min(50, bf))
        } else {
            guard let hip = log.hipsCm, hip > 0 else { return nil }
            let sum = waist + hip - neck
            guard sum > 0 else { return nil }
            let bf = 163.205 * log10(sum) - 97.684 * log10(heightCm) + 36.76
            return max(8, min(55, bf))
        }
    }

    private func classify(bf: Double, isMale: Bool) -> (String, Color) {
        if isMale {
            switch bf {
            case ..<6:  return ("Essential", Pulse.critical)
            case ..<14: return ("Athletic", Pulse.positive)
            case ..<18: return ("Fit", Pulse.hydration)
            case ..<25: return ("Average", Pulse.nutrition)
            default:    return ("Above avg", Pulse.critical)
            }
        } else {
            switch bf {
            case ..<14: return ("Essential", Pulse.critical)
            case ..<21: return ("Athletic", Pulse.positive)
            case ..<25: return ("Fit", Pulse.hydration)
            case ..<32: return ("Average", Pulse.nutrition)
            default:    return ("Above avg", Pulse.critical)
            }
        }
    }
}
