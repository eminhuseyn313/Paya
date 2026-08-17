import Foundation
import SwiftData

// MARK: - Lifestyle Plan Engine
//
// GoalEngine gives hard numeric nutrition targets (protein/calories) from a
// pure formula, and UserSupplementStore seeds a static goal-keyed supplement
// table — both are deliberately deterministic since the rest of the app
// depends on those numbers. What was missing is the end-to-end synthesis:
// taking EVERY questionnaire answer (goal, experience, equipment, injuries,
// training days, diet preference, sleep target, stress) together and having
// AI turn it into one coherent, personalized narrative — how those numbers
// actually play out in a real week, tailored to this specific person rather
// than five fixed buckets. Cached on the profile and regenerated on demand,
// not on every launch.
//
// This also feeds in actual recent behavior (nutrition adherence, daily
// check-in trends) rather than only the static onboarding snapshot — so the
// plan reflects what's really happening, not just what was answered once at
// setup. A person who said "low stress" at onboarding but has logged high
// soreness/low energy for a week should get advice that reflects the week,
// not the questionnaire.

enum LifestylePlanEngine {

    @MainActor
    static func generate(profile: PersonProfile, context: ModelContext, apiKey: String) async -> String? {
        let system = """
        You are an evidence-based strength & nutrition coach writing a short, \
        personalized lifestyle plan for one specific person. Ground every \
        recommendation in mainstream sports-science consensus (ACSM/NSCA \
        position stands, ISSN nutrition guidance) — no fad claims, no products \
        to buy beyond common, cheap, well-studied supplements. Be concrete and \
        specific to the numbers given, not generic — if recent behavior data is \
        included, react to it directly rather than repeating generic advice. \
        Write in plain, warm, direct language — this appears in a fitness app, \
        not a medical report. \
        Structure your answer with exactly these three headers, each followed \
        by 2-4 short sentences or bullet points: \
        NUTRITION: (how to actually hit their protein/calorie targets given \
        their diet preference, meal-timing around training, and how their \
        recent adherence has actually looked) \
        SUPPLEMENTS: (only well-evidenced, appropriate for their goal and diet) \
        LIFESTYLE: (sleep, stress, and recovery advice tailored to what they \
        reported AND what their recent check-ins actually show)
        """

        let userMessage = buildUserMessage(profile: profile, context: context)
        let result = await AIService.shared.generate(system: system, userMessage: userMessage, apiKey: apiKey, requiresReasoning: true)

        if let result {
            profile.cachedLifestylePlan = result
            profile.lifestylePlanGeneratedAt = .now
        }
        return result
    }

    private static func buildUserMessage(profile: PersonProfile, context: ModelContext) -> String {
        var lines: [String] = []
        lines.append("Age \(profile.currentAge), sex \(profile.sexRaw), height \(Int(profile.heightCm))cm, weight \(Int(profile.currentWeightKg))kg.")
        lines.append("Goal: \(profile.goal.displayName). Experience: \(profile.experienceLevel.displayName). Trains \(profile.preferredTrainingDaysPerWeek)x/week with \(profile.equipmentAccess.displayName.lowercased()).")
        if !profile.injuryFlags.isEmpty {
            lines.append("Areas to go easy on: \(profile.injuryFlags.map { $0.displayName.lowercased() }.joined(separator: ", ")).")
        }
        lines.append("Diet preference: \(profile.dietPreference.displayName).")
        lines.append("Current numeric targets already computed: \(Int(profile.proteinTargetG))g protein/day, \(Int(profile.trainingDayCalories)) kcal training days, \(Int(profile.restDayCalories)) kcal rest days — work within these, don't recompute them.")
        lines.append("Sleep target: \(String(format: "%.1f", profile.sleepTargetHours))h/night. Self-reported stress level: \(profile.stressLevel)/5.")
        if profile.hasInflammatoryCondition {
            lines.append("Has an inflammatory joint condition (e.g. RA) — factor gentle, anti-inflammatory-friendly guidance into lifestyle advice, not medical treatment advice.")
        }

        if let adherence = recentNutritionAdherence(profile: profile, context: context) {
            lines.append(adherence)
        }
        if let checkInSummary = recentCheckInSummary(profile: profile, context: context) {
            lines.append(checkInSummary)
        }

        return lines.joined(separator: " ")
    }

    /// Last 7 days of actual logged calories/protein vs. target — so
    /// nutrition advice reacts to real adherence, not just the goal formula.
    @MainActor
    private static func recentNutritionAdherence(profile: PersonProfile, context: ModelContext) -> String? {
        let pid = ActiveProfile.id
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let descriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.date >= weekAgo && $0.profileId == pid }
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        guard !logs.isEmpty else { return nil }

        let avgProtein = logs.reduce(0.0) { $0 + $1.totalProtein } / Double(logs.count)
        let avgCalories = logs.reduce(0.0) { $0 + $1.totalCalories } / Double(logs.count)
        let proteinPercent = Int((avgProtein / max(1, profile.proteinTargetG)) * 100)
        let caloriePercent = Int((avgCalories / max(1, profile.trainingDayCalories)) * 100)

        return "Last 7 days actual logging: averaging \(Int(avgProtein))g protein/day (\(proteinPercent)% of target), \(Int(avgCalories)) kcal/day (\(caloriePercent)% of training-day target) — \(logs.count) day(s) logged."
    }

    /// Last 7 days of morning check-ins — soreness/energy/symptom trend, so
    /// lifestyle advice reacts to how the week has actually gone, not just
    /// the one-time onboarding stress/sleep answers.
    @MainActor
    private static func recentCheckInSummary(profile: PersonProfile, context: ModelContext) -> String? {
        let pid = ActiveProfile.id
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let descriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate<DailyCheckIn> { $0.date >= weekAgo && $0.profileId == pid }
        )
        let checkIns = (try? context.fetch(descriptor)) ?? []
        guard !checkIns.isEmpty else { return nil }

        let avgSoreness = Double(checkIns.reduce(0) { $0 + $1.soreness }) / Double(checkIns.count)
        let avgEnergy = Double(checkIns.reduce(0) { $0 + $1.energy }) / Double(checkIns.count)
        let flaggedDays = checkIns.filter { !$0.symptomTags.isEmpty }.count

        var summary = "Last 7 days of morning check-ins (\(checkIns.count) logged): average soreness \(String(format: "%.1f", avgSoreness))/5, average energy \(String(format: "%.1f", avgEnergy))/3."
        if flaggedDays > 0 {
            summary += " Flagged a symptom on \(flaggedDays) of those days — take this seriously in the lifestyle section."
        }
        return summary
    }
}
