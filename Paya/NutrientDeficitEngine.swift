import Foundation
import SwiftData

// MARK: - Nutrient Deficit Engine
//
// Compares today's (and rolling 7-day average) micronutrient intake from
// logged food against age/sex-specific Recommended Dietary Allowances
// (Institute of Medicine / National Academies of Sciences, Engineering,
// and Medicine. "Dietary Reference Intakes" series, consolidated in DRI
// Tables 2019). Cross-references with the user's active supplement stack
// to flag nutrients they're already supplementing and flag ones they're
// NOT supplementing but running low on from food alone.

enum NutrientDeficitEngine {

    struct NutrientTarget {
        let id: String
        let name: String
        let unit: String
        let rda: Double
        let keyPath: (MealLog) -> Double
    }

    // RDAs for adult males 19-50 (IOM DRI Tables 2019).
    // Adjusted at call-time for sex/age when the profile is available.
    static func targets(age: Int, sex: String) -> [NutrientTarget] {
        let isFemale = sex.lowercased().hasPrefix("f")
        return [
            NutrientTarget(id: "protein", name: "Protein", unit: "g",
                           rda: isFemale ? 46 : 56, keyPath: \.protein),
            NutrientTarget(id: "fat", name: "Fat", unit: "g",
                           rda: isFemale ? 55 : 70, keyPath: \.fatG),
            NutrientTarget(id: "carbs", name: "Carbs", unit: "g",
                           rda: 130, keyPath: \.carbsG),
            NutrientTarget(id: "fiber", name: "Fiber", unit: "g",
                           rda: isFemale ? 25 : 38, keyPath: \.fiberG),
            NutrientTarget(id: "iron", name: "Iron", unit: "mg",
                           rda: isFemale && age < 51 ? 18 : 8, keyPath: \.ironMg),
            NutrientTarget(id: "calcium", name: "Calcium", unit: "mg",
                           rda: age > 70 ? 1200 : 1000, keyPath: \.calciumMg),
            NutrientTarget(id: "magnesium", name: "Magnesium", unit: "mg",
                           rda: isFemale ? 320 : 420, keyPath: \.magnesiumMg),
            NutrientTarget(id: "zinc", name: "Zinc", unit: "mg",
                           rda: isFemale ? 8 : 11, keyPath: \.zincMg),
            NutrientTarget(id: "vitaminD", name: "Vitamin D", unit: "mcg",
                           rda: age > 70 ? 20 : 15, keyPath: \.vitaminDMcg),
            NutrientTarget(id: "potassium", name: "Potassium", unit: "mg",
                           rda: isFemale ? 2600 : 3400, keyPath: \.potassiumMg),
            NutrientTarget(id: "vitaminC", name: "Vitamin C", unit: "mg",
                           rda: isFemale ? 75 : 90, keyPath: \.vitaminCMg),
            NutrientTarget(id: "sodium", name: "Sodium", unit: "mg",
                           rda: 2300, keyPath: \.sodiumMg),
        ]
    }

    struct NutrientStatus: Identifiable {
        var id: String { target.id }
        let target: NutrientTarget
        let todayIntake: Double
        let weekAvgIntake: Double
        let percentRDA: Double
        let weekPercentRDA: Double
        let isSupplemented: Bool
        let supplementName: String?

        var level: Level {
            let pct = weekPercentRDA > 0 ? weekPercentRDA : percentRDA
            switch pct {
            case ..<50: return .critical
            case 50..<80: return .low
            case 80..<120: return .adequate
            case 120..<200: return .high
            default: return .excessive
            }
        }

        enum Level: String {
            case critical = "Very Low"
            case low = "Low"
            case adequate = "Good"
            case high = "High"
            case excessive = "Excessive"

            var color: String {
                switch self {
                case .critical: return "EF4444"
                case .low: return "F97316"
                case .adequate: return "22C55E"
                case .high: return "3B82F6"
                case .excessive: return "DC2626"
                }
            }

            var icon: String {
                switch self {
                case .critical: return "exclamationmark.triangle.fill"
                case .low: return "arrow.down.circle.fill"
                case .adequate: return "checkmark.circle.fill"
                case .high: return "arrow.up.circle.fill"
                case .excessive: return "exclamationmark.circle.fill"
                }
            }
        }
    }

    struct Report {
        let nutrients: [NutrientStatus]
        let deficits: [NutrientStatus]
        let supplementRecommendations: [SupplementRec]
        let supplementStopSuggestions: [SupplementStop]
    }

    struct SupplementRec {
        let nutrientName: String
        let reason: String
    }

    struct SupplementStop {
        let supplementName: String
        let nutrientName: String
        let reason: String
    }

    @MainActor
    static func analyze(context: ModelContext, age: Int, sex: String) -> Report {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let pid = ActiveProfile.id

        let nutDescriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.date >= weekAgo && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        let nutritionLogs = (try? context.fetch(nutDescriptor)) ?? []

        let todaysMeals = nutritionLogs
            .first { calendar.isDate($0.date, inSameDayAs: today) }?
            .meals ?? []

        let weekMeals = nutritionLogs.flatMap(\.meals)
        let daysWithMeals = Set(nutritionLogs.filter { !$0.meals.isEmpty }.map {
            calendar.startOfDay(for: $0.date)
        }).count
        let effectiveDays = max(1, daysWithMeals)

        let activeSupplements = UserSupplementStore.active(context: context)
        let allTargets = targets(age: age, sex: sex)
        var nutrients: [NutrientStatus] = []

        for target in allTargets {
            let todayTotal = todaysMeals.reduce(0.0) { $0 + target.keyPath($1) }
            let weekTotal = weekMeals.reduce(0.0) { $0 + target.keyPath($1) }
            let weekAvg = weekTotal / Double(effectiveDays)

            let pctToday = target.rda > 0 ? (todayTotal / target.rda) * 100 : 0
            let pctWeek = target.rda > 0 ? (weekAvg / target.rda) * 100 : 0

            let matchedSupplement = activeSupplements.first { supp in
                let name = supp.name.lowercased()
                let tgt = target.name.lowercased()
                return name.contains(tgt) || tgt.contains(name)
            }

            nutrients.append(NutrientStatus(
                target: target,
                todayIntake: todayTotal,
                weekAvgIntake: weekAvg,
                percentRDA: pctToday,
                weekPercentRDA: pctWeek,
                isSupplemented: matchedSupplement != nil,
                supplementName: matchedSupplement?.name
            ))
        }

        let deficits = nutrients.filter { $0.level == .critical || $0.level == .low }

        var recommendations: [SupplementRec] = []
        var stopSuggestions: [SupplementStop] = []

        for deficit in deficits where !deficit.isSupplemented {
            // Sodium is special — low sodium from food is usually fine/healthy
            if deficit.target.id == "sodium" { continue }
            recommendations.append(SupplementRec(
                nutrientName: deficit.target.name,
                reason: "Your 7-day average \(deficit.target.name.lowercased()) intake is \(Int(deficit.weekPercentRDA))% of RDA from food alone. Consider a \(deficit.target.name.lowercased()) supplement."
            ))
        }

        for nutrient in nutrients where nutrient.isSupplemented {
            if nutrient.level == .high || nutrient.level == .excessive {
                stopSuggestions.append(SupplementStop(
                    supplementName: nutrient.supplementName ?? nutrient.target.name,
                    nutrientName: nutrient.target.name,
                    reason: "You're already getting \(Int(nutrient.weekPercentRDA))% of RDA from food. The \(nutrient.supplementName ?? nutrient.target.name) supplement may be pushing you beyond what's beneficial."
                ))
            }
        }

        return Report(
            nutrients: nutrients,
            deficits: deficits,
            supplementRecommendations: recommendations,
            supplementStopSuggestions: stopSuggestions
        )
    }
}
