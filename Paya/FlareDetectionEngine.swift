import Foundation
import SwiftData
import SwiftUI

// MARK: - Chronic Condition
//
// The biometric signals this engine watches (resting HR, HRV, sleep,
// respiratory rate, wrist temperature, gait steadiness) are general
// inflammation/fatigue/illness markers, not specific to any one diagnosis —
// the mechanism already generalizes. What didn't generalize was the
// user-facing copy: the AI supplement-advice prompt and the condition
// toggle both hardcoded "rheumatoid arthritis" regardless of what the user
// actually has, which is a real problem for anyone using this for a
// different condition where fatigue/flares still track gym capacity.
enum ChronicCondition: String, Codable, CaseIterable, Identifiable {
    case rheumatoidArthritis
    case psoriaticArthritis
    case ankylosingSpondylitis
    case lupus
    case fibromyalgia
    case mecfs
    case longCovid
    case hypothyroidism
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rheumatoidArthritis: return "Rheumatoid arthritis"
        case .psoriaticArthritis: return "Psoriatic arthritis"
        case .ankylosingSpondylitis: return "Ankylosing spondylitis"
        case .lupus: return "Lupus"
        case .fibromyalgia: return "Fibromyalgia"
        case .mecfs: return "ME/CFS (chronic fatigue)"
        case .longCovid: return "Long COVID fatigue"
        case .hypothyroidism: return "Hypothyroidism"
        case .other: return "Other condition"
        }
    }

    /// Short clause for AI prompts — deliberately not a diagnosis claim,
    /// just naming what the user told the app so advice isn't generic.
    var promptClause: String {
        switch self {
        case .rheumatoidArthritis: return "rheumatoid arthritis"
        case .psoriaticArthritis: return "psoriatic arthritis"
        case .ankylosingSpondylitis: return "ankylosing spondylitis"
        case .lupus: return "lupus"
        case .fibromyalgia: return "fibromyalgia"
        case .mecfs: return "ME/CFS (myalgic encephalomyelitis / chronic fatigue syndrome)"
        case .longCovid: return "long COVID-related fatigue"
        case .hypothyroidism: return "hypothyroidism-related fatigue"
        case .other: return "a chronic condition affecting energy and joint/muscle comfort"
        }
    }
}

// MARK: - Flare Risk Level

enum FlareRiskLevel: String, Codable {
    case low
    case moderate
    case elevated
    case high

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .elevated: return "Elevated"
        case .high: return "High"
        }
    }

    var color: Color {
        switch self {
        case .low:      return Color(hex: "059669")
        case .moderate: return Color(hex: "B45309")
        case .elevated: return Color(hex: "EA580C")
        case .high:     return Color(hex: "DC2626")
        }
    }

    var icon: String {
        switch self {
        case .low:      return "checkmark.shield.fill"
        case .moderate: return "exclamationmark.triangle"
        case .elevated: return "exclamationmark.triangle.fill"
        case .high:     return "flame.fill"
        }
    }
}

// MARK: - Confidence Level

enum ConfidenceLevel: String {
    case learning      // < 14 days of data
    case building      // 14-30 days
    case calibrated    // 30+ days
    case personalized  // 30+ days AND has learned from 3+ flare episodes

    var displayName: String {
        switch self {
        case .learning:     return "Learning your baseline"
        case .building:     return "Building your model"
        case .calibrated:   return "Calibrated"
        case .personalized: return "Personalized"
        }
    }

    var subtitle: String {
        switch self {
        case .learning:     return "Log daily for accurate detection"
        case .building:     return "Getting to know your normal ranges"
        case .calibrated:   return "Based on your 30-day averages"
        case .personalized: return "Trained on your flare patterns"
        }
    }
}

// MARK: - Flare Risk Assessment

struct FlareRiskAssessment {
    let level: FlareRiskLevel
    let score: Int              // 0-100
    let factors: [FlareFactor]
    let recommendation: String
    let confidence: ConfidenceLevel

    struct FlareFactor: Identifiable {
        let id = UUID()
        let name: String
        let observation: String
        let severity: Int        // 0-3
        let icon: String
    }
}

// MARK: - Flare Detection Engine
//
// Each biometric SIGNAL this engine watches has real physiological
// grounding as an early-warning marker, even though the exact scoring
// weights below (the ×15/×10 multipliers, the 60/40/20 score bands, the
// "reduce weight 25%" figure) are this app's own tuning on top of those
// signals, not numbers taken directly from a study — worth being explicit
// about that distinction rather than implying false precision.
//
//   - Elevated resting HR & suppressed HRV as illness/overreaching
//     precursors: Plews DJ, Laursen PB, Kilding AE, Buchheit M. "Training
//     Adaptation and Heart Rate Variability in Elite Endurance Athletes:
//     Opening the Door to Effective Monitoring." Sports Med. 2013;
//     Halson SL. "Monitoring Training Load to Understand Fatigue in
//     Athletes." Sports Med. 2014.
//   - Respiratory rate as an inflammation/deterioration marker: used as one
//     of the most sensitive vital signs in clinical early-warning scoring
//     (e.g. the UK's NEWS2 protocol, Royal College of Physicians 2017).
//   - Sleep disruption preceding/correlating with RA disease activity:
//     Løppenthin K, et al. "Sleep quality and correlates of poor sleep in
//     patients with rheumatoid arthritis." Clin Rheumatol. 2015;
//     Irwin MR, et al. "Sleep Disturbance, Sleep Duration, and
//     Inflammation: A Systematic Review." Biol Psychiatry. 2016.
@MainActor
@Observable
class FlareDetectionEngine {

    static let shared = FlareDetectionEngine()

    // MARK: - Assessment

    func assess(
        biometrics: BiometricStore,
        healthLogs: [HealthLog],
        pressureDropKPa: Double? = nil,
        todaysNoiseDb: Double? = nil
    ) -> FlareRiskAssessment {

        let confidence = determineConfidence(
            historyDays: biometrics.history.count,
            healthLogs: healthLogs
        )

        // Compute personal thresholds if we have enough data
        let thresholds = computePersonalThresholds(
            biometrics: biometrics,
            healthLogs: healthLogs
        )

        var score = 0
        var factors: [FlareRiskAssessment.FlareFactor] = []

        // Signal 1: Resting HR elevation
        if let rhrZ = biometrics.zScoreToday(for: .restingHR) {
            if rhrZ > thresholds.restingHRZThreshold {
                let sev = min(3, Int(rhrZ.rounded()))
                score += sev * 15
                factors.append(.init(
                    name: "Resting HR",
                    observation: String(format: "%.1f std devs above normal", rhrZ),
                    severity: sev,
                    icon: "heart.fill"
                ))
            }
        }

        // Signal 2: HRV suppression
        if let hrvZ = biometrics.zScoreToday(for: .hrv) {
            if hrvZ < thresholds.hrvZThreshold {
                let sev = min(3, Int(abs(hrvZ).rounded()))
                score += sev * 15
                factors.append(.init(
                    name: "HRV",
                    observation: String(format: "%.1f std devs below normal", hrvZ),
                    severity: sev,
                    icon: "waveform.path.ecg"
                ))
            }
        }

        // Signal 3: Sleep
        if let sleep = biometrics.today?.sleepHours {
            if sleep < thresholds.minSleepHours {
                let sev = sleep < (thresholds.minSleepHours - 1) ? 3 : 2
                score += sev * 10
                factors.append(.init(
                    name: "Sleep",
                    observation: String(format: "%.1fh (below your %.1fh threshold)", sleep, thresholds.minSleepHours),
                    severity: sev,
                    icon: "moon.zzz.fill"
                ))
            }
        }

        // Signal 3b: Self-reported joint pain — the one signal that was
        // captured (the Health tab's joint pain slider persists it on every
        // HealthLog) but never actually fed into the risk score until now.
        // For an RA-flare detector specifically, the patient's own reported
        // joint pain is at least as informative as any biometric proxy —
        // arguably more direct, since it's the thing being predicted, not a
        // correlate of it.
        if let todaysPain = healthLogs.first(where: { Calendar.current.isDateInToday($0.date) })?.jointPainLevel {
            if todaysPain >= 4 {
                let sev = todaysPain >= 8 ? 3 : (todaysPain >= 6 ? 2 : 1)
                score += sev * 15
                factors.append(.init(
                    name: "Joint Pain",
                    observation: "\(todaysPain)/10 reported today",
                    severity: sev,
                    icon: "figure.walk.motion"
                ))
            }
        }

        // Signal 4: Multi-day trend
        if let yesterdayRHR = biometrics.yesterday?.restingHR,
           let todayRHR = biometrics.today?.restingHR,
           let baseline = biometrics.baseline(for: .restingHR),
           yesterdayRHR > baseline.mean && todayRHR > baseline.mean {
            score += 10
            factors.append(.init(
                name: "Trend",
                observation: "Elevated RHR two days running",
                severity: 2,
                icon: "chart.line.uptrend.xyaxis"
            ))
        }

        // Signal 5: Respiratory rate spike (RA inflammation marker)
        if let respZ = biometrics.zScoreToday(for: .respiratoryRate),
           respZ > 1.5 {
            let sev = min(3, Int(respZ.rounded()))
            score += sev * 10
            factors.append(.init(
                name: "Respiratory Rate",
                observation: String(format: "%.1f std devs above normal", respZ),
                severity: sev,
                icon: "lungs.fill"
            ))
        }

        // Signal 7: Wrist temperature elevation — Apple's overnight
        // sleeping-wrist-temperature reading (Watch Series 8+/Ultra).
        // Elevated skin temperature is a real, if nonspecific, systemic
        // inflammation/illness marker (Mackowiak PA. "Concepts of fever."
        // Arch Intern Med. 1998; body-temperature elevation as an
        // inflammatory response is textbook physiology) — nonspecific
        // because it also rises with ambient heat, illness unrelated to RA,
        // or alcohol, so this is one input among several, not a diagnosis.
        if let tempZ = biometrics.zScoreToday(for: .wristTemp), tempZ > 1.5 {
            let sev = min(3, Int(tempZ.rounded()))
            score += sev * 10
            factors.append(.init(
                name: "Wrist Temperature",
                observation: String(format: "%.1f std devs above your normal", tempZ),
                severity: sev,
                icon: "thermometer.medium"
            ))
        }

        // Signal 8: Reduced walking steadiness — Apple's gait-stability
        // score (derived from iPhone motion sensors during regular
        // walking). Originally built for fall-risk research, but reduced
        // gait steadiness and asymmetry are also documented correlates of
        // active joint pain/inflammation affecting the lower body in
        // arthritis research (e.g. Turcot K, et al. "Test-retest
        // reliability and best indicators of soft tissue artifact of
        // knee kinematic measurements... in patients with knee
        // osteoarthritis." Gait Posture. 2010, among broader
        // arthritis-gait literature) — a passive signal that doesn't
        // require logging anything.
        if let steadinessZ = biometrics.zScoreToday(for: .walkingSteadiness), steadinessZ < -1.0 {
            let sev = min(3, Int(abs(steadinessZ).rounded()))
            score += sev * 10
            factors.append(.init(
                name: "Walking Steadiness",
                observation: String(format: "%.1f std devs below your normal", steadinessZ),
                severity: sev,
                icon: "figure.walk.motion"
            ))
        }

        // Signal 9: Sharp barometric pressure drop — the Flare Risk Factors
        // card already flags this against the same threshold (Timmermans
        // EJ, et al. "Weather Conditions and Joint Pain in Older People."
        // Pain Medicine, 2015), but until now that card and this score were
        // two disconnected features describing the same risk.
        if let drop = pressureDropKPa, drop >= 1.0 {
            let sev = drop >= 2.0 ? 3 : 2
            score += sev * 10
            factors.append(.init(
                name: "Barometric Pressure",
                observation: String(format: "↓ %.1f kPa vs yesterday", drop),
                severity: sev,
                icon: "barometer"
            ))
        }

        // Signal 10: Elevated ambient noise — WHO environmental noise
        // guidance flags sustained exposure above ~70dB as a stress driver,
        // and stress is a documented flare trigger across inflammatory
        // conditions (Straub RH, Cutolo M. "Psychoneuroimmunology: A
        // Fascinating Global Player in Rheumatology." J Rheumatol
        // Suppl. 2016).
        if let noise = todaysNoiseDb, noise >= 70 {
            let sev = noise >= 80 ? 3 : 2
            score += sev * 8
            factors.append(.init(
                name: "Ambient Noise",
                observation: String(format: "%.0f dB avg today", noise),
                severity: sev,
                icon: "waveform"
            ))
        }

        // Signal 6: Prior-flare pattern matching (only if personalized)
        if confidence == .personalized {
            let matchScore = matchPastFlarePattern(
                biometrics: biometrics,
                healthLogs: healthLogs
            )
            if matchScore > 0 {
                score += matchScore
                factors.append(.init(
                    name: "Pattern match",
                    observation: "Similar to your last flare precursor",
                    severity: matchScore > 15 ? 3 : 2,
                    icon: "brain.head.profile"
                ))
            }
        }

        // Determine level
        let level: FlareRiskLevel = {
            if score >= 60 { return .high }
            if score >= 40 { return .elevated }
            if score >= 20 { return .moderate }
            return .low
        }()

        // Recommendation
        let recommendation: String = {
            switch level {
            case .low:      return "All systems normal. Train as planned."
            case .moderate: return "Consider lighter loads today. Avoid pushing to failure."
            case .elevated: return "Strong signal of stress. Reduce weight 25%, prioritize recovery."
            case .high:     return "Skip heavy training. Focus on gentle mobility, sleep, and hydration."
            }
        }()

        return FlareRiskAssessment(
            level: level,
            score: min(100, score),
            factors: factors,
            recommendation: recommendation,
            confidence: confidence
        )
    }

    // MARK: - Personal Thresholds

    struct PersonalThresholds {
        var restingHRZThreshold: Double  // std devs above baseline
        var hrvZThreshold: Double        // std devs below baseline (negative)
        var minSleepHours: Double
    }

    /// Learns thresholds from user's actual flare-day patterns.
    /// Defaults tighten as more flare data accumulates.
    func computePersonalThresholds(
        biometrics: BiometricStore,
        healthLogs: [HealthLog]
    ) -> PersonalThresholds {

        var thresholds = PersonalThresholds(
            restingHRZThreshold: 1.0,
            hrvZThreshold: -1.0,
            minSleepHours: 6.5
        )

        // Find pre-flare days (day before or day of a logged flare)
        let flareDates = healthLogs
            .filter { $0.isFlareDay }
            .map { Calendar.current.startOfDay(for: $0.date) }

        guard flareDates.count >= 3 else { return thresholds }

        // Get biometrics for day-before-flare
        let preFlareDays = flareDates.compactMap { flareDate -> DailySummary? in
            let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: flareDate) ?? flareDate
            return biometrics.history.first {
                Calendar.current.isDate($0.date, inSameDayAs: previousDay)
            }
        }

        guard !preFlareDays.isEmpty else { return thresholds }

        // Learn from patterns
        if let overallHR = biometrics.baseline(for: .restingHR, days: 60) {
            let preFlareHRs = preFlareDays.compactMap { $0.restingHR }
            if !preFlareHRs.isEmpty {
                let avgPreFlareHR = preFlareHRs.reduce(0, +) / Double(preFlareHRs.count)
                let avgZ = (avgPreFlareHR - overallHR.mean) / max(overallHR.stdDev, 1)
                thresholds.restingHRZThreshold = max(0.5, avgZ * 0.8)
            }
        }

        if let overallHRV = biometrics.baseline(for: .hrv, days: 60) {
            let preFlareHRVs = preFlareDays.compactMap { $0.hrv }
            if !preFlareHRVs.isEmpty {
                let avgPreFlareHRV = preFlareHRVs.reduce(0, +) / Double(preFlareHRVs.count)
                let avgZ = (avgPreFlareHRV - overallHRV.mean) / max(overallHRV.stdDev, 1)
                thresholds.hrvZThreshold = min(-0.5, avgZ * 0.8)
            }
        }

        let preFlareSleep = preFlareDays.compactMap { $0.sleepHours }
        if !preFlareSleep.isEmpty {
            let avgSleep = preFlareSleep.reduce(0, +) / Double(preFlareSleep.count)
            thresholds.minSleepHours = max(5.5, min(7.5, avgSleep + 0.5))
        }

        return thresholds
    }

    // MARK: - Pattern matching

    /// Compares today's biometric signature to averaged pre-flare signature.
    /// Returns 0-25 similarity score.
    private func matchPastFlarePattern(
        biometrics: BiometricStore,
        healthLogs: [HealthLog]
    ) -> Int {
        let flareDates = healthLogs
            .filter { $0.isFlareDay }
            .map { Calendar.current.startOfDay(for: $0.date) }

        guard flareDates.count >= 3 else { return 0 }

        let preFlareDays = flareDates.compactMap { flareDate -> DailySummary? in
            let previousDay = Calendar.current.date(byAdding: .day, value: -1, to: flareDate) ?? flareDate
            return biometrics.history.first {
                Calendar.current.isDate($0.date, inSameDayAs: previousDay)
            }
        }

        guard !preFlareDays.isEmpty, let today = biometrics.today else { return 0 }

        // Aggregate pre-flare signature
        let avgHR = preFlareDays.compactMap { $0.restingHR }.reduce(0, +) / Double(max(1, preFlareDays.count))
        let avgHRV = preFlareDays.compactMap { $0.hrv }.reduce(0, +) / Double(max(1, preFlareDays.count))
        let avgSleep = preFlareDays.compactMap { $0.sleepHours }.reduce(0, +) / Double(max(1, preFlareDays.count))

        var similarity = 0
        if let todayHR = today.restingHR, avgHR > 0 {
            let diff = abs(todayHR - avgHR) / avgHR
            if diff < 0.05 { similarity += 8 }
            else if diff < 0.10 { similarity += 4 }
        }
        if let todayHRV = today.hrv, avgHRV > 0 {
            let diff = abs(todayHRV - avgHRV) / avgHRV
            if diff < 0.10 { similarity += 8 }
            else if diff < 0.20 { similarity += 4 }
        }
        if let todaySleep = today.sleepHours, avgSleep > 0 {
            let diff = abs(todaySleep - avgSleep) / avgSleep
            if diff < 0.10 { similarity += 9 }
            else if diff < 0.20 { similarity += 5 }
        }

        return similarity
    }

    // MARK: - Confidence

    private func determineConfidence(
        historyDays: Int,
        healthLogs: [HealthLog]
    ) -> ConfidenceLevel {
        let flareCount = healthLogs.filter { $0.isFlareDay }.count

        if historyDays >= 30 && flareCount >= 3 {
            return .personalized
        }
        if historyDays >= 30 {
            return .calibrated
        }
        if historyDays >= 14 {
            return .building
        }
        return .learning
    }
}
