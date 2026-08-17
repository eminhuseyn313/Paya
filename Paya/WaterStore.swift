import Foundation
import SwiftData

// MARK: - Water Store
// Reads/writes today's water intake on the profile's HealthLog.

enum WaterStore {

    static var dailyTargetMl: Int {
        get { LifestyleReminderSettings.hydrationTargetMl }
        set { LifestyleReminderSettings.hydrationTargetMl = newValue }
    }

    @MainActor
    static func todayTotal(context: ModelContext) -> Int {
        todaysLog(context: context, createIfMissing: false)?.waterMl ?? 0
    }

    @MainActor
    @discardableResult
    static func addWater(_ ml: Int, drinkType: DrinkType = .water, context: ModelContext) -> Int {
        guard let log = todaysLog(context: context, createIfMissing: true) else { return 0 }
        log.waterMl = max(0, log.waterMl + ml)

        let event = WaterEventLog(ml: ml, drinkType: drinkType)
        event.profileId = ActiveProfile.id
        context.insert(event)

        if drinkType != .water && drinkType != .sparklingWater {
            syncDrinkToNutrition(ml: ml, drinkType: drinkType, context: context)
        }

        try? context.save()
        return log.waterMl
    }

    @MainActor
    private static func syncDrinkToNutrition(ml: Int, drinkType: DrinkType, context: ModelContext) {
        let scale = Double(ml) / 250.0
        let cal = drinkType.caloriesPer250ml * scale
        let protein = drinkType.proteinGPer250ml * scale
        guard cal > 0 || protein > 0 else { return }

        let pid = ActiveProfile.id
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == pid && $0.date >= startOfDay },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let nutritionLog: NutritionLog
        if let existing = (try? context.fetch(descriptor))?.first {
            nutritionLog = existing
        } else {
            // Create today's NutritionLog if one doesn't exist yet —
            // otherwise drinks logged before the Nutrition tab is opened
            // silently lose their nutritional data.
            let isTraining = ProgramData.todaySessionType != nil
            let newLog = NutritionLog(date: .now, isTrainingDay: isTraining, proteinTarget: 170, calorieTarget: isTraining ? 2200 : 1900)
            newLog.profileId = pid
            context.insert(newLog)
            nutritionLog = newLog
        }

        let meal = MealLog(
            name: "Drink",
            food: drinkType.displayName,
            protein: protein,
            calories: cal,
            fatG: 0,
            carbsG: drinkType.sugarGPer250ml * scale,
            fiberG: 0,
            sugarG: drinkType.sugarGPer250ml * scale,
            sodiumMg: 0,
            ironMg: 0,
            calciumMg: drinkType.calciumMgPer250ml * scale,
            magnesiumMg: drinkType.magnesiumMgPer250ml * scale,
            zincMg: 0,
            vitaminDMcg: 0,
            potassiumMg: drinkType.potassiumMgPer250ml * scale,
            vitaminCMg: 0
        )
        context.insert(meal)
        meal.nutritionLog = nutritionLog
        nutritionLog.meals.append(meal)
        nutritionLog.recalculateTotals()
    }

    /// Rough today's caffeine estimate from logged drink types — an
    /// awareness note (not a precise measurement, since it uses per-type
    /// averages), surfaced because plain volume totals never distinguished
    /// water from coffee/tea at all.
    @MainActor
    static func todayCaffeineMg(context: ModelContext) -> Double {
        let pid = ActiveProfile.id
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<WaterEventLog>(
            predicate: #Predicate<WaterEventLog> { $0.date >= startOfDay && $0.profileId == pid }
        )
        let events = (try? context.fetch(descriptor)) ?? []
        return events.reduce(0.0) { total, event in
            total + (Double(event.ml) / 250.0) * event.drinkType.caffeineMgPer250ml
        }
    }

    @MainActor
    static func todayDrinkCalories(context: ModelContext) -> Double {
        todayDrinkEvents(context: context).reduce(0.0) { total, event in
            total + (Double(event.ml) / 250.0) * event.drinkType.caloriesPer250ml
        }
    }

    @MainActor
    static func todayDrinkSugar(context: ModelContext) -> Double {
        todayDrinkEvents(context: context).reduce(0.0) { total, event in
            total + (Double(event.ml) / 250.0) * event.drinkType.sugarGPer250ml
        }
    }

    @MainActor
    private static func todayDrinkEvents(context: ModelContext) -> [WaterEventLog] {
        let pid = ActiveProfile.id
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<WaterEventLog>(
            predicate: #Predicate<WaterEventLog> { $0.date >= startOfDay && $0.profileId == pid }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Returns the most frequently logged ml amounts for a drink type over
    /// the last 14 days. Falls back to sensible defaults if no history exists.
    /// This drives the quick-add buttons so they adapt to the user's actual
    /// drinking habits instead of showing static [100, 250, 500].
    @MainActor
    static func frequentAmounts(for drinkType: DrinkType, context: ModelContext, count: Int = 3) -> [Int] {
        let defaults: [Int] = drinkType == .espresso ? [30, 60, 90] : [100, 250, 500]

        let pid = ActiveProfile.id
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let typeRaw = drinkType.rawValue
        let descriptor = FetchDescriptor<WaterEventLog>(
            predicate: #Predicate<WaterEventLog> {
                $0.profileId == pid && $0.date >= twoWeeksAgo && $0.drinkTypeRaw == typeRaw
            }
        )
        let events = (try? context.fetch(descriptor)) ?? []
        guard events.count >= 3 else { return defaults }

        // Count frequency of each ml amount
        var freq: [Int: Int] = [:]
        for e in events { freq[e.ml, default: 0] += 1 }

        // Sort by frequency (descending), then by amount (ascending) for ties
        let sorted = freq.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key < rhs.key
        }

        let top = Array(sorted.prefix(count).map { $0.key })
        guard top.count >= 2 else { return defaults }
        return top.sorted()   // present in ascending ml order
    }

    @MainActor
    private static func todaysLog(context: ModelContext, createIfMissing: Bool) -> HealthLog? {
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        let descriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate { $0.profileId == pid && $0.date >= startOfDay },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        guard createIfMissing else { return nil }
        let log = HealthLog()
        log.profileId = pid
        context.insert(log)
        try? context.save()
        return log
    }
}
