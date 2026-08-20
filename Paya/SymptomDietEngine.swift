import Foundation
import SwiftData

// MARK: - Symptom Diet Engine
//
// Generates AI-powered anti-inflammatory diet recommendations based on
// the user's actual logged symptom data — not just their onboarding
// answers. Follows LifestylePlanEngine's pattern: build a comprehensive
// prompt from real behavioral data, call AIService.generate(), cache
// the result on the profile.
//
// Grounding: The anti-inflammatory dietary pattern draws from the
// Mediterranean diet evidence base (Sköldstam L, et al., Ann Rheum Dis
// 2003; Petersson S, et al., Nutrients 2018) and ISSN position stands
// on omega-3 fatty acids and joint health (Calder PC, Biochem Soc
// Trans, 2017). The engine does NOT prescribe medical treatment — it
// suggests food choices that mainstream nutrition research associates
// with reduced systemic inflammation markers.

enum SymptomDietEngine {

    @MainActor
    static func generate(profile: PersonProfile, context: ModelContext, apiKey: String) async -> String? {
        let system = """
        You are an evidence-based nutrition advisor writing personalized \
        anti-inflammatory diet guidance for one specific person based on \
        their actual logged symptom data. Ground every recommendation in \
        mainstream nutrition research — Mediterranean diet evidence \
        (Sköldstam 2003, Petersson 2018), omega-3/joint health consensus \
        (Calder 2017, ISSN position stands), and gut-inflammation links \
        (Zinöcker & Lindseth, Nutrients 2018). No fad diets, no expensive \
        specialty supplements, no medical treatment advice. \
        Be concrete and specific to their actual symptom patterns — \
        reference the symptoms they've logged, not generic advice. \
        Write in plain, warm, direct language — this appears in a fitness \
        app, not a medical journal. \
        Structure your answer with exactly these four headers, each \
        followed by 3-5 short bullet points: \
        ANTI-INFLAMMATORY FOODS: (specific foods to prioritize based on \
        their symptoms — e.g. fatty fish for joint pain, ginger for \
        nausea, leafy greens for general inflammation) \
        FOODS TO LIMIT: (specific foods that may worsen their particular \
        symptoms — e.g. refined sugar for joint inflammation, high-sodium \
        foods for swelling, alcohol for flare risk) \
        MEAL IDEAS: (2-3 simple, practical meal suggestions that \
        incorporate the recommended foods and fit their diet preference) \
        TIMING & HABITS: (when to eat around training, hydration notes, \
        any symptom-specific timing advice like avoiding late meals if \
        they log digestive issues)
        """

        let userMessage = buildUserMessage(profile: profile, context: context)
        let result = await AIService.shared.generate(system: system, userMessage: userMessage, apiKey: apiKey, requiresReasoning: true)

        if let result {
            profile.cachedSymptomDietPlan = result
            profile.symptomDietPlanGeneratedAt = .now
        }
        return result
    }

    // MARK: - Prompt Builder

    @MainActor
    private static func buildUserMessage(profile: PersonProfile, context: ModelContext) -> String {
        var lines: [String] = []

        // Basic profile
        lines.append("Age \(profile.currentAge), sex \(profile.sexRaw), weight \(Int(profile.currentWeightKg))kg.")
        lines.append("Diet preference: \(profile.dietPreference.displayName).")
        lines.append("Goal: \(profile.goal.displayName). Trains \(profile.preferredTrainingDaysPerWeek)x/week.")
        lines.append("Current targets: \(Int(profile.proteinTargetG))g protein/day, \(Int(profile.trainingDayCalories)) kcal training days, \(Int(profile.restDayCalories)) kcal rest days.")

        if profile.hasInflammatoryCondition {
            lines.append("Has an inflammatory joint condition (e.g. RA) — this is the primary driver of their symptom pattern. Focus on anti-inflammatory nutrition that supports joint health specifically.")
        }

        // Recent symptom logs (last 14 days)
        if let symptomSummary = recentSymptomSummary(context: context) {
            lines.append(symptomSummary)
        }

        // Flare day history
        if let flareSummary = recentFlareSummary(context: context) {
            lines.append(flareSummary)
        }

        // Joint pain trends
        if let painSummary = recentPainSummary(context: context) {
            lines.append(painSummary)
        }

        // Check-in symptom tags
        if let checkInSummary = recentCheckInSymptoms(context: context) {
            lines.append(checkInSummary)
        }

        // Recent nutrition (what they're actually eating)
        if let nutritionSummary = recentNutritionSnapshot(profile: profile, context: context) {
            lines.append(nutritionSummary)
        }

        // Bathroom/digestive patterns
        if let digestiveSummary = recentDigestiveSummary(context: context) {
            lines.append(digestiveSummary)
        }

        if lines.count <= 4 {
            lines.append("No symptom data logged in the last 14 days — provide general anti-inflammatory nutrition advice tailored to their profile and diet preference.")
        }

        return lines.joined(separator: " ")
    }

    // MARK: - Data Fetchers

    /// Symptom logs from the last 14 days — the primary signal for this engine.
    @MainActor
    private static func recentSymptomSummary(context: ModelContext) -> String? {
        let logs = SymptomStore.recent(daysBack: 14, context: context)
        guard !logs.isEmpty else { return nil }

        // Group by tag and count occurrences
        var tagCounts: [String: (count: Int, avgSeverity: Double)] = [:]
        for log in logs {
            let existing = tagCounts[log.tag] ?? (count: 0, avgSeverity: 0)
            let newCount = existing.count + 1
            let newAvg = (existing.avgSeverity * Double(existing.count) + Double(log.severity)) / Double(newCount)
            tagCounts[log.tag] = (count: newCount, avgSeverity: newAvg)
        }

        let sorted = tagCounts.sorted { $0.value.count > $1.value.count }
        let descriptions = sorted.map { tag, data in
            let label = symptomOptions.first(where: { $0.id == tag })?.label ?? tag
            return "\(label) ×\(data.count) (avg severity \(String(format: "%.1f", data.avgSeverity))/3)"
        }

        return "Symptom logs (last 14 days, \(logs.count) total entries): \(descriptions.joined(separator: ", "))."
    }

    /// Flare day frequency — how many of the last 14 days were marked as flare days.
    @MainActor
    private static func recentFlareSummary(context: ModelContext) -> String? {
        let pid = ActiveProfile.id
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let descriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.date >= twoWeeksAgo && $0.profileId == pid }
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        let flareDays = logs.filter { $0.isFlareDay }.count
        guard flareDays > 0 else { return nil }

        return "Flare days in last 14 days: \(flareDays) out of \(logs.count) logged days — diet recommendations should prioritize reducing flare triggers."
    }

    /// Joint pain level trend over the last 14 days.
    @MainActor
    private static func recentPainSummary(context: ModelContext) -> String? {
        let pid = ActiveProfile.id
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let descriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.date >= twoWeeksAgo && $0.profileId == pid }
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        let painLogs = logs.filter { $0.jointPainLevel > 0 }
        guard !painLogs.isEmpty else { return nil }

        let avgPain = Double(painLogs.reduce(0) { $0 + $1.jointPainLevel }) / Double(painLogs.count)
        let maxPain = painLogs.map { $0.jointPainLevel }.max() ?? 0

        return "Joint pain (last 14 days): avg \(String(format: "%.1f", avgPain))/10, peak \(maxPain)/10 across \(painLogs.count) days with pain logged."
    }

    /// Symptom tags from morning check-ins.
    @MainActor
    private static func recentCheckInSymptoms(context: ModelContext) -> String? {
        let pid = ActiveProfile.id
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        let descriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate<DailyCheckIn> { $0.date >= twoWeeksAgo && $0.profileId == pid }
        )
        let checkIns = (try? context.fetch(descriptor)) ?? []
        let withSymptoms = checkIns.filter { !$0.symptomTags.isEmpty }
        guard !withSymptoms.isEmpty else { return nil }

        var tagFreq: [String: Int] = [:]
        for ci in withSymptoms {
            for tag in ci.symptomTags {
                tagFreq[tag, default: 0] += 1
            }
        }
        let sorted = tagFreq.sorted { $0.value > $1.value }
        let tagList = sorted.prefix(5).map { "\($0.key) ×\($0.value)" }.joined(separator: ", ")

        let avgSoreness = Double(checkIns.reduce(0) { $0 + $1.soreness }) / Double(checkIns.count)
        let avgEnergy = Double(checkIns.reduce(0) { $0 + $1.energy }) / Double(checkIns.count)

        return "Morning check-in trends (14d): \(checkIns.count) check-ins, \(withSymptoms.count) had symptoms (\(tagList)). Avg soreness \(String(format: "%.1f", avgSoreness))/5, avg energy \(String(format: "%.1f", avgEnergy))/3."
    }

    /// What they've actually been eating — so diet advice doesn't ignore reality.
    @MainActor
    private static func recentNutritionSnapshot(profile: PersonProfile, context: ModelContext) -> String? {
        let pid = ActiveProfile.id
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let descriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.date >= weekAgo && $0.profileId == pid }
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        guard !logs.isEmpty else { return nil }

        let avgProtein = logs.reduce(0.0) { $0 + $1.totalProtein } / Double(logs.count)
        let avgCalories = logs.reduce(0.0) { $0 + $1.totalCalories } / Double(logs.count)
        let avgFat = logs.reduce(0.0) { $0 + $1.totalFatG } / Double(logs.count)
        let avgCarbs = logs.reduce(0.0) { $0 + $1.totalCarbsG } / Double(logs.count)

        return "Recent nutrition (7d avg, \(logs.count) days logged): \(Int(avgCalories)) kcal, \(Int(avgProtein))g protein, \(Int(avgFat))g fat, \(Int(avgCarbs))g carbs."
    }

    /// Digestive patterns from bathroom logs — relevant for gut-inflammation axis.
    @MainActor
    private static func recentDigestiveSummary(context: ModelContext) -> String? {
        let pid = ActiveProfile.id
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let descriptor = FetchDescriptor<BathroomLog>(
            predicate: #Predicate<BathroomLog> { $0.date >= weekAgo && $0.profileId == pid }
        )
        let logs = (try? context.fetch(descriptor)) ?? []
        let poopLogs = logs.filter { $0.type == "poop" }
        guard !poopLogs.isEmpty else { return nil }

        let bristolScales = poopLogs.compactMap { $0.bristolScale }
        guard !bristolScales.isEmpty else { return nil }

        let avgBristol = Double(bristolScales.reduce(0, +)) / Double(bristolScales.count)
        let looseDays = bristolScales.filter { $0 >= 6 }.count
        let constipatedDays = bristolScales.filter { $0 <= 2 }.count

        var summary = "Digestive pattern (7d): \(poopLogs.count) bowel movements, avg Bristol \(String(format: "%.1f", avgBristol))/7."
        if looseDays > 0 { summary += " \(looseDays) loose stool events." }
        if constipatedDays > 0 { summary += " \(constipatedDays) constipation events." }
        if looseDays > 0 || constipatedDays > 0 {
            summary += " Factor digestive health into food recommendations."
        }
        return summary
    }
}
