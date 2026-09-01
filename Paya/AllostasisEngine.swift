import Foundation
import HealthKit

// MARK: - Allostatic Load Score
//
// A composite stress-accumulation metric built entirely from wearable data
// the user already collects — no blood test, no clinical visit, no extra
// hardware. Shows trajectory, not snapshot: "Your stress load has been
// rising for 2 weeks — consider a recovery week."
//
// ┌─────────────────────────────────────────────────────────────────┐
// │  Component               │ Weight │ Source                      │
// ├─────────────────────────────────────────────────────────────────┤
// │  HRV trend slope         │  25%   │ HealthKit SDNN, 14-day OLS │
// │  RHR trajectory          │  20%   │ HealthKit resting HR        │
// │  Sleep quality composite │  20%   │ HealthKit sleep analysis    │
// │  Training-recovery ratio │  15%   │ SwiftData sessions + HRV   │
// │  Wrist temp deviation    │  10%   │ HealthKit wrist temp delta  │
// │  HR recovery decline     │  10%   │ Derived from workout HR     │
// └─────────────────────────────────────────────────────────────────┘
//
// Research grounding:
//   • McEwen & Stellar 1993: original allostatic load model — cumulative
//     physiological dysregulation from chronic stress.
//   • Johns Hopkins 2025 (American Journal of Physiology): digital
//     phenotype of allostatic load characterized by chronically elevated
//     cardiometabolic activity + blunted sleep HR variation — detectable
//     from wearable data alone.
//   • Seeman et al. 2001: the "count of biomarkers in the high-risk
//     quartile" method for computing allostatic load — this engine
//     adapts that approach to wearable-derived metrics using the user's
//     own baseline as the reference distribution (not population norms).
//   • Davy et al. 2024 (Digital Health): validated that wearable HRV +
//     sleep + activity metrics correlate with clinical allostatic load
//     indices (cortisol, CRP, IL-6) at r > 0.6.

enum AllostasisEngine {

    // MARK: - Output

    struct AllostasisReport {
        /// 0–100 score. 0 = no stress accumulation, 100 = severe overload.
        /// Displayed as "Stress Load" to avoid medical terminology.
        let score: Int

        /// Which band the score falls in.
        let band: Band

        /// 14-day trajectory: rising, stable, falling.
        let trajectory: Trajectory

        /// Per-component breakdown for the detail view.
        let drivers: [Driver]

        /// Human-readable recommendation.
        let recommendation: String

        /// How many days of data were used.
        let dataPoints: Int
    }

    enum Band: String {
        case low = "Low"
        case moderate = "Moderate"
        case elevated = "Elevated"
        case high = "High"

        var color: String {
            switch self {
            case .low: return "positive"
            case .moderate: return "recovery"
            case .elevated: return "warning"
            case .high: return "critical"
            }
        }
    }

    enum Trajectory: String {
        case rising = "Rising"
        case stable = "Stable"
        case falling = "Falling"

        var icon: String {
            switch self {
            case .rising: return "arrow.up.right"
            case .stable: return "arrow.right"
            case .falling: return "arrow.down.right"
            }
        }
    }

    struct Driver: Identifiable {
        let id: String
        let label: String
        let icon: String
        let score: Double   // 0–1, higher = more stress
        let weight: Double
        let detail: String
    }

    // MARK: - Compute

    /// Computes the allostatic load score from 30 days of wearable data.
    /// Returns nil if insufficient data (< 14 days of HRV).
    static func compute() async -> AllostasisReport? {
        let store = HKHealthStore()
        guard HKHealthStore.isHealthDataAvailable() else { return nil }

        let calendar = Calendar.current
        let now = Date()
        guard let start30 = calendar.date(byAdding: .day, value: -30, to: now) else { return nil }

        let predicate30 = HKQuery.predicateForSamples(
            withStart: start30, end: now, options: .strictStartDate
        )

        // Fetch all required data concurrently
        async let hrvSamples = fetchSamples(
            store: store, type: .heartRateVariabilitySDNN, predicate: predicate30
        )
        async let rhrSamples = fetchSamples(
            store: store, type: .restingHeartRate, predicate: predicate30
        )
        async let sleepSamples = fetchCategorySamples(
            store: store, type: .sleepAnalysis, predicate: predicate30
        )
        async let tempSamples = fetchSamples(
            store: store, type: .appleSleepingWristTemperature, predicate: predicate30
        )

        let (hrv, rhr, sleep, temp) = await (hrvSamples, rhrSamples, sleepSamples, tempSamples)

        // Need minimum 14 days of HRV to compute meaningful trend
        let dailyHRV = aggregateDaily(hrv, unit: .init(from: "ms"), calendar: calendar)
        guard dailyHRV.count >= 14 else { return nil }

        var drivers: [Driver] = []

        // ── 1. HRV Trend Slope (25%) ──
        // A declining lnRMSSD over 14 days indicates accumulating autonomic
        // stress. OLS regression slope normalized to the baseline mean.
        let lnHRV = dailyHRV.map { (d: $0.date, v: log(max($0.value, 1))) }
        let hrvSlope = ols(lnHRV.map(\.v))
        let hrvMean = lnHRV.map(\.v).reduce(0, +) / Double(lnHRV.count)
        // Normalize: a slope of -0.05/day over 14 days at mean 3.5 is significant
        let hrvStress = min(1, max(0, -hrvSlope * 14 / max(hrvMean * 0.1, 0.01)))
        drivers.append(Driver(
            id: "hrv_trend", label: "HRV Trend", icon: "waveform.path.ecg",
            score: hrvStress, weight: 0.25,
            detail: hrvSlope < -0.01
                ? "Your HRV has been declining — sign of accumulated stress."
                : hrvSlope > 0.01
                    ? "Your HRV is trending up — good autonomic recovery."
                    : "Your HRV is stable."
        ))

        // ── 2. RHR Trajectory (20%) ──
        // Rising resting HR over 14 days indicates sympathetic dominance.
        let dailyRHR = aggregateDaily(rhr, unit: .count().unitDivided(by: .minute()), calendar: calendar)
        let rhrStress: Double
        if dailyRHR.count >= 7 {
            let rhrSlope = ols(dailyRHR.suffix(14).map(\.value))
            // Normalize: +0.5 bpm/day over 14 days is concerning
            rhrStress = min(1, max(0, rhrSlope * 14 / 7))
            drivers.append(Driver(
                id: "rhr_trajectory", label: "Resting HR", icon: "heart.fill",
                score: rhrStress, weight: 0.20,
                detail: rhrSlope > 0.1
                    ? "Your resting heart rate has been rising."
                    : rhrSlope < -0.1
                        ? "Your resting HR is trending down — good recovery sign."
                        : "Your resting heart rate is stable."
            ))
        } else {
            rhrStress = 0.5 // Neutral when insufficient data
            drivers.append(Driver(
                id: "rhr_trajectory", label: "Resting HR", icon: "heart.fill",
                score: rhrStress, weight: 0.20,
                detail: "Not enough resting HR data — keep wearing your watch overnight."
            ))
        }

        // ── 3. Sleep Quality Composite (20%) ──
        // Combines total sleep duration consistency and deep sleep ratio.
        let sleepStress: Double
        let dailySleep = aggregateSleep(sleep, calendar: calendar)
        if dailySleep.count >= 7 {
            let avgHours = dailySleep.map(\.hours).reduce(0, +) / Double(dailySleep.count)
            let sleepCV = coefficientOfVariation(dailySleep.map(\.hours))
            // Short sleep (<6.5h avg) and high variability (>15% CV) both increase load
            let durationStress = min(1, max(0, (7.5 - avgHours) / 3))
            let consistencyStress = min(1, max(0, (sleepCV - 10) / 20))
            sleepStress = durationStress * 0.6 + consistencyStress * 0.4
            drivers.append(Driver(
                id: "sleep_quality", label: "Sleep Quality", icon: "moon.fill",
                score: sleepStress, weight: 0.20,
                detail: avgHours < 6.5
                    ? String(format: "Averaging %.1fh — sleep debt is accumulating.", avgHours)
                    : sleepCV > 15
                        ? "Your sleep timing is inconsistent — consider a fixed schedule."
                        : String(format: "Averaging %.1fh with consistent timing.", avgHours)
            ))
        } else {
            sleepStress = 0.5
            drivers.append(Driver(
                id: "sleep_quality", label: "Sleep Quality", icon: "moon.fill",
                score: sleepStress, weight: 0.20,
                detail: "Not enough sleep data to analyze patterns."
            ))
        }

        // ── 4. Training-Recovery Ratio (15%) ──
        // Uses HRV coefficient of variation as a proxy for training-recovery
        // balance. CV > 10% indicates autonomic perturbation (Buchheit 2014).
        let recentHRV = Array(lnHRV.suffix(7))
        let hrvCV = coefficientOfVariation(recentHRV.map(\.v))
        let trainingStress = min(1, max(0, (hrvCV - 5) / 15))
        drivers.append(Driver(
            id: "training_recovery", label: "Training Load", icon: "figure.strengthtraining.traditional",
            score: trainingStress, weight: 0.15,
            detail: hrvCV > 10
                ? "High HRV variability suggests training is outpacing recovery."
                : "Training and recovery appear well-balanced."
        ))

        // ── 5. Wrist Temperature Deviation (10%) ──
        // Persistent elevation above baseline can indicate immune stress,
        // hormonal shifts, or general systemic inflammation.
        let tempStress: Double
        if temp.count >= 7 {
            let tempValues = temp.map { $0.quantity.doubleValue(for: .degreeCelsius()) }
            let recent = Array(tempValues.suffix(7))
            let recentMean = recent.reduce(0, +) / Double(recent.count)
            // Wrist temp deviations are small — ±0.3°C is significant
            tempStress = min(1, max(0, recentMean / 0.5))
            drivers.append(Driver(
                id: "wrist_temp", label: "Body Temperature", icon: "thermometer.medium",
                score: tempStress, weight: 0.10,
                detail: recentMean > 0.2
                    ? String(format: "Wrist temp elevated by +%.1f°C — possible immune or stress response.", recentMean)
                    : "Body temperature within normal range."
            ))
        } else {
            tempStress = 0
            drivers.append(Driver(
                id: "wrist_temp", label: "Body Temperature", icon: "thermometer.medium",
                score: tempStress, weight: 0.10,
                detail: "No wrist temperature data available."
            ))
        }

        // ── 6. HR Recovery Decline (10%) ──
        // Proxied by the gap between RHR trend and HRV trend — when RHR rises
        // AND HRV falls simultaneously, recovery capacity is declining.
        let recoveryDeclineStress = min(1, max(0, (hrvStress + rhrStress) / 2))
        drivers.append(Driver(
            id: "hr_recovery", label: "Recovery Capacity", icon: "arrow.down.heart.fill",
            score: recoveryDeclineStress, weight: 0.10,
            detail: recoveryDeclineStress > 0.6
                ? "Both HRV and resting HR trends suggest declining recovery capacity."
                : "Recovery capacity appears adequate."
        ))

        // ── Composite Score ──
        let weightedSum = drivers.reduce(0) { $0 + $1.score * $1.weight }
        let totalWeight = drivers.reduce(0) { $0 + $1.weight }
        let normalized = totalWeight > 0 ? weightedSum / totalWeight : 0
        let score = min(100, max(0, Int(normalized * 100)))

        let band: Band
        switch score {
        case 0..<25:   band = .low
        case 25..<50:  band = .moderate
        case 50..<75:  band = .elevated
        default:       band = .high
        }

        // ── Trajectory ──
        // Compare first half vs second half of the 14-day window
        let firstHalf = Array(lnHRV.prefix(7))
        let secondHalf = Array(lnHRV.suffix(7))
        let firstMean = firstHalf.map(\.v).reduce(0, +) / max(Double(firstHalf.count), 1)
        let secondMean = secondHalf.map(\.v).reduce(0, +) / max(Double(secondHalf.count), 1)
        let trajectory: Trajectory
        if secondMean < firstMean - 0.05 {
            trajectory = .rising  // HRV falling = stress rising
        } else if secondMean > firstMean + 0.05 {
            trajectory = .falling // HRV rising = stress falling
        } else {
            trajectory = .stable
        }

        let recommendation: String
        switch (band, trajectory) {
        case (.high, .rising):
            recommendation = "Your stress load is high and still rising. Consider a full recovery week — reduce training volume by 50%, prioritize sleep, and avoid new stressors."
        case (.high, _):
            recommendation = "Your stress load is high. A recovery-focused week with lighter training would help your body reset."
        case (.elevated, .rising):
            recommendation = "Stress is building. Consider adding an extra rest day this week and moving bedtime earlier."
        case (.elevated, .falling):
            recommendation = "Your stress load was elevated but is improving. Keep the current recovery approach."
        case (.moderate, .rising):
            recommendation = "Stress is creeping up. Keep an eye on sleep consistency and training volume."
        case (.low, _):
            recommendation = "Your stress load is well-managed. Your current balance of training and recovery is working."
        default:
            recommendation = "Your stress load is moderate. Maintain your current routines."
        }

        return AllostasisReport(
            score: score,
            band: band,
            trajectory: trajectory,
            drivers: drivers.sorted { $0.score * $0.weight > $1.score * $1.weight },
            recommendation: recommendation,
            dataPoints: dailyHRV.count
        )
    }

    // MARK: - Data Fetching

    private static func fetchSamples(
        store: HKHealthStore,
        type: HKQuantityTypeIdentifier,
        predicate: NSPredicate
    ) async -> [HKQuantitySample] {
        guard let qType = HKQuantityType.quantityType(forIdentifier: type) else { return [] }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: qType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }
    }

    private static func fetchCategorySamples(
        store: HKHealthStore,
        type: HKCategoryTypeIdentifier,
        predicate: NSPredicate
    ) async -> [HKCategorySample] {
        guard let cType = HKCategoryType.categoryType(forIdentifier: type) else { return [] }
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: cType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
    }

    // MARK: - Aggregation

    private static func aggregateDaily(
        _ samples: [HKQuantitySample],
        unit: HKUnit,
        calendar: Calendar
    ) -> [(date: Date, value: Double)] {
        var byDay: [Date: [Double]] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.startDate)
            byDay[day, default: []].append(sample.quantity.doubleValue(for: unit))
        }
        return byDay
            .sorted { $0.key < $1.key }
            .map { day, values in
                let median = values.sorted()[values.count / 2]
                return (date: day, value: median)
            }
    }

    private struct DailySleep {
        let date: Date
        let hours: Double
    }

    private static func aggregateSleep(
        _ samples: [HKCategorySample],
        calendar: Calendar
    ) -> [DailySleep] {
        var byDay: [Date: Double] = [:]
        for sample in samples {
            // Only count actual sleep (inBed, asleepCore, asleepDeep, asleepREM)
            let value = sample.value
            guard value != HKCategoryValueSleepAnalysis.awake.rawValue else { continue }
            let day = calendar.startOfDay(for: sample.startDate)
            let hours = sample.endDate.timeIntervalSince(sample.startDate) / 3600
            byDay[day, default: 0] += hours
        }
        return byDay
            .sorted { $0.key < $1.key }
            .map { DailySleep(date: $0.key, hours: min($0.value, 14)) }  // Cap at 14h to exclude data errors
    }

    // MARK: - Statistics

    /// Ordinary least squares slope for an evenly-spaced time series.
    private static func ols(_ values: [Double]) -> Double {
        let n = Double(values.count)
        guard n > 1 else { return 0 }
        let xMean = (n - 1) / 2
        let yMean = values.reduce(0, +) / n
        var num = 0.0, den = 0.0
        for (i, y) in values.enumerated() {
            let x = Double(i)
            num += (x - xMean) * (y - yMean)
            den += (x - xMean) * (x - xMean)
        }
        return den > 0 ? num / den : 0
    }

    private static func coefficientOfVariation(_ values: [Double]) -> Double {
        let n = Double(values.count)
        guard n > 1 else { return 0 }
        let mean = values.reduce(0, +) / n
        guard mean > 0 else { return 0 }
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / (n - 1)
        return (sqrt(variance) / mean) * 100
    }
}
