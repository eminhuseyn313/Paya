import Foundation
import SwiftData

// MARK: - Digestive Pattern Engine
//
// Maps food intake → digestive outcomes with lag analysis.
// Discovers which foods or food categories predict poor digestion
// (Bristol 1-2 or 6-7) and GI symptoms for THIS specific user.
//
// The core idea: most food-gut research operates at population level
// ("fiber is good for everyone"), but individual GI responses vary
// dramatically. This engine learns YOUR patterns:
//   • "High-sugar meals are followed by Bristol 6-7 within 18h for you"
//   • "Days with >30g fiber → Bristol 3-4 (ideal) next day"
//   • "Dairy-heavy meals correlate with bloating reports"
//
// Research grounding:
//   • Koloski et al. 2019, Am J Gastroenterol: "Perceived food
//     intolerance affects 20% of the population; individual
//     elimination-rechallenge is the gold standard for identifying
//     personal triggers."
//   • Böhn et al. 2013, Gut: meal-to-symptom lag for IBS averages
//     4-12h but varies 2-48h between individuals. Fixed population
//     lag windows miss most individual patterns.
//   • Staudacher et al. 2017, Gastroenterology: FODMAPs trigger
//     symptoms in 50-80% of IBS patients but are harmless for
//     others — proving per-person analysis is essential.
//   • Lewis & Heaton 1997, Scand J Gastroenterol: Bristol Stool
//     Scale is a validated, reliable proxy for colonic transit time.

enum DigestivePatternEngine {

    // MARK: - Types

    struct Report {
        let patterns: [Pattern]
        let digestiveScore: Int    // 0-100, higher = healthier
        let idealDays: Int         // Bristol 3-4 days
        let totalTrackedDays: Int
        let topTriggers: [Trigger]
    }

    struct Pattern: Identifiable {
        let id = UUID()
        let category: Category
        let headline: String
        let detail: String
        let metric: String
        let tone: Tone
        let sampleDays: Int

        enum Category: String {
            case fiber      = "Fiber impact"
            case sugar      = "Sugar response"
            case fat        = "Fat tolerance"
            case mealSize   = "Meal size"
            case hydration  = "Hydration link"
            case timing     = "Meal timing"
            case symptom    = "Symptom trigger"
        }

        enum Tone {
            case positive, negative, neutral
        }
    }

    struct Trigger: Identifiable {
        let id = UUID()
        let label: String         // e.g. "High sugar (>50g)"
        let icon: String
        let occurrences: Int
        let badOutcomeRate: Double // 0-1
    }

    /// A day's combined food + bathroom + symptom profile.
    private struct DayDigestive {
        let date: Date
        let totalCalories: Double
        let protein: Double
        let fat: Double
        let carbs: Double
        let fiber: Double
        let sugar: Double

        // Next-day bathroom outcomes
        let nextDayBristol: [Int]         // all Bristol scores logged next day
        let nextDayPoopCount: Int
        // Same-day or next-day GI symptoms
        let giSymptoms: [String]          // symptom tags within 24h
    }

    // MARK: - Compute

    @MainActor
    static func compute(context: ModelContext) async -> Report? {
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -60, to: now) else { return nil }

        // Fetch nutrition logs
        let nutDescriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.date >= startDate },
            sortBy: [SortDescriptor(\NutritionLog.date)]
        )
        guard let nutritionLogs = try? context.fetch(nutDescriptor), !nutritionLogs.isEmpty else { return nil }

        // Fetch bathroom logs
        let bathDescriptor = FetchDescriptor<BathroomLog>(
            predicate: #Predicate<BathroomLog> { $0.date >= startDate },
            sortBy: [SortDescriptor(\BathroomLog.date)]
        )
        let bathroomLogs = (try? context.fetch(bathDescriptor)) ?? []

        // Fetch symptom logs (filter to GI-related)
        let symDescriptor = FetchDescriptor<SymptomLog>(
            predicate: #Predicate<SymptomLog> { $0.date >= startDate },
            sortBy: [SortDescriptor(\SymptomLog.date)]
        )
        let symptomLogs = (try? context.fetch(symDescriptor)) ?? []

        // Need at least 7 days with both food and bathroom data
        let poopLogs = bathroomLogs.filter { $0.type == "poop" }
        guard poopLogs.count >= 5 else { return nil }

        // Index bathroom logs by date
        var bristolByDate: [String: [Int]] = [:]
        var poopCountByDate: [String: Int] = [:]
        for log in poopLogs {
            let key = calendar.startOfDay(for: log.date).formatted(.iso8601.year().month().day())
            bristolByDate[key, default: []].append(log.bristolScale ?? 4)
            poopCountByDate[key, default: 0] += 1
        }

        // Index GI symptoms by date
        let giTags: Set<String> = ["bloating", "gas", "nausea", "cramps", "diarrhea",
                                    "constipation", "acid reflux", "stomach pain",
                                    "indigestion", "abdominal pain", "heartburn"]
        var symptomsByDate: [String: [String]] = [:]
        for log in symptomLogs {
            if giTags.contains(log.tag.lowercased()) {
                let key = calendar.startOfDay(for: log.date).formatted(.iso8601.year().month().day())
                symptomsByDate[key, default: []].append(log.tag)
            }
        }

        // Build day profiles
        var days: [DayDigestive] = []
        for log in nutritionLogs {
            let dayStart = calendar.startOfDay(for: log.date)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            let nextKey = nextDay.formatted(.iso8601.year().month().day())
            let sameDayKey = dayStart.formatted(.iso8601.year().month().day())

            // Combine same-day and next-day symptoms (within 24h window)
            var combinedSymptoms = symptomsByDate[sameDayKey] ?? []
            combinedSymptoms.append(contentsOf: symptomsByDate[nextKey] ?? [])

            days.append(DayDigestive(
                date: log.date,
                totalCalories: log.totalCalories,
                protein: log.totalProtein,
                fat: log.totalFat,
                carbs: log.totalCarbs,
                fiber: log.totalFiber,
                sugar: log.totalSugar,
                nextDayBristol: bristolByDate[nextKey] ?? [],
                nextDayPoopCount: poopCountByDate[nextKey] ?? 0,
                giSymptoms: combinedSymptoms
            ))
        }

        guard days.count >= 7 else { return nil }

        // Run analyses
        var patterns: [Pattern] = []
        if let p = fiberAnalysis(days) { patterns.append(p) }
        if let p = sugarAnalysis(days) { patterns.append(p) }
        if let p = fatAnalysis(days) { patterns.append(p) }
        if let p = mealSizeAnalysis(days) { patterns.append(p) }
        if let p = symptomTriggerAnalysis(days) { patterns.append(p) }

        // Digestive health score
        let allBristol = days.flatMap(\.nextDayBristol)
        let idealCount = allBristol.filter { $0 == 3 || $0 == 4 }.count
        let totalBristol = allBristol.count
        let score = totalBristol > 0 ? Int(Double(idealCount) / Double(totalBristol) * 100) : 50

        // Top triggers
        let triggers = buildTriggers(days)

        return Report(
            patterns: patterns,
            digestiveScore: score,
            idealDays: idealCount,
            totalTrackedDays: days.count,
            topTriggers: triggers
        )
    }

    // MARK: - Analyses

    private static func fiberAnalysis(_ days: [DayDigestive]) -> Pattern? {
        let withBristol = days.filter { !$0.nextDayBristol.isEmpty }
        let highFiber = withBristol.filter { $0.fiber >= 25 }
        let lowFiber = withBristol.filter { $0.fiber < 15 }

        guard highFiber.count >= 3, lowFiber.count >= 3 else { return nil }

        let highIdealRate = idealRate(highFiber)
        let lowIdealRate = idealRate(lowFiber)
        let diff = highIdealRate - lowIdealRate

        let tone: Pattern.Tone = diff > 10 ? .positive : diff < -10 ? .negative : .neutral

        return Pattern(
            category: .fiber,
            headline: diff > 10
                ? "High-fiber days lead to better digestion for you"
                : diff < -10
                    ? "High fiber seems to upset your digestion"
                    : "Fiber intake doesn't strongly affect your stool quality",
            detail: String(format: "Days with ≥25g fiber: %.0f%% ideal Bristol (3-4). Days with <15g: %.0f%%. Lewis & Heaton 1997: Bristol 3-4 indicates optimal 18-36h transit time.", highIdealRate, lowIdealRate),
            metric: String(format: "%+.0f%%", diff),
            tone: tone,
            sampleDays: highFiber.count + lowFiber.count
        )
    }

    private static func sugarAnalysis(_ days: [DayDigestive]) -> Pattern? {
        let withBristol = days.filter { !$0.nextDayBristol.isEmpty }
        let highSugar = withBristol.filter { $0.sugar > 50 }
        let lowSugar = withBristol.filter { $0.sugar <= 25 }

        guard highSugar.count >= 3, lowSugar.count >= 3 else { return nil }

        // Bad outcome = Bristol 1-2 (constipated) or 6-7 (loose)
        let highBadRate = badOutcomeRate(highSugar)
        let lowBadRate = badOutcomeRate(lowSugar)
        let diff = highBadRate - lowBadRate

        guard abs(diff) > 5 else { return nil }

        return Pattern(
            category: .sugar,
            headline: diff > 10
                ? "High-sugar days predict digestive issues"
                : "Sugar intake doesn't significantly affect your digestion",
            detail: String(format: "Days with >50g sugar: %.0f%% bad outcomes (Bristol 1-2 or 6-7). Days ≤25g: %.0f%%.", highBadRate, lowBadRate),
            metric: String(format: "%+.0f%% bad", diff),
            tone: diff > 10 ? .negative : .neutral,
            sampleDays: highSugar.count + lowSugar.count
        )
    }

    private static func fatAnalysis(_ days: [DayDigestive]) -> Pattern? {
        let withBristol = days.filter { !$0.nextDayBristol.isEmpty }
        let highFat = withBristol.filter { $0.fat > 80 }
        let lowFat = withBristol.filter { $0.fat <= 40 }

        guard highFat.count >= 3, lowFat.count >= 3 else { return nil }

        let highBadRate = badOutcomeRate(highFat)
        let lowBadRate = badOutcomeRate(lowFat)
        let diff = highBadRate - lowBadRate

        guard abs(diff) > 5 else { return nil }

        return Pattern(
            category: .fat,
            headline: diff > 10
                ? "High-fat days upset your digestion"
                : "Fat intake has modest digestive impact",
            detail: String(format: "Days with >80g fat: %.0f%% bad outcomes. Days ≤40g: %.0f%%.", highBadRate, lowBadRate),
            metric: String(format: "%+.0f%% bad", diff),
            tone: diff > 10 ? .negative : .neutral,
            sampleDays: highFat.count + lowFat.count
        )
    }

    private static func mealSizeAnalysis(_ days: [DayDigestive]) -> Pattern? {
        let withBristol = days.filter { !$0.nextDayBristol.isEmpty && $0.totalCalories > 0 }
        let highCal = withBristol.filter { $0.totalCalories > 2500 }
        let normalCal = withBristol.filter { $0.totalCalories >= 1500 && $0.totalCalories <= 2200 }

        guard highCal.count >= 3, normalCal.count >= 3 else { return nil }

        let highIdeal = idealRate(highCal)
        let normalIdeal = idealRate(normalCal)
        let diff = highIdeal - normalIdeal

        guard abs(diff) > 5 else { return nil }

        return Pattern(
            category: .mealSize,
            headline: diff < -10
                ? "Overeating days worsen your digestion"
                : "Total calorie intake doesn't strongly affect stool quality",
            detail: String(format: "Days >2500 kcal: %.0f%% ideal stool. Days 1500-2200 kcal: %.0f%%.", highIdeal, normalIdeal),
            metric: String(format: "%+.0f%%", diff),
            tone: diff < -10 ? .negative : .neutral,
            sampleDays: highCal.count + normalCal.count
        )
    }

    private static func symptomTriggerAnalysis(_ days: [DayDigestive]) -> Pattern? {
        let withSymptoms = days.filter { !$0.giSymptoms.isEmpty }
        let withoutSymptoms = days.filter { $0.giSymptoms.isEmpty }

        guard withSymptoms.count >= 3, withoutSymptoms.count >= 3 else { return nil }

        // Compare macro profiles of symptom days vs clean days
        let sympFat = withSymptoms.map(\.fat).average
        let cleanFat = withoutSymptoms.map(\.fat).average
        let sympSugar = withSymptoms.map(\.sugar).average
        let cleanSugar = withoutSymptoms.map(\.sugar).average
        let sympFiber = withSymptoms.map(\.fiber).average
        let cleanFiber = withoutSymptoms.map(\.fiber).average

        // Find the biggest divergence
        let fatDiff = sympFat - cleanFat
        let sugarDiff = sympSugar - cleanSugar
        let fiberDiff = sympFiber - cleanFiber

        let biggest: (name: String, diff: Double, unit: String)
        if abs(fatDiff) > abs(sugarDiff) && abs(fatDiff) > abs(fiberDiff) {
            biggest = ("fat", fatDiff, "g")
        } else if abs(sugarDiff) > abs(fiberDiff) {
            biggest = ("sugar", sugarDiff, "g")
        } else {
            biggest = ("fiber", fiberDiff, "g")
        }

        guard abs(biggest.diff) > 5 else { return nil }

        return Pattern(
            category: .symptom,
            headline: "GI symptom days have \(biggest.diff > 0 ? "higher" : "lower") \(biggest.name) intake",
            detail: String(format: "Days with GI symptoms avg %.0f%@ %@. Clean days: %.0f%@. Koloski 2019: individual trigger identification through personal pattern analysis is the gold standard.",
                           biggest.diff > 0 ? sympFat : sympSugar, biggest.unit, biggest.name,
                           biggest.diff > 0 ? cleanFat : cleanSugar, biggest.unit),
            metric: String(format: "%+.0f%@ %@", biggest.diff, biggest.unit, biggest.name),
            tone: .negative,
            sampleDays: withSymptoms.count + withoutSymptoms.count
        )
    }

    // MARK: - Triggers

    private static func buildTriggers(_ days: [DayDigestive]) -> [Trigger] {
        var triggers: [Trigger] = []
        let withBristol = days.filter { !$0.nextDayBristol.isEmpty }

        // High sugar trigger
        let highSugar = withBristol.filter { $0.sugar > 50 }
        if highSugar.count >= 3 {
            triggers.append(Trigger(
                label: "High sugar (>50g)",
                icon: "cube.fill",
                occurrences: highSugar.count,
                badOutcomeRate: badOutcomeRate(highSugar) / 100
            ))
        }

        // High fat trigger
        let highFat = withBristol.filter { $0.fat > 80 }
        if highFat.count >= 3 {
            triggers.append(Trigger(
                label: "High fat (>80g)",
                icon: "drop.fill",
                occurrences: highFat.count,
                badOutcomeRate: badOutcomeRate(highFat) / 100
            ))
        }

        // Low fiber trigger
        let lowFiber = withBristol.filter { $0.fiber < 15 }
        if lowFiber.count >= 3 {
            triggers.append(Trigger(
                label: "Low fiber (<15g)",
                icon: "leaf.fill",
                occurrences: lowFiber.count,
                badOutcomeRate: badOutcomeRate(lowFiber) / 100
            ))
        }

        // Overeating trigger
        let overeat = withBristol.filter { $0.totalCalories > 2800 }
        if overeat.count >= 3 {
            triggers.append(Trigger(
                label: "Overeating (>2800 kcal)",
                icon: "fork.knife",
                occurrences: overeat.count,
                badOutcomeRate: badOutcomeRate(overeat) / 100
            ))
        }

        return triggers.sorted { $0.badOutcomeRate > $1.badOutcomeRate }
    }

    // MARK: - Helpers

    private static func idealRate(_ days: [DayDigestive]) -> Double {
        let allBristol = days.flatMap(\.nextDayBristol)
        guard !allBristol.isEmpty else { return 0 }
        let ideal = allBristol.filter { $0 == 3 || $0 == 4 }.count
        return Double(ideal) / Double(allBristol.count) * 100
    }

    private static func badOutcomeRate(_ days: [DayDigestive]) -> Double {
        let allBristol = days.flatMap(\.nextDayBristol)
        guard !allBristol.isEmpty else { return 0 }
        let bad = allBristol.filter { $0 <= 2 || $0 >= 6 }.count
        return Double(bad) / Double(allBristol.count) * 100
    }
}

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
