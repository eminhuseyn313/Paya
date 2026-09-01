import SwiftUI

// MARK: - Localization Helpers
//
// Thin wrapper around String(localized:) that keeps call sites tidy.
// Keys correspond to Localizable.xcstrings entries.
// Usage:  Text(L10n.tab.health)  or  Label(L10n.common.done, ...)

enum L10n {

    // MARK: Tabs
    enum tab {
        static var health: String   { String(localized: "tab.health") }
        static var train: String    { String(localized: "tab.train") }
        static var nutrition: String { String(localized: "tab.nutrition") }
        static var progress: String { String(localized: "tab.progress") }
    }

    // MARK: Common
    enum common {
        static var done: String     { String(localized: "common.done") }
        static var cancel: String   { String(localized: "common.cancel") }
        static var save: String     { String(localized: "common.save") }
        static var settings: String { String(localized: "common.settings") }
    }

    // MARK: Session
    enum session {
        static var start: String    { String(localized: "session.start") }
        static var finish: String   { String(localized: "session.finish") }
        static var logSet: String   { String(localized: "session.log_set") }
    }

    // MARK: Nutrition
    enum nutrition {
        static var protein: String  { String(localized: "nutrition.protein") }
        static var calories: String { String(localized: "nutrition.calories") }
        static var carbs: String    { String(localized: "nutrition.carbs") }
        static var fat: String      { String(localized: "nutrition.fat") }
        static var logMeal: String  { String(localized: "nutrition.log_meal") }
    }

    // MARK: Health
    enum health {
        static var sleep: String       { String(localized: "health.sleep") }
        static var heartRate: String   { String(localized: "health.heart_rate") }
        static var hrv: String         { String(localized: "health.hrv") }
        static var readiness: String   { String(localized: "health.readiness") }
        static var steps: String       { String(localized: "health.steps") }
        static var bloodOxygen: String { String(localized: "health.blood_oxygen") }
        static var glucose: String     { String(localized: "health.glucose") }
        static var cyclePhase: String  { String(localized: "health.cycle_phase") }
    }

    // MARK: Exercise
    enum exercise {
        static var sets: String    { String(localized: "exercise.sets") }
        static var reps: String    { String(localized: "exercise.reps") }
        static var weight: String  { String(localized: "exercise.weight") }
        static var rest: String    { String(localized: "exercise.rest") }
        static var volume: String  { String(localized: "exercise.volume") }
    }

    // MARK: Recovery
    enum recovery {
        static var normal: String  { String(localized: "recovery.normal") }
        static var caution: String { String(localized: "recovery.caution") }
        static var deload: String  { String(localized: "recovery.deload") }
    }

    // MARK: Readiness
    enum readiness {
        static var pushToday: String   { String(localized: "readiness.push_today") }
        static var recoveryDay: String { String(localized: "readiness.recovery_day") }
    }

    // MARK: Cycle
    enum cycle {
        static var menstrual: String  { String(localized: "cycle.menstrual") }
        static var follicular: String { String(localized: "cycle.follicular") }
        static var ovulatory: String  { String(localized: "cycle.ovulatory") }
        static var luteal: String     { String(localized: "cycle.luteal") }
    }

    // MARK: Glucose
    enum glucose {
        static var response: String    { String(localized: "glucose.response") }
        static var timeInRange: String { String(localized: "glucose.time_in_range") }
    }

    // MARK: Onboarding
    enum onboarding {
        static var healthJourney: String { String(localized: "onboarding.health_journey") }
    }

    // MARK: Water
    enum water {
        static var add: String { String(localized: "water.add") }
    }
}
