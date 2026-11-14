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
        weightKg: Double?
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
        WatchSessionManager.shared.pushHealth(v)
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
