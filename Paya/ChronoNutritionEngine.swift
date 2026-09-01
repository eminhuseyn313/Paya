import Foundation
import SwiftData

// MARK: - Chrononutrition Engine
//
// Discovers personalized relationships between WHEN you eat and how
// you sleep + recover. Unlike the CircadianEngine (which infers
// chronotype from sleep patterns alone), this engine correlates actual
// meal timestamps with same-night biometrics to surface actionable
// patterns unique to each user.
//
// Key insights this engine can surface:
//   • "Meals after 9 PM correlate with 18% less deep sleep for YOU"
//   • "Your HRV is 12% higher the morning after early dinners"
//   • "Your eating window on good-sleep days averages 10.2h vs. 13.1h on poor nights"
//
// Research grounding:
//   • St-Onge et al. 2016, AJCN: "Fiber and saturated fat intake predict
//     sleep architecture; meal timing modulates sleep onset latency."
//   • Crispim et al. 2011, J Clin Sleep Med: eating within 1-2h of bedtime
//     is associated with longer sleep onset latency and reduced sleep quality,
//     with high-glycemic-index meals showing the strongest effect.
//   • Iao et al. 2021, Nutrients meta-analysis: late-night eating is
//     consistently associated with shorter sleep duration and worse sleep
//     quality across 23 studies (n=225,000+).
//   • Wirth et al. 2020, Adv Nutr: time-restricted eating (≤12h window)
//     improves multiple cardiometabolic biomarkers including HRV.

enum ChronoNutritionEngine {

    // MARK: - Types

    struct Insight: Identifiable {
        let id = UUID()
        let category: Category
        let headline: String
        let detail: String
        let metric: String          // e.g. "−22% deep sleep"
        let metricColor: MetricTone
        let sampleDays: Int
        let confidence: Confidence

        enum Category: String {
            case lastMealTiming   = "Last meal timing"
            case eatingWindow     = "Eating window"
            case deepSleep        = "Deep sleep impact"
            case hrvRecovery      = "HRV recovery"
            case sleepOnset       = "Sleep duration"
        }

        enum MetricTone {
            case positive, negative, neutral
        }

        enum Confidence: String {
            case strong   = "Strong"   // 20+ matched days, clear split
            case moderate = "Moderate" // 10-19 days
            case emerging = "Emerging" // 7-9 days
        }
    }

    /// A single day's chrononutrition profile — last meal time, eating window,
    /// plus same-night biometrics.
    private struct DayProfile {
        let date: Date
        let lastMealHour: Double      // 0-24 (e.g. 21.5 = 9:30 PM)
        let firstMealHour: Double     // earliest meal of the day
        let eatingWindowHours: Double // last - first
        let mealCount: Int
        let totalCalories: Double
        let sleepHours: Double?
        let sleepDeep: Double?        // hours of deep sleep
        let sleepREM: Double?         // hours of REM
        let nextDayHRV: Double?       // next morning's HRV
    }

    // MARK: - Compute

    /// Analyze meal timing × sleep/HRV correlations for the past 60 days.
    /// Requires a modelContext to fetch NutritionLog/MealLog data.
    @MainActor
    static func compute(context: ModelContext) async -> [Insight] {
        // 1. Fetch last 60 days of nutrition logs with meals
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -60, to: now) else { return [] }

        let descriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.date >= startDate },
            sortBy: [SortDescriptor(\NutritionLog.date)]
        )
        guard let logs = try? context.fetch(descriptor), !logs.isEmpty else { return [] }

        // 2. Load biometric history
        let bio = BiometricStore.shared
        if bio.history.isEmpty { await bio.loadHistory(daysBack: 90) }

        // Build date-indexed biometric lookup
        var bioByDate: [String: DailySummary] = [:]
        for day in bio.history {
            let key = calendar.startOfDay(for: day.date).formatted(.iso8601.year().month().day())
            bioByDate[key] = day
        }

        // 3. Build day profiles
        var profiles: [DayProfile] = []
        for log in logs {
            let meals = log.meals
            guard !meals.isEmpty else { continue }

            let mealHours = meals.compactMap { meal -> Double? in
                let comps = calendar.dateComponents([.hour, .minute], from: meal.loggedAt)
                guard let h = comps.hour, let m = comps.minute else { return nil }
                return Double(h) + Double(m) / 60.0
            }
            guard !mealHours.isEmpty else { continue }

            let firstHour = mealHours.min()!
            let lastHour = mealHours.max()!
            let window = lastHour - firstHour

            let dayKey = calendar.startOfDay(for: log.date).formatted(.iso8601.year().month().day())
            let sameNightBio = bioByDate[dayKey]

            // Next-day HRV
            let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: log.date))!
            let nextKey = nextDay.formatted(.iso8601.year().month().day())
            let nextDayBio = bioByDate[nextKey]

            profiles.append(DayProfile(
                date: log.date,
                lastMealHour: lastHour,
                firstMealHour: firstHour,
                eatingWindowHours: max(0, window),
                mealCount: meals.count,
                totalCalories: log.totalCalories,
                sleepHours: sameNightBio?.sleepHours,
                sleepDeep: sameNightBio?.sleepDeep,
                sleepREM: sameNightBio?.sleepREM,
                nextDayHRV: nextDayBio?.hrv
            ))
        }

        guard profiles.count >= 7 else { return [] }

        // 4. Run analyses
        var insights: [Insight] = []

        if let i = lastMealTimingAnalysis(profiles) { insights.append(i) }
        if let i = eatingWindowAnalysis(profiles) { insights.append(i) }
        if let i = deepSleepImpact(profiles) { insights.append(i) }
        if let i = hrvRecoveryAnalysis(profiles) { insights.append(i) }
        if let i = sleepDurationAnalysis(profiles) { insights.append(i) }

        return insights
    }

    // MARK: - Individual Analyses

    /// Compare sleep quality on "early dinner" (< 8 PM) vs "late dinner" (≥ 9 PM) nights.
    private static func lastMealTimingAnalysis(_ profiles: [DayProfile]) -> Insight? {
        let withSleep = profiles.filter { $0.sleepHours != nil }
        let early = withSleep.filter { $0.lastMealHour < 20 }
        let late = withSleep.filter { $0.lastMealHour >= 21 }

        guard early.count >= 3, late.count >= 3 else { return nil }

        let earlySleep = early.compactMap(\.sleepHours).average
        let lateSleep = late.compactMap(\.sleepHours).average

        let diff = lateSleep - earlySleep
        let pctDiff = earlySleep > 0 ? (diff / earlySleep) * 100 : 0
        let totalDays = early.count + late.count

        let tone: Insight.MetricTone = diff < -0.2 ? .negative : diff > 0.2 ? .positive : .neutral
        let metricStr = String(format: "%+.0f min", diff * 60)

        return Insight(
            category: .lastMealTiming,
            headline: abs(pctDiff) > 5
                ? "Late dinners affect your sleep"
                : "Dinner timing has little effect on your sleep",
            detail: String(format: "Nights after eating past 9 PM: avg %.1fh sleep. Early dinners (before 8 PM): avg %.1fh. Based on Crispim et al. 2011 — eating within 2h of bed extends sleep onset latency.", lateSleep, earlySleep),
            metric: metricStr,
            metricColor: tone,
            sampleDays: totalDays,
            confidence: confidence(from: totalDays)
        )
    }

    /// Compare eating windows: restricted (≤10h) vs extended (>13h).
    private static func eatingWindowAnalysis(_ profiles: [DayProfile]) -> Insight? {
        let withSleep = profiles.filter { $0.sleepHours != nil }
        let restricted = withSleep.filter { $0.eatingWindowHours <= 10 }
        let extended = withSleep.filter { $0.eatingWindowHours > 13 }

        guard restricted.count >= 3, extended.count >= 3 else { return nil }

        let restrictedSleep = restricted.compactMap(\.sleepHours).average
        let extendedSleep = extended.compactMap(\.sleepHours).average
        let diff = restrictedSleep - extendedSleep
        let totalDays = restricted.count + extended.count

        let tone: Insight.MetricTone = diff > 0.2 ? .positive : diff < -0.2 ? .negative : .neutral

        return Insight(
            category: .eatingWindow,
            headline: diff > 0.15
                ? "Shorter eating windows improve your sleep"
                : "Eating window length doesn't clearly affect your sleep",
            detail: String(format: "Days with ≤10h eating window: avg %.1fh sleep. Days with >13h window: avg %.1fh. Wirth et al. 2020: time-restricted eating (≤12h) improves cardiometabolic markers including HRV.", restrictedSleep, extendedSleep),
            metric: String(format: "%+.0f min", diff * 60),
            metricColor: tone,
            sampleDays: totalDays,
            confidence: confidence(from: totalDays)
        )
    }

    /// Deep sleep % comparison based on last meal timing.
    private static func deepSleepImpact(_ profiles: [DayProfile]) -> Insight? {
        let withDeep = profiles.filter { $0.sleepDeep != nil && $0.sleepHours != nil && $0.sleepHours! > 0 }
        let early = withDeep.filter { $0.lastMealHour < 20 }
        let late = withDeep.filter { $0.lastMealHour >= 21 }

        guard early.count >= 3, late.count >= 3 else { return nil }

        let earlyDeepPct = early.map { ($0.sleepDeep! / $0.sleepHours!) * 100 }.average
        let lateDeepPct = late.map { ($0.sleepDeep! / $0.sleepHours!) * 100 }.average
        let diff = lateDeepPct - earlyDeepPct
        let totalDays = early.count + late.count

        let tone: Insight.MetricTone = diff < -2 ? .negative : diff > 2 ? .positive : .neutral

        return Insight(
            category: .deepSleep,
            headline: abs(diff) > 3
                ? "Late meals cut into your deep sleep"
                : "Deep sleep isn't strongly affected by meal timing",
            detail: String(format: "Deep sleep share: %.0f%% after early dinners vs. %.0f%% after late meals. St-Onge et al. 2016: meal composition and timing directly predict sleep architecture.", earlyDeepPct, lateDeepPct),
            metric: String(format: "%+.0f%%", diff),
            metricColor: tone,
            sampleDays: totalDays,
            confidence: confidence(from: totalDays)
        )
    }

    /// Next-morning HRV comparison: early vs late last meal.
    private static func hrvRecoveryAnalysis(_ profiles: [DayProfile]) -> Insight? {
        let withHRV = profiles.filter { $0.nextDayHRV != nil }
        let early = withHRV.filter { $0.lastMealHour < 20 }
        let late = withHRV.filter { $0.lastMealHour >= 21 }

        guard early.count >= 3, late.count >= 3 else { return nil }

        let earlyHRV = early.compactMap(\.nextDayHRV).average
        let lateHRV = late.compactMap(\.nextDayHRV).average
        let diff = earlyHRV - lateHRV
        let pctDiff = lateHRV > 0 ? (diff / lateHRV) * 100 : 0
        let totalDays = early.count + late.count

        let tone: Insight.MetricTone = pctDiff > 3 ? .positive : pctDiff < -3 ? .negative : .neutral

        return Insight(
            category: .hrvRecovery,
            headline: abs(pctDiff) > 5
                ? "Early dinners boost your morning HRV"
                : "Meal timing has a modest effect on your HRV",
            detail: String(format: "Next-morning HRV after early dinner: %.0f ms. After late meal: %.0f ms (%+.0f%%). Iao et al. 2021: late eating consistently worsens recovery markers across 23 studies.", earlyHRV, lateHRV, pctDiff),
            metric: String(format: "%+.0f ms", diff),
            metricColor: tone,
            sampleDays: totalDays,
            confidence: confidence(from: totalDays)
        )
    }

    /// Sleep duration correlation with eating window length.
    private static func sleepDurationAnalysis(_ profiles: [DayProfile]) -> Insight? {
        let valid = profiles.filter { $0.sleepHours != nil && $0.eatingWindowHours > 0 }
        guard valid.count >= 7 else { return nil }

        // Pearson R between eating window and sleep hours
        let xs = valid.map(\.eatingWindowHours)
        let ys = valid.compactMap(\.sleepHours)
        guard xs.count == ys.count else { return nil }

        let r = pearsonR(xs, ys)
        let totalDays = valid.count

        guard abs(r) > 0.15 else { return nil }

        let tone: Insight.MetricTone = r < -0.15 ? .negative : r > 0.15 ? .positive : .neutral
        let direction = r < 0 ? "Wider eating windows correlate with shorter sleep" : "Wider eating windows correlate with longer sleep"

        return Insight(
            category: .sleepOnset,
            headline: direction,
            detail: String(format: "Correlation r=%.2f across %d days. %@", r, totalDays, abs(r) > 0.3
                ? "A moderate-to-strong relationship exists for you."
                : "A weak but consistent pattern."),
            metric: String(format: "r=%.2f", r),
            metricColor: tone,
            sampleDays: totalDays,
            confidence: confidence(from: totalDays)
        )
    }

    // MARK: - Helpers

    private static func confidence(from days: Int) -> Insight.Confidence {
        switch days {
        case 20...: return .strong
        case 10..<20: return .moderate
        default: return .emerging
        }
    }

    private static func pearsonR(_ xs: [Double], _ ys: [Double]) -> Double {
        let n = Double(xs.count)
        guard n > 2 else { return 0 }
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        var num = 0.0, denX = 0.0, denY = 0.0
        for i in 0..<xs.count {
            let dx = xs[i] - meanX
            let dy = ys[i] - meanY
            num += dx * dy
            denX += dx * dx
            denY += dy * dy
        }
        let den = sqrt(denX * denY)
        return den > 0 ? num / den : 0
    }
}

// MARK: - Array Average Helper

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
