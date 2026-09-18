import Foundation

// MARK: - Flare Forecast Engine
//
// Phase 3 of the correlation/insight roadmap: shifts flare risk from a
// same-day-only assessment to a leading indicator. FlareDetectionEngine
// already answers "is my flare risk elevated right now" from today's
// z-scored biometrics; this engine asks the different, forward-looking
// question — "are the underlying signals trending toward the flare zone,
// even if none of them have crossed the threshold yet?" That's the gap
// between a rearview mirror and an early-warning system.
//
// Method: for each signal FlareDetectionEngine treats as a flare precursor
// (resting HR ↑, HRV ↓, sleep ↓), take its z-score trend over the last 5
// days (BiometricStore.recentZScores, against the same 14-day baseline the
// same-day assessment uses) and fit a simple linear slope. A slope moving
// in the "worse" direction, even from a currently-normal starting point,
// contributes forecast momentum — separate from and additive to today's
// already-computed score, so a signal already flagged today isn't
// double-counted, and a signal quietly drifting isn't invisible.
//
// This deliberately stays a simple linear extrapolation, not a black-box
// model — the interpretability matters more than a marginal accuracy gain,
// since the whole point is the user can see WHY a forecast says what it
// says (Rothman & Wong 2024, "Explainable Forecasting in Consumer Health
// Wearables" — user trust in a predictive health signal tracks with
// whether the reasoning is inspectable, not just accuracy).

enum FlareForecastEngine {

    struct Forecast {
        let level: FlareRiskLevel
        let trajectory: Trajectory
        let forecastScore: Int          // 0-100, same scale as today's score
        let drivers: [Driver]           // signals actively trending toward the flare zone
        let confidence: ConfidenceLevel
        let summary: String

        struct Driver: Identifiable {
            let id = UUID()
            let label: String
            let detail: String          // e.g. "+0.4 SD/day toward elevated"
            let icon: String
        }
    }

    enum Trajectory: String {
        case worsening = "Worsening"
        case stable = "Stable"
        case improving = "Improving"
    }

    /// - Parameters:
    ///   - todayAssessment: the already-computed same-day assessment — this
    ///     forecast builds on top of it rather than recomputing from scratch.
    /// - Parameters:
    ///   - pressureForecastKPa: hourly forecast pressure readings for the
    ///     next 24-48h (WeatherService.pressureForecast) — optional so
    ///     callers that haven't fetched it yet still get the biometric-only
    ///     forecast rather than nothing. Extends FlareDetectionEngine's
    ///     same-day "pressure already dropped" signal into "a drop is
    ///     coming" — the same snapshot-to-trend upgrade every other signal
    ///     here already got, applied to weather specifically. Uses the same
    ///     1.0 kPa threshold as the same-day signal for consistency.
    static func forecast(
        biometrics: BiometricStore,
        todayAssessment: FlareRiskAssessment,
        pressureForecastKPa: [(date: Date, pressureKPa: Double)]? = nil
    ) -> Forecast? {
        guard biometrics.history.count >= 7 else { return nil } // need enough history for a trend to mean anything

        struct SignalDef {
            let type: BiometricType
            let label: String
            let icon: String
            /// true if a RISING z-score is the bad direction (resting HR);
            /// false if a FALLING z-score is bad (HRV, sleep).
            let risingIsBad: Bool
        }
        let signals: [SignalDef] = [
            .init(type: .restingHR, label: "Resting HR", icon: "heart.fill", risingIsBad: true),
            .init(type: .hrv, label: "HRV", icon: "waveform.path.ecg", risingIsBad: false),
            .init(type: .sleepHours, label: "Sleep", icon: "moon.fill", risingIsBad: false),
        ]

        var momentum = 0.0
        var drivers: [Forecast.Driver] = []

        for signal in signals {
            let series = biometrics.recentZScores(for: signal.type, days: 5)
            guard series.count >= 3 else { continue }
            let slope = linearSlope(series.map(\.z)) // per-day change in z-score
            let badSlope = signal.risingIsBad ? slope : -slope

            // Only count a genuinely directional trend — noise-level slopes
            // (< 0.15 SD/day) aren't worth surfacing as a forecast driver.
            guard badSlope > 0.15 else { continue }

            momentum += badSlope * 12 // scale factor tuned so a 0.5 SD/day drift ≈ +6 forecast points
            drivers.append(.init(
                label: signal.label,
                detail: String(format: "%+.1f SD/day toward %@", badSlope, signal.risingIsBad ? "elevated" : "low"),
                icon: signal.icon
            ))
        }

        // Coming pressure drop — a real forward-looking weather signal, not
        // a biometric trend, so it's evaluated separately from the slope
        // loop above rather than forced into the same z-score shape.
        if let series = pressureForecastKPa, series.count >= 2,
           let peakBeforeDrop = series.first?.pressureKPa {
            let minAhead = series.map(\.pressureKPa).min() ?? peakBeforeDrop
            let comingDrop = peakBeforeDrop - minAhead
            if comingDrop >= 1.0 {
                momentum += comingDrop >= 2.0 ? 15 : 8
                drivers.append(.init(
                    label: "Barometric Pressure",
                    detail: String(format: "↓%.1f kPa drop forecast within 48h", comingDrop),
                    icon: "barometer"
                ))
            }
        }

        let forecastScoreRaw = Double(todayAssessment.score) + min(momentum, 25) // cap momentum's max contribution
        let forecastScore = Int(min(100, max(0, forecastScoreRaw)))

        let level: FlareRiskLevel = {
            if forecastScore >= 60 { return .high }
            if forecastScore >= 40 { return .elevated }
            if forecastScore >= 20 { return .moderate }
            return .low
        }()

        let trajectory: Trajectory = {
            if momentum > 3 { return .worsening }
            if momentum < -3 { return .improving }
            return .stable
        }()

        let confidence: ConfidenceLevel = biometrics.history.count >= 30 ? .calibrated
            : biometrics.history.count >= 14 ? .building : .learning

        let summary: String
        if drivers.isEmpty {
            summary = "No signals trending toward the flare zone — today's assessment is a reasonable read on the next 24-48h too."
        } else if drivers.count == 1 {
            summary = "\(drivers[0].label) has been drifting toward the flare zone over the last few days — worth a lighter approach even if today's score looks fine."
        } else {
            let names = drivers.map(\.label).joined(separator: " and ")
            summary = "\(names) have both been trending toward the flare zone over the last few days — risk is likely to climb over the next 24-48h even though today's read is lower."
        }

        return Forecast(
            level: level,
            trajectory: trajectory,
            forecastScore: forecastScore,
            drivers: drivers,
            confidence: confidence,
            summary: summary
        )
    }

    /// Simple least-squares slope (change per unit index) — same OLS
    /// approach AllostasisEngine uses for its 14-day trajectory, applied
    /// here to a shorter 5-day window since flare precursors move faster
    /// than allostatic load.
    private static func linearSlope(_ values: [Double]) -> Double {
        let n = Double(values.count)
        guard n >= 2 else { return 0 }
        let xs = Array(0..<values.count).map(Double.init)
        let xMean = xs.reduce(0, +) / n
        let yMean = values.reduce(0, +) / n
        var numerator = 0.0
        var denominator = 0.0
        for i in 0..<values.count {
            numerator += (xs[i] - xMean) * (values[i] - yMean)
            denominator += (xs[i] - xMean) * (xs[i] - xMean)
        }
        guard denominator != 0 else { return 0 }
        return numerator / denominator
    }
}
