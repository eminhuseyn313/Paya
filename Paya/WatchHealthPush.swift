import Foundation
import SwiftData

// MARK: - Health context for the watch
// Pushes the pieces of Paya's health picture the wrist can act on:
// flare level + early-warning, the day's briefing headline, today's due
// medications, and a post-workout protein figure. Everything is optional and
// only sent when it genuinely exists — the watch shows "—"/nothing otherwise.

@MainActor
enum WatchHealthPush {

    private static let briefingKey = "paya_watch_briefing"
    private static let briefingDayKey = "paya_watch_briefing_day"

    /// Remember today's briefing headline so the watch can show it all day,
    /// not only at the moment the (once-a-day) briefing is generated.
    static func cacheBriefing(_ headline: String) {
        UserDefaults.standard.set(headline, forKey: briefingKey)
        UserDefaults.standard.set(dayStamp(), forKey: briefingDayKey)
    }

    private static func dayStamp(_ d: Date = .now) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    static func pushFlareAndBriefing(
        assessment: FlareRiskAssessment?,
        forecast: FlareForecastEngine.Forecast?,
        flareEnabled: Bool,
        weightKg: Double?,
        sleepHours: Double? = nil,
        hrvMs: Double? = nil,
        restingHR: Int? = nil
    ) {
        var v: [String: Any] = [:]
        if flareEnabled, let assessment {
            v["flareLevel"] = assessment.level.rawValue
            let worsening = forecast?.trajectory == .worsening
            v["flareWorsening"] = worsening
            v["flareSummary"] = worsening ? (forecast?.summary ?? assessment.recommendation) : assessment.recommendation
            v["flareAlertId"] = worsening ? "flare-\(dayStamp())" : ""
        } else {
            v["flareLevel"] = ""
            v["flareWorsening"] = false
            v["flareAlertId"] = ""
        }
        let defaults = UserDefaults.standard
        if defaults.string(forKey: briefingDayKey) == dayStamp(), let b = defaults.string(forKey: briefingKey) {
            v["briefing"] = b
        } else {
            v["briefing"] = ""
        }
        // 0.3 g/kg — inside the 0.25–0.4 g/kg per-meal range supported for
        // muscle protein synthesis (Schoenfeld & Aragon 2018; Morton 2018).
        if let weightKg, weightKg > 30 {
            v["postWorkoutProteinG"] = Int((0.3 * weightKg / 5).rounded()) * 5
        } else {
            v["postWorkoutProteinG"] = 0
        }
        // Last night's numbers — only sent when they exist (0 = none).
        v["sleepHours"] = (sleepHours ?? 0) > 0 ? sleepHours! : 0.0
        v["hrvMs"] = hrvMs ?? 0.0
        v["restingHR"] = restingHR ?? 0
        v["latestWeightKg"] = weightKg ?? 0.0
        WatchSessionManager.shared.pushHealth(v)
    }

    /// Your most-used saved meals, for one-tap logging from the wrist.
    static func pushQuickMeals(context: ModelContext) {
        let pid = ActiveProfile.id
        var d = FetchDescriptor<SavedMealTemplate>(
            predicate: #Predicate { $0.profileId == pid },
            sortBy: [SortDescriptor(\.useCount, order: .reverse)]
        )
        d.fetchLimit = 5
        let rows: [[String: Any]] = ((try? context.fetch(d)) ?? []).map {
            ["id": $0.id.uuidString, "name": $0.name, "kcal": Int($0.calories), "protein": Int($0.protein)]
        }
        WatchSessionManager.shared.pushHealth(["quickMeals": rows])
    }

    /// Logs a saved meal tapped on the watch (ignores an identical tap within 60 s).
    static func handleMealRequested(id: String, context: ModelContext) {
        guard let uuid = UUID(uuidString: id) else { return }
        let stampKey = "paya_watch_last_meal_\(id)"
        if Date().timeIntervalSince1970 - UserDefaults.standard.double(forKey: stampKey) < 60 { return }
        let pid = ActiveProfile.id
        guard let template = ((try? context.fetch(FetchDescriptor<SavedMealTemplate>(
            predicate: #Predicate { $0.profileId == pid && $0.id == uuid }))) ?? []).first else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: stampKey)

        let today = Calendar.current.startOfDay(for: .now)
        let existing = ((try? context.fetch(FetchDescriptor<NutritionLog>(
            predicate: #Predicate { $0.profileId == pid && $0.date >= today }))) ?? []).first
        let log: NutritionLog
        if let existing { log = existing } else {
            log = NutritionLog(date: today)
            log.profileId = pid
            context.insert(log)
        }
        let meal = MealLog(name: template.mealSlot, food: template.food, protein: template.protein,
                           calories: template.calories, fatG: template.fatG, carbsG: template.carbsG, fiberG: template.fiberG)
        context.insert(meal)
        meal.nutritionLog = log
        log.recalculateTotals()
        template.useCount += 1
        template.lastUsed = Date()
        try? context.save()
    }

    /// Logs a weight entered on the watch (kg), also writing to Apple Health.
    static func handleWeightRequested(kg: Double, context: ModelContext) {
        guard kg > 20, kg < 400 else { return }
        let key = "paya_watch_last_weight"
        let stamp = UserDefaults.standard.double(forKey: key + "_t")
        if Date().timeIntervalSince1970 - stamp < 60, UserDefaults.standard.double(forKey: key) == kg { return }
        UserDefaults.standard.set(kg, forKey: key)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key + "_t")
        let log = BodyWeightLog(weightKg: kg)
        log.profileId = ActiveProfile.id
        context.insert(log)
        try? context.save()
        Task { _ = await HealthKitManager.shared.saveBodyWeight(kg) }
    }

    /// Medications that are due today or were already taken today.
    static func pushMeds(context: ModelContext) {
        let meds = MedicationStore.active(context: context)
        let rows: [[String: Any]] = meds.compactMap { m in
            let taken = MedicationStore.takenToday(m, context: context)
            guard taken || MedicationStore.isDueToday(m, context: context) else { return nil }
            return ["id": m.id.uuidString, "name": m.name, "dose": m.dose, "taken": taken]
        }
        WatchSessionManager.shared.pushHealth(["meds": rows])
    }

    /// Logs a dose tapped on the watch. Never logs a second dose for a
    /// medication already taken today (a double-tap or a late retry).
    static func handleMedTaken(id: String, context: ModelContext) {
        guard let uuid = UUID(uuidString: id),
              let med = MedicationStore.active(context: context).first(where: { $0.id == uuid }),
              !MedicationStore.takenToday(med, context: context) else {
            pushMeds(context: context)
            return
        }
        MedicationStore.logDose(med, context: context)
        pushMeds(context: context)
    }
}
