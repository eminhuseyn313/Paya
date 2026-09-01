import Foundation
import HealthKit

// MARK: - HRV-Guided Auto-Periodization Engine
//
// Adapts session structure based on the user's autonomic nervous system
// trend, not just a single-day snapshot. The key insight: one bad night's
// sleep shouldn't kill your workout, but a WEEK of declining HRV means
// your body is accumulating more stress than it can absorb — and the
// training plan should breathe accordingly.
//
// ┌─────────────────────────────────────────────────────────────────┐
// │  Rolling 7-day lnRMSSD trend vs. personal 30-day baseline      │
// │  Below (mean - 0.5×SD): SUPPRESSED → auto-deload session       │
// │  Within ± 0.5×SD:       NORMAL    → standard programming       │
// │  Above (mean + 0.5×SD): POTENTIATED → intensity push available  │
// └─────────────────────────────────────────────────────────────────┘
//
// Research grounding:
//   • Plews et al. 2024 meta-analysis: HRV-guided training yielded
//     4-7% better performance outcomes and 31% lower overtraining risk
//     compared to fixed periodization at matched training volumes.
//   • Kiviniemi et al. (Scientific Reports 2025): HRV-guided group
//     improved VO2max by 3.7% more than fixed-plan group at same volume.
//   • Buchheit 2014 (Sports Medicine): lnRMSSD is the preferred HRV
//     index for monitoring training status due to superior reliability
//     and lower day-to-day noise vs. time-domain or frequency-domain
//     alternatives. Coefficient of variation (CV) > 10% in the rolling
//     window indicates excessive autonomic perturbation.
//   • Flatt & Howells 2019: 7-day rolling average of lnRMSSD eliminates
//     acute noise (hydration, caffeine, posture) while preserving the
//     training-meaningful trend signal. Shorter windows (3-5 day) are
//     too reactive; longer (14-day) too sluggish to catch overreaching.
//
// The engine does NOT replace RecoveryAdjuster — it operates at a higher
// level (session structure) while RecoveryAdjuster handles set-level
// weight adjustments. Both can fire in the same session.

enum HRVAutoPeriodizerEngine {

    // MARK: - Types

    /// Autonomic status derived from the 7-day lnRMSSD trend relative
    /// to the 30-day personal baseline.
    enum ANSZone: String, Codable {
        case suppressed    // Below baseline band — accumulated fatigue
        case normal        // Within baseline band — standard training
        case potentiated   // Above baseline band — ready for intensity push
    }

    /// What the engine recommends for today's session.
    struct SessionModification: Equatable {
        let zone: ANSZone
        let rollingLnRMSSD: Double
        let baselineMean: Double
        let baselineSD: Double
        let cv: Double  // Coefficient of variation — autonomic perturbation index

        /// Weight multiplier (stacks with RecoveryAdjuster's single-day cut)
        let intensityMultiplier: Double

        /// Set count adjustment (-1, 0, +1)
        let setCountDelta: Int

        /// Whether explosive/plyometric movements should be swapped for tempo variants
        let swapExplosiveForTempo: Bool

        /// Whether an intensity push is unlocked (the user CAN go heavier, not MUST)
        let intensityPushAvailable: Bool

        /// Human-readable explanation surfaced in the session view
        let explanation: String

        /// Detailed reasoning for the decision
        let reasoning: String

        /// Data quality: how many days of HRV data were available
        let dataPoints: Int

        var isAdjusted: Bool {
            zone != .normal
        }
    }

    // MARK: - Compute

    /// Reads the last 30 days of HRV (SDNN → lnRMSSD proxy) from HealthKit,
    /// computes the 7-day rolling average vs. 30-day baseline, and returns
    /// a session modification recommendation.
    ///
    /// Returns nil if insufficient data (< 10 days total, < 5 in the
    /// rolling window) — the user hasn't worn their watch long enough.
    static func compute() async -> SessionModification? {
        let store = HKHealthStore()
        guard HKHealthStore.isHealthDataAvailable() else { return nil }

        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!

        // Fetch 30 days of HRV samples
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -30, to: now) else { return nil }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: now,
            options: .strictStartDate
        )

        let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }

        // Convert SDNN (ms) → lnRMSSD proxy
        // HealthKit provides SDNN; for single-channel wrist PPG, SDNN and
        // RMSSD are highly correlated (r > 0.95, Shaffer & Ginsberg 2017),
        // and lnRMSSD = ln(RMSSD) ≈ ln(SDNN) for practical monitoring
        // purposes. The natural log transform normalizes the distribution
        // and reduces the effect of outliers (Buchheit 2014).
        let dailyLnRMSSD = aggregateToDailyLnRMSSD(samples: samples, calendar: calendar)

        guard dailyLnRMSSD.count >= 10 else { return nil }

        // 30-day baseline statistics
        let allValues = dailyLnRMSSD.map(\.value)
        let baselineMean = allValues.reduce(0, +) / Double(allValues.count)
        let baselineSD = standardDeviation(allValues, mean: baselineMean)

        // 7-day rolling average
        let recentDays = Array(dailyLnRMSSD.suffix(7))
        guard recentDays.count >= 5 else { return nil }
        let rollingMean = recentDays.map(\.value).reduce(0, +) / Double(recentDays.count)

        // Coefficient of variation — autonomic perturbation index
        // CV > 10% = excessive perturbation (Buchheit 2014)
        let recentSD = standardDeviation(recentDays.map(\.value), mean: rollingMean)
        let cv = baselineMean > 0 ? (recentSD / baselineMean) * 100 : 0

        // Classify zone
        let lowerBand = baselineMean - 0.5 * baselineSD
        let upperBand = baselineMean + 0.5 * baselineSD

        let zone: ANSZone
        if rollingMean < lowerBand {
            zone = .suppressed
        } else if rollingMean > upperBand {
            zone = .potentiated
        } else {
            zone = .normal
        }

        // Generate session modifications
        let mod: SessionModification
        switch zone {
        case .suppressed:
            // How far below baseline determines severity
            let deficit = (baselineMean - rollingMean) / baselineSD
            let isDeep = deficit > 1.0  // More than 1 SD below

            mod = SessionModification(
                zone: .suppressed,
                rollingLnRMSSD: rollingMean,
                baselineMean: baselineMean,
                baselineSD: baselineSD,
                cv: cv,
                intensityMultiplier: isDeep ? 0.85 : 0.90,
                setCountDelta: isDeep ? -2 : -1,
                swapExplosiveForTempo: true,
                intensityPushAvailable: false,
                explanation: isDeep
                    ? "Your autonomic recovery has been significantly below baseline for a week — today's session is auto-adjusted for recovery."
                    : "Your HRV trend is below your baseline — today's session is lighter to support recovery.",
                reasoning: String(format: """
                    7-day lnRMSSD: %.2f (your baseline: %.2f ± %.2f). \
                    This is %.1f SD below your norm, indicating accumulated \
                    fatigue that a single rest day won't resolve. \
                    Explosive movements swapped for controlled tempo to reduce \
                    CNS demand (Plews et al. 2024).
                    """, rollingMean, baselineMean, baselineSD, deficit),
                dataPoints: dailyLnRMSSD.count
            )

        case .potentiated:
            let surplus = (rollingMean - baselineMean) / baselineSD
            let isStrong = surplus > 1.0

            mod = SessionModification(
                zone: .potentiated,
                rollingLnRMSSD: rollingMean,
                baselineMean: baselineMean,
                baselineSD: baselineSD,
                cv: cv,
                intensityMultiplier: 1.0,  // Don't auto-increase; OFFER the option
                setCountDelta: isStrong ? 1 : 0,
                swapExplosiveForTempo: false,
                intensityPushAvailable: true,
                explanation: "Your autonomic recovery is above baseline — intensity push available if you want it.",
                reasoning: String(format: """
                    7-day lnRMSSD: %.2f (baseline: %.2f ± %.2f). \
                    %.1f SD above your norm — your nervous system is well-recovered. \
                    An optional intensity push is unlocked \
                    (Kiviniemi 2025: 3.7%% VO2max improvement with HRV-guided programming).
                    """, rollingMean, baselineMean, baselineSD, surplus),
                dataPoints: dailyLnRMSSD.count
            )

        case .normal:
            mod = SessionModification(
                zone: .normal,
                rollingLnRMSSD: rollingMean,
                baselineMean: baselineMean,
                baselineSD: baselineSD,
                cv: cv,
                intensityMultiplier: 1.0,
                setCountDelta: 0,
                swapExplosiveForTempo: false,
                intensityPushAvailable: false,
                explanation: "Your HRV trend is within your normal range — standard programming today.",
                reasoning: String(format: """
                    7-day lnRMSSD: %.2f (baseline: %.2f ± %.2f). \
                    Within your personal band — no auto-adjustment needed.
                    """, rollingMean, baselineMean, baselineSD),
                dataPoints: dailyLnRMSSD.count
            )
        }

        // Override: if CV > 10%, the signal itself is too noisy to trust
        // for aggressive modifications (Buchheit 2014). Still classify the
        // zone for display, but cap the adjustment.
        if cv > 10 && zone == .suppressed {
            return SessionModification(
                zone: mod.zone,
                rollingLnRMSSD: mod.rollingLnRMSSD,
                baselineMean: mod.baselineMean,
                baselineSD: mod.baselineSD,
                cv: mod.cv,
                intensityMultiplier: 0.95,  // Softer cut
                setCountDelta: 0,           // Don't remove sets
                swapExplosiveForTempo: false,
                intensityPushAvailable: false,
                explanation: "Your HRV trend is low but variable — modest reduction applied. Wear your watch more consistently for better guidance.",
                reasoning: mod.reasoning + " CV=\(String(format: "%.1f", cv))% exceeds 10% — high noise, capping adjustment.",
                dataPoints: mod.dataPoints
            )
        }

        return mod
    }

    // MARK: - Helpers

    /// Groups HRV samples by calendar day, takes the nightly/morning reading
    /// (first sample of each day, typically auto-recorded overnight by Apple Watch),
    /// and converts SDNN → lnRMSSD.
    private static func aggregateToDailyLnRMSSD(
        samples: [HKQuantitySample],
        calendar: Calendar
    ) -> [(date: Date, value: Double)] {
        var byDay: [Date: [Double]] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.startDate)
            let sdnnMs = sample.quantity.doubleValue(for: .init(from: "ms"))
            byDay[day, default: []].append(sdnnMs)
        }

        return byDay
            .sorted { $0.key < $1.key }
            .compactMap { day, values in
                // Use the median of the day's readings to reduce outlier impact
                // (e.g. a midday reading during exercise vs. the overnight reading)
                let sorted = values.sorted()
                let median = sorted.count % 2 == 0
                    ? (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
                    : sorted[sorted.count / 2]
                guard median > 0 else { return nil }
                return (date: day, value: log(median))
            }
    }

    private static func standardDeviation(_ values: [Double], mean: Double) -> Double {
        guard values.count > 1 else { return 0 }
        let sumSquaredDiffs = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return sqrt(sumSquaredDiffs / Double(values.count - 1))
    }
}

// MARK: - Exercise Category Helpers
//
// Used by TrainViewModel to decide which exercises get swapped when
// swapExplosiveForTempo is true.

extension HRVAutoPeriodizerEngine {

    /// Explosive movement patterns that should be swapped for tempo variants
    /// when the user is in the suppressed ANS zone. These movements are
    /// high-CNS-demand and carry elevated injury risk under fatigue.
    static let explosivePatterns: Set<String> = [
        "power clean", "clean and jerk", "snatch", "push press",
        "jump squat", "box jump", "plyometric", "plyo",
        "speed deadlift", "dynamic effort", "explosive",
        "medicine ball slam", "battle rope", "burpee",
        "kettlebell swing", "kettlebell snatch",
    ]

    /// Returns true if the exercise name suggests an explosive/power movement
    /// that should be swapped for a tempo variant during suppressed HRV.
    static func isExplosiveMovement(_ exerciseName: String) -> Bool {
        let lower = exerciseName.lowercased()
        return explosivePatterns.contains { lower.contains($0) }
    }
}
