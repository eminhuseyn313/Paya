import SwiftUI
import SwiftData

// MARK: - Biological Age Score
//
// Quarterly composite estimate from HRV, RHR, sleep quality, VO2max,
// and body composition trends. NOT a clinical diagnosis — a relative
// fitness-age score that shows whether the user's physiological
// markers trend younger or older than their chronological age.
//
// Research basis:
// - Levine (2013), "Modeling the Rate of Senescence" — phenotypic
//   age derived from biomarkers. We adapt the concept to consumer
//   wearable data (HRV, RHR, sleep) rather than blood markers.
// - Nes et al. (2011), "Estimating VO2peak from a Nonexercise
//   Prediction Model" — VO2max is the strongest single predictor
//   of all-cause mortality, making it the anchor of fitness-age
//   estimates.
// - Shaffer & Ginsberg (2017), "An Overview of Heart Rate
//   Variability Metrics" — HRV declines ~1ms SDNN per year of
//   chronological age in healthy adults.

struct BiologicalAgeCard: View {

    @Environment(AppState.self) private var appState
    @State private var bioAge: BiologicalAgeEstimate?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "heart.text.clipboard.fill")
                    .foregroundColor(Pulse.ai)
                    .font(.system(size: 12))
                Text("Biological age estimate")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if bioAge != nil {
                    Text("Quarterly")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Pulse.ai)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Pulse.ai.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if isLoading {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text("Analyzing biomarkers…")
                        .font(.caption).foregroundColor(Pulse.textTertiary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
            } else if let est = bioAge {
                // Main score display
                HStack(spacing: 16) {
                    // Bio age
                    VStack(spacing: 2) {
                        Text("\(est.estimatedAge)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(est.deltaColor)
                        Text("Bio age")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Pulse.textTertiary)
                    }

                    // vs chronological
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chronological: \(est.chronologicalAge)")
                            .font(.caption)
                        HStack(spacing: 4) {
                            Image(systemName: est.delta < 0 ? "arrow.down" : est.delta > 0 ? "arrow.up" : "equal")
                                .font(.system(size: 10, weight: .bold))
                            Text(est.deltaText)
                                .font(.caption.weight(.bold))
                        }
                        .foregroundColor(est.deltaColor)

                        Text(est.summaryText)
                            .font(.system(size: 10))
                            .foregroundColor(Pulse.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

                // Component breakdown
                VStack(spacing: 6) {
                    Text("COMPONENTS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Pulse.textTertiary)

                    ForEach(est.components) { comp in
                        HStack {
                            Image(systemName: comp.icon)
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: comp.colorHex))
                                .frame(width: 20)
                            Text(comp.label)
                                .font(.system(size: 11))
                            Spacer()
                            Text(comp.valueText)
                                .font(.system(size: 11, weight: .medium))
                            Text(comp.impactText)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(comp.impactColor)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }

                // Disclaimer
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 8))
                    Text("Estimate from consumer wearable data, not clinical biomarkers. Not a diagnosis. Levine (2013) phenotypic age model adapted.")
                        .font(.system(size: 9))
                }
                .foregroundColor(Pulse.textTertiary)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "heart.text.clipboard")
                        .font(.title3).foregroundColor(Pulse.textTertiary)
                    Text("Not enough data")
                        .font(.caption.weight(.semibold))
                    Text("Needs at least 30 days of HRV, resting HR, and sleep data to estimate biological age.")
                        .font(.system(size: 10))
                        .foregroundColor(Pulse.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
            }
        }
        .payaCard(padding: 14)
        .task { await compute() }
    }

    // MARK: - Computation

    @MainActor
    private func compute() async {
        let chronAge = appState.profile.age
        guard chronAge > 0 else { isLoading = false; return }

        let bio = BiometricStore.shared
        if bio.history.isEmpty { await bio.loadHistory(daysBack: 90) }

        let recent = bio.history.suffix(90)
        let hrvValues = recent.compactMap(\.hrv)
        let rhrValues = recent.compactMap(\.restingHR)
        let sleepValues = recent.compactMap(\.sleepHours)
        let deepSleepValues = recent.compactMap(\.sleepDeep)

        guard hrvValues.count >= 14, rhrValues.count >= 14 else {
            isLoading = false
            return
        }

        let avgHRV = hrvValues.reduce(0, +) / Double(hrvValues.count)
        let avgRHR = rhrValues.reduce(0, +) / Double(rhrValues.count)
        let avgSleep = sleepValues.isEmpty ? nil : sleepValues.reduce(0, +) / Double(sleepValues.count)
        let avgDeep = deepSleepValues.isEmpty ? nil : deepSleepValues.reduce(0, +) / Double(deepSleepValues.count)

        // VO2max from HealthKit
        let vo2 = await HealthKitManager.shared.fetchVO2Max()

        var components: [BioAgeComponent] = []
        var ageAdjustments: [Double] = []

        // HRV component: Shaffer & Ginsberg (2017) — HRV declines ~1ms/year
        // Population norms: 20yo ~45ms, 40yo ~35ms, 60yo ~25ms
        let hrvExpectedForAge = max(15, 50 - Double(chronAge) * 0.5)
        let hrvDelta = (avgHRV - hrvExpectedForAge) / hrvExpectedForAge
        let hrvAgeImpact = -hrvDelta * 10  // each 10% above norm = ~1 year younger
        ageAdjustments.append(hrvAgeImpact)
        components.append(BioAgeComponent(
            id: "hrv", label: "HRV", icon: "waveform.path.ecg",
            colorHex: "059669", valueText: "\(Int(avgHRV)) ms",
            impact: hrvAgeImpact, weight: 0.3
        ))

        // RHR: lower = fitter. Norms: fit adult 55-65, average 65-75
        let rhrExpected = 68.0
        let rhrDelta = (avgRHR - rhrExpected) / rhrExpected
        let rhrAgeImpact = rhrDelta * 8
        ageAdjustments.append(rhrAgeImpact)
        components.append(BioAgeComponent(
            id: "rhr", label: "Resting HR", icon: "heart.fill",
            colorHex: "DC2626", valueText: "\(Int(avgRHR)) bpm",
            impact: rhrAgeImpact, weight: 0.25
        ))

        // Sleep: optimal 7-9h
        if let sleep = avgSleep {
            let sleepImpact: Double
            if sleep >= 7 && sleep <= 9 {
                sleepImpact = -1  // good sleep = younger
            } else if sleep >= 6 && sleep <= 10 {
                sleepImpact = 1
            } else {
                sleepImpact = 3  // poor sleep = older
            }
            ageAdjustments.append(sleepImpact)
            components.append(BioAgeComponent(
                id: "sleep", label: "Sleep", icon: "moon.fill",
                colorHex: "2563EB", valueText: String(format: "%.1fh", sleep),
                impact: sleepImpact, weight: 0.2
            ))
        }

        // Deep sleep: should be 15-25% of total
        if let deep = avgDeep, let sleep = avgSleep, sleep > 0 {
            let deepPct = deep / sleep * 100
            let deepImpact: Double
            if deepPct >= 15 && deepPct <= 25 {
                deepImpact = -1
            } else if deepPct >= 10 {
                deepImpact = 1
            } else {
                deepImpact = 3
            }
            ageAdjustments.append(deepImpact)
            components.append(BioAgeComponent(
                id: "deep", label: "Deep sleep", icon: "bed.double.fill",
                colorHex: "8B5CF6", valueText: String(format: "%.0f%%", deepPct),
                impact: deepImpact, weight: 0.1
            ))
        }

        // VO2max: strongest mortality predictor (Nes 2011)
        if let vo2Data = vo2 {
            // VO2max norms vary by age/sex. Rough: excellent for 30yo male = 48+
            let vo2Expected = max(25, 52 - Double(chronAge) * 0.4)
            let vo2Delta = (vo2Data.value - vo2Expected) / vo2Expected
            let vo2Impact = -vo2Delta * 15
            ageAdjustments.append(vo2Impact)
            components.append(BioAgeComponent(
                id: "vo2", label: "VO₂ max", icon: "lungs.fill",
                colorHex: "059669", valueText: String(format: "%.1f", vo2Data.value),
                impact: vo2Impact, weight: 0.3
            ))
        }

        // Weighted average
        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let weightedAdjustment = components.reduce(0.0) { $0 + $1.impact * $1.weight } / max(0.01, totalWeight)

        let estimatedAge = max(16, chronAge + Int(weightedAdjustment.rounded()))
        let delta = estimatedAge - chronAge

        let summaryText: String
        if delta <= -3 {
            summaryText = "Your biomarkers suggest physiological fitness well ahead of your age. Keep it up."
        } else if delta < 0 {
            summaryText = "Slightly younger than your calendar age — your recovery and cardio metrics look healthy."
        } else if delta == 0 {
            summaryText = "Right on track — your biological markers match your chronological age."
        } else if delta <= 3 {
            summaryText = "Slightly above your calendar age. Focus on sleep quality and consistent training."
        } else {
            summaryText = "Your markers suggest room for improvement. Prioritize sleep, recovery, and aerobic fitness."
        }

        bioAge = BiologicalAgeEstimate(
            estimatedAge: estimatedAge,
            chronologicalAge: chronAge,
            delta: delta,
            summaryText: summaryText,
            components: components
        )
        isLoading = false
    }
}

// MARK: - Data Types

private struct BiologicalAgeEstimate {
    let estimatedAge: Int
    let chronologicalAge: Int
    let delta: Int
    let summaryText: String
    let components: [BioAgeComponent]

    var deltaText: String {
        if delta < 0 { return "\(abs(delta)) years younger" }
        if delta > 0 { return "\(delta) years older" }
        return "Same as calendar age"
    }

    var deltaColor: Color {
        if delta < 0 { return Pulse.positive }
        if delta > 0 { return Pulse.critical }
        return Pulse.nutrition
    }
}

private struct BioAgeComponent: Identifiable {
    let id: String
    let label: String
    let icon: String
    let colorHex: String
    let valueText: String
    let impact: Double
    let weight: Double

    var impactText: String {
        if impact < -0.5 { return String(format: "%.0fy ↓", abs(impact)) }
        if impact > 0.5 { return String(format: "+%.0fy ↑", impact) }
        return "—"
    }

    var impactColor: Color {
        if impact < -0.5 { return Pulse.positive }
        if impact > 0.5 { return Pulse.critical }
        return .secondary
    }
}
