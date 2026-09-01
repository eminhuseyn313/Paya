import Foundation
import HealthKit
import SwiftData

// MARK: - Glucose Engine (CGM Integration via HealthKit)
//
// Reads interstitial glucose samples written to Apple Health by OTC
// continuous glucose monitors — Dexcom Stelo, Abbott Lingo/Libre, or
// any device that writes HKQuantityType(.bloodGlucose). No direct
// device pairing needed; the CGM app does the pairing and HealthKit
// acts as the shared data bus.
//
// Key capabilities:
//   1. Post-meal glucose curves — correlate meals (from NutritionLog)
//      with the glucose response that follows, measuring peak, time-to-
//      peak, and area-under-curve (AUC) in the 2h post-prandial window.
//   2. Food-specific glucose ranking — compare the same user's response
//      to different foods/meals across multiple days.
//   3. Pre-workout glucose × performance — correlate fasting or pre-
//      session glucose with training volume/RPE.
//   4. Daily glucose statistics — mean, variability (CV%), time-in-range.
//
// Research grounding:
//   • Zeevi et al. 2015, Cell: "Personalized nutrition by prediction of
//     glycemic responses" — identical foods produce vastly different
//     glucose curves across individuals; personal data > population data.
//   • Monnier et al. 2003, JAMA: Glucose variability (CV%) is an
//     independent predictor of oxidative stress beyond mean glucose;
//     CV <36% is the clinical stability threshold (Danne et al. 2017,
//     International Consensus on Time in Range).
//   • Battelino et al. 2019, Diabetes Care (International Consensus):
//     Time-in-range 70-180 mg/dL target ≥70% for non-diabetic adults;
//     time-below-range <54 mg/dL should be <1%.
//   • Cockcroft et al. 2020, J Sports Sci: Pre-exercise glucose
//     60-120 mg/dL is associated with optimal endurance performance;
//     values >160 mg/dL correlate with impaired fat oxidation.

enum GlucoseEngine {

    // MARK: - Types

    struct GlucoseSample: Identifiable {
        let id = UUID()
        let value: Double          // mg/dL
        let date: Date
        let source: String         // bundle ID of the CGM app
    }

    struct PostMealCurve: Identifiable {
        let id = UUID()
        let mealName: String       // e.g. "Lunch"
        let foodDescription: String // e.g. "3 eggs + 80g oats"
        let mealTime: Date
        let preMealGlucose: Double?   // mg/dL, closest reading ≤15 min before
        let peakGlucose: Double       // highest in 2h window
        let peakTimeMinutes: Int      // minutes after meal to peak
        let auc: Double               // area-under-curve (mg/dL × min) above baseline
        let deltaFromBaseline: Double // peak - preMealGlucose
        let samples: [GlucoseSample] // raw curve for charting
        let carbsG: Double
        let caloriesTotal: Double
    }

    struct DayStats: Identifiable {
        let id = UUID()
        let date: Date
        let mean: Double              // mg/dL
        let stdDev: Double
        let coefficientOfVariation: Double  // CV% = (stdDev/mean)*100
        let timeInRange: Double       // % of readings in 70-180 mg/dL
        let timeBelowRange: Double    // % below 54 mg/dL
        let timeAboveRange: Double    // % above 180 mg/dL
        let minGlucose: Double
        let maxGlucose: Double
        let sampleCount: Int
    }

    struct FoodGlucoseRanking: Identifiable {
        let id = UUID()
        let food: String
        let avgPeak: Double           // average peak glucose
        let avgDelta: Double          // average spike magnitude
        let avgTimeToPeak: Int        // minutes
        let occurrences: Int
        let trend: Trend              // getting better/worse over time

        enum Trend: String {
            case improving = "↓ Improving"
            case worsening = "↑ Worsening"
            case stable = "→ Stable"
        }
    }

    struct PreWorkoutCorrelation: Identifiable {
        let id = UUID()
        let sessionDate: Date
        let preWorkoutGlucose: Double // mg/dL, 30 min before session
        let sessionVolume: Double     // kg total volume
        let sessionRPE: Int?
        let glucoseZone: GlucoseZone

        enum GlucoseZone: String {
            case low = "Low (<70)"
            case optimal = "Optimal (70-120)"
            case elevated = "Elevated (120-160)"
            case high = "High (>160)"

            init(glucose: Double) {
                switch glucose {
                case ..<70:  self = .low
                case ..<120: self = .optimal
                case ..<160: self = .elevated
                default:     self = .high
                }
            }
        }
    }

    struct GlucoseOverview {
        let hasData: Bool
        let samples: [GlucoseSample]
        let dayStats: [DayStats]
        let postMealCurves: [PostMealCurve]
        let foodRankings: [FoodGlucoseRanking]
        let workoutCorrelations: [PreWorkoutCorrelation]
        let todaySummary: DayStats?
        let insights: [Insight]
    }

    struct Insight: Identifiable {
        let id = UUID()
        let category: Category
        let headline: String
        let detail: String
        let metric: String
        let metricTone: MetricTone

        enum Category: String, CaseIterable {
            case variability = "Glucose Variability"
            case mealResponse = "Meal Response"
            case workout = "Pre-Workout Glucose"
            case timeInRange = "Time in Range"
        }

        enum MetricTone {
            case positive, negative, neutral
        }
    }

    // MARK: - HealthKit Fetch

    private static let healthStore = HKHealthStore()

    /// Request read authorization for blood glucose.
    static func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        guard let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return false }

        return await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: [glucoseType]) { ok, _ in
                continuation.resume(returning: ok)
            }
        }
    }

    /// Fetch raw glucose samples from HealthKit for the given window.
    static func fetchGlucoseSamples(from startDate: Date, to endDate: Date = .now) async -> [GlucoseSample] {
        guard let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: glucoseType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, _ in
                guard let samples = results as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                // mg/dL — HealthKit stores glucose in mg/dL by convention
                // (Dexcom, Libre, and Apple Health all use this unit for US locale;
                // mmol/L users: Apple Health normalizes via the unit parameter)
                let unit = HKUnit(from: "mg/dL")
                let mapped = samples.map { sample in
                    GlucoseSample(
                        value: sample.quantity.doubleValue(for: unit),
                        date: sample.endDate,
                        source: sample.sourceRevision.source.bundleIdentifier
                    )
                }
                continuation.resume(returning: mapped)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Compute Overview

    /// Main entry point — builds the full glucose overview from HealthKit +
    /// local SwiftData (meals + sessions).
    static func compute(context: ModelContext, daysBack: Int = 30) async -> GlucoseOverview {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -daysBack, to: .now) ?? .now

        // 1. Fetch glucose from HealthKit
        let authorized = await requestAuthorization()
        guard authorized else {
            return GlucoseOverview(hasData: false, samples: [], dayStats: [], postMealCurves: [], foodRankings: [], workoutCorrelations: [], todaySummary: nil, insights: [])
        }

        let samples = await fetchGlucoseSamples(from: startDate)
        guard !samples.isEmpty else {
            return GlucoseOverview(hasData: false, samples: [], dayStats: [], postMealCurves: [], foodRankings: [], workoutCorrelations: [], todaySummary: nil, insights: [])
        }

        // 2. Compute daily stats
        let dayStats = computeDayStats(samples: samples)

        // 3. Fetch meals and compute post-meal curves
        let meals = fetchMeals(context: context, from: startDate)
        let curves = computePostMealCurves(meals: meals, glucoseSamples: samples)

        // 4. Rank foods by glucose response
        let rankings = computeFoodRankings(curves: curves)

        // 5. Fetch sessions and correlate pre-workout glucose
        let sessions = fetchSessions(context: context, from: startDate)
        let workoutCorrelations = computeWorkoutCorrelations(sessions: sessions, glucoseSamples: samples)

        // 6. Today's summary
        let todayStart = calendar.startOfDay(for: .now)
        let todaySummary = dayStats.first { calendar.isDate($0.date, inSameDayAs: todayStart) }

        // 7. Generate insights
        let insights = generateInsights(dayStats: dayStats, curves: curves, rankings: rankings, workoutCorrelations: workoutCorrelations)

        return GlucoseOverview(
            hasData: true,
            samples: samples,
            dayStats: dayStats,
            postMealCurves: curves,
            foodRankings: rankings,
            workoutCorrelations: workoutCorrelations,
            todaySummary: todaySummary,
            insights: insights
        )
    }

    // MARK: - Daily Stats

    private static func computeDayStats(samples: [GlucoseSample]) -> [DayStats] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.date) }

        return grouped.compactMap { date, daySamples in
            guard daySamples.count >= 3 else { return nil }  // need minimum readings
            let values = daySamples.map(\.value)
            let mean = values.reduce(0, +) / Double(values.count)
            let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
            let stdDev = sqrt(variance)
            let cv = mean > 0 ? (stdDev / mean) * 100 : 0

            // Time-in-range (Battelino 2019: 70-180 mg/dL)
            let inRange = Double(values.filter { $0 >= 70 && $0 <= 180 }.count) / Double(values.count) * 100
            let belowRange = Double(values.filter { $0 < 54 }.count) / Double(values.count) * 100
            let aboveRange = Double(values.filter { $0 > 180 }.count) / Double(values.count) * 100

            return DayStats(
                date: date,
                mean: mean,
                stdDev: stdDev,
                coefficientOfVariation: cv,
                timeInRange: inRange,
                timeBelowRange: belowRange,
                timeAboveRange: aboveRange,
                minGlucose: values.min() ?? 0,
                maxGlucose: values.max() ?? 0,
                sampleCount: values.count
            )
        }.sorted { $0.date > $1.date }
    }

    // MARK: - Post-Meal Curves

    private static func fetchMeals(context: ModelContext, from startDate: Date) -> [MealLog] {
        let descriptor = FetchDescriptor<MealLog>(
            predicate: #Predicate<MealLog> { $0.loggedAt >= startDate },
            sortBy: [SortDescriptor(\.loggedAt, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func computePostMealCurves(meals: [MealLog], glucoseSamples: [GlucoseSample]) -> [PostMealCurve] {
        guard !glucoseSamples.isEmpty else { return [] }

        return meals.compactMap { meal in
            let mealTime = meal.loggedAt

            // Pre-meal glucose: closest reading within 15 min before the meal
            let preMealWindow = mealTime.addingTimeInterval(-15 * 60)
            let preMealSamples = glucoseSamples.filter { $0.date >= preMealWindow && $0.date <= mealTime }
            let preMealGlucose = preMealSamples.last?.value

            // Post-meal window: 0-120 min after meal (standard post-prandial window)
            let postStart = mealTime
            let postEnd = mealTime.addingTimeInterval(120 * 60)
            let postSamples = glucoseSamples.filter { $0.date > postStart && $0.date <= postEnd }

            guard postSamples.count >= 2 else { return nil }

            let peak = postSamples.max(by: { $0.value < $1.value })!
            let peakMinutes = Int(peak.date.timeIntervalSince(mealTime) / 60)
            let baseline = preMealGlucose ?? postSamples.first!.value
            let delta = peak.value - baseline

            // AUC above baseline (trapezoidal rule)
            var auc: Double = 0
            for i in 1..<postSamples.count {
                let dt = postSamples[i].date.timeIntervalSince(postSamples[i-1].date) / 60  // minutes
                let avgAboveBaseline = max(0, ((postSamples[i].value - baseline) + (postSamples[i-1].value - baseline)) / 2)
                auc += avgAboveBaseline * dt
            }

            return PostMealCurve(
                mealName: meal.name,
                foodDescription: meal.food,
                mealTime: mealTime,
                preMealGlucose: preMealGlucose,
                peakGlucose: peak.value,
                peakTimeMinutes: peakMinutes,
                auc: auc,
                deltaFromBaseline: delta,
                samples: Array(postSamples),
                carbsG: meal.carbsG,
                caloriesTotal: meal.calories
            )
        }
    }

    // MARK: - Food Rankings

    private static func computeFoodRankings(curves: [PostMealCurve]) -> [FoodGlucoseRanking] {
        // Group by normalized food description
        let grouped = Dictionary(grouping: curves) { normalizeFood($0.foodDescription) }

        return grouped.compactMap { food, curves in
            guard curves.count >= 2 else { return nil }  // need at least 2 data points
            let avgPeak = curves.map(\.peakGlucose).reduce(0, +) / Double(curves.count)
            let avgDelta = curves.map(\.deltaFromBaseline).reduce(0, +) / Double(curves.count)
            let avgTimeToPeak = Int(curves.map { Double($0.peakTimeMinutes) }.reduce(0, +) / Double(curves.count))

            // Trend: compare first half vs second half chronologically
            let sorted = curves.sorted { $0.mealTime < $1.mealTime }
            let mid = sorted.count / 2
            let firstHalf = sorted.prefix(mid).map(\.deltaFromBaseline).reduce(0, +) / Double(max(1, mid))
            let secondHalf = sorted.suffix(from: mid).map(\.deltaFromBaseline).reduce(0, +) / Double(max(1, sorted.count - mid))
            let trend: FoodGlucoseRanking.Trend = {
                let diff = secondHalf - firstHalf
                if diff < -5 { return .improving }
                if diff > 5 { return .worsening }
                return .stable
            }()

            return FoodGlucoseRanking(
                food: food,
                avgPeak: avgPeak,
                avgDelta: avgDelta,
                avgTimeToPeak: avgTimeToPeak,
                occurrences: curves.count,
                trend: trend
            )
        }.sorted { $0.avgDelta > $1.avgDelta }
    }

    private static func normalizeFood(_ food: String) -> String {
        // Simple normalization: lowercase, trim, collapse whitespace
        food.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Pre-Workout Correlations

    private static func fetchSessions(context: ModelContext, from startDate: Date) -> [TrainingSession] {
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.date >= startDate && $0.isCompleted },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func computeWorkoutCorrelations(sessions: [TrainingSession], glucoseSamples: [GlucoseSample]) -> [PreWorkoutCorrelation] {
        guard !glucoseSamples.isEmpty else { return [] }

        return sessions.compactMap { session in
            // Find glucose reading 0-30 min before session
            let windowStart = session.date.addingTimeInterval(-30 * 60)
            let preSamples = glucoseSamples.filter { $0.date >= windowStart && $0.date <= session.date }
            guard let preGlucose = preSamples.last else { return nil }

            // Total volume
            let volume = session.exercises.reduce(0.0) { total, ex in
                total + ex.sets.filter(\.isCompleted).reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
            }

            return PreWorkoutCorrelation(
                sessionDate: session.date,
                preWorkoutGlucose: preGlucose.value,
                sessionVolume: volume,
                sessionRPE: session.subjectiveRPE,
                glucoseZone: .init(glucose: preGlucose.value)
            )
        }
    }

    // MARK: - Insights

    private static func generateInsights(
        dayStats: [DayStats],
        curves: [PostMealCurve],
        rankings: [FoodGlucoseRanking],
        workoutCorrelations: [PreWorkoutCorrelation]
    ) -> [Insight] {
        var insights: [Insight] = []

        // 1. Glucose variability insight
        // Danne et al. 2017: CV% <36% is the stability threshold
        if let recent7 = dayStats.prefix(7).nilIfEmpty {
            let avgCV = recent7.map(\.coefficientOfVariation).reduce(0, +) / Double(recent7.count)
            if avgCV < 36 {
                insights.append(Insight(
                    category: .variability,
                    headline: "Your glucose is stable",
                    detail: "Your 7-day glucose coefficient of variation is \(String(format: "%.0f", avgCV))% — below the 36% clinical stability threshold (Danne et al. 2017, International Consensus on TIR).",
                    metric: "CV \(String(format: "%.0f", avgCV))%",
                    metricTone: .positive
                ))
            } else {
                insights.append(Insight(
                    category: .variability,
                    headline: "Higher glucose variability detected",
                    detail: "Your 7-day CV is \(String(format: "%.0f", avgCV))% — above the 36% stability threshold. High variability is linked to oxidative stress (Monnier et al. 2003, JAMA). Consider pairing carbs with protein/fat.",
                    metric: "CV \(String(format: "%.0f", avgCV))%",
                    metricTone: .negative
                ))
            }
        }

        // 2. Time-in-range insight
        // Battelino 2019: ≥70% TIR for non-diabetic
        if let recent7 = dayStats.prefix(7).nilIfEmpty {
            let avgTIR = recent7.map(\.timeInRange).reduce(0, +) / Double(recent7.count)
            insights.append(Insight(
                category: .timeInRange,
                headline: avgTIR >= 70 ? "Excellent time in range" : "Time in range could improve",
                detail: "\(String(format: "%.0f", avgTIR))% of your readings are in the 70-180 mg/dL range (target ≥70%, Battelino et al. 2019, Diabetes Care International Consensus).",
                metric: "\(String(format: "%.0f", avgTIR))% TIR",
                metricTone: avgTIR >= 70 ? .positive : .negative
            ))
        }

        // 3. Worst food spike
        if let worst = rankings.first, worst.avgDelta > 30 {
            insights.append(Insight(
                category: .mealResponse,
                headline: "Biggest glucose spike",
                detail: "\"\(worst.food)\" causes your highest average glucose spike (+\(String(format: "%.0f", worst.avgDelta)) mg/dL, \(worst.occurrences) meals). Zeevi et al. 2015 (Cell) showed individual glycemic responses vary dramatically — this is YOUR response.",
                metric: "+\(String(format: "%.0f", worst.avgDelta)) mg/dL",
                metricTone: .negative
            ))
        }

        // 4. Best food (lowest spike)
        if rankings.count >= 3, let best = rankings.last, best.avgDelta < 30 {
            insights.append(Insight(
                category: .mealResponse,
                headline: "Gentlest on your glucose",
                detail: "\"\(best.food)\" produces your smallest glucose response (+\(String(format: "%.0f", best.avgDelta)) mg/dL average). Consider this as a go-to for stable energy.",
                metric: "+\(String(format: "%.0f", best.avgDelta)) mg/dL",
                metricTone: .positive
            ))
        }

        // 5. Pre-workout glucose × performance
        // Cockcroft 2020: 60-120 mg/dL optimal for performance
        if workoutCorrelations.count >= 3 {
            let optimal = workoutCorrelations.filter { $0.glucoseZone == .optimal }
            let nonOptimal = workoutCorrelations.filter { $0.glucoseZone != .optimal && $0.glucoseZone != .low }
            if optimal.count >= 2 && nonOptimal.count >= 2 {
                let optAvgVol = optimal.map(\.sessionVolume).reduce(0, +) / Double(optimal.count)
                let nonOptAvgVol = nonOptimal.map(\.sessionVolume).reduce(0, +) / Double(nonOptimal.count)
                let diff = ((optAvgVol - nonOptAvgVol) / max(1, nonOptAvgVol)) * 100
                if abs(diff) > 5 {
                    insights.append(Insight(
                        category: .workout,
                        headline: diff > 0 ? "Optimal glucose → better sessions" : "Glucose zone didn't impact volume",
                        detail: "Sessions with pre-workout glucose 70-120 mg/dL averaged \(String(format: "%.0f", optAvgVol)) kg volume vs \(String(format: "%.0f", nonOptAvgVol)) kg otherwise. Cockcroft et al. 2020 (J Sports Sci): 60-120 mg/dL supports optimal fat oxidation.",
                        metric: "\(diff > 0 ? "+" : "")\(String(format: "%.0f", diff))% volume",
                        metricTone: diff > 0 ? .positive : .neutral
                    ))
                }
            }
        }

        return insights
    }
}

// MARK: - Utility

private extension ArraySlice {
    var nilIfEmpty: Self? { isEmpty ? nil : self }
}
