import Foundation
import SwiftData
import SwiftUI

// MARK: - Person Profile
// One per user of the app. Owns goal, body stats, and condition flags.

@Model
class PersonProfile {

    var id: UUID
    var name: String
    var age: Int = 30
    var sexRaw: String = "male"
    var heightCm: Double = 178
    var currentWeightKg: Double = 85
    var bodyWeightGoalKg: Double = 80
    var goalRaw: String = TrainingGoal.hypertrophy.rawValue
    var proteinTargetG: Double = 160
    var trainingDayCalories: Double = 2200
    var restDayCalories: Double = 1900
    var hasInflammatoryCondition: Bool = false
    var chronicConditionRaw: String = ChronicCondition.rheumatoidArthritis.rawValue
    var colorHex: String = "2563EB"
    var createdAt: Date = Date()

    // Personalization inputs — drive program selection, exercise substitution,
    // and starting-weight scaling (see PersonalizationEngine).
    var experienceLevelRaw: String = ExperienceLevel.beginner.rawValue
    var equipmentAccessRaw: String = EquipmentAccess.fullGym.rawValue
    var injuryFlagsRaw: [String] = []

    /// How many days per week the user can actually train — the upstream
    /// input the split/volume science is built from, not a byproduct of
    /// whichever template happens to get installed.
    var preferredTrainingDaysPerWeek: Int = 3

    // Adaptive calorie targets (see AdaptiveCalorieEngine)
    var lastCalorieAdjustmentDate: Date? = nil
    var lastCalorieAdjustmentKcal: Double = 0
    var lastCalorieAdjustmentReason: String = ""

    // Lifestyle inputs — feed LifestylePlanEngine's AI-generated end-to-end
    // nutrition/supplement/lifestyle plan alongside everything above.
    var dietPreferenceRaw: String = DietPreference.omnivore.rawValue
    var priorityMuscleRaw: String = MusclePriority.none.rawValue
    var sleepTargetHours: Double = 8
    var stressLevel: Int = 2   // 1 (low) – 5 (high)

    // Cached AI lifestyle plan — regenerated on demand, not on every launch.
    var cachedLifestylePlan: String? = nil
    var lifestylePlanGeneratedAt: Date? = nil

    // Cached AI training-coach recommendation — same regenerate-on-demand pattern.
    var cachedCoachRecommendation: String? = nil
    var coachRecommendationGeneratedAt: Date? = nil

    init(name: String) {
        self.id = UUID()
        self.name = name
    }

    var goal: TrainingGoal {
        get { TrainingGoal(rawValue: goalRaw) ?? .hypertrophy }
        set { goalRaw = newValue.rawValue }
    }

    var experienceLevel: ExperienceLevel {
        get { ExperienceLevel(rawValue: experienceLevelRaw) ?? .beginner }
        set { experienceLevelRaw = newValue.rawValue }
    }

    var equipmentAccess: EquipmentAccess {
        get { EquipmentAccess(rawValue: equipmentAccessRaw) ?? .fullGym }
        set { equipmentAccessRaw = newValue.rawValue }
    }

    var injuryFlags: Set<InjuryArea> {
        get { Set(injuryFlagsRaw.compactMap { InjuryArea(rawValue: $0) }) }
        set { injuryFlagsRaw = newValue.map { $0.rawValue } }
    }

    var dietPreference: DietPreference {
        get { DietPreference(rawValue: dietPreferenceRaw) ?? .omnivore }
        set { dietPreferenceRaw = newValue.rawValue }
    }

    var priorityMuscle: MusclePriority {
        get { MusclePriority(rawValue: priorityMuscleRaw) ?? .none }
        set { priorityMuscleRaw = newValue.rawValue }
    }

    var chronicCondition: ChronicCondition {
        get { ChronicCondition(rawValue: chronicConditionRaw) ?? .rheumatoidArthritis }
        set { chronicConditionRaw = newValue.rawValue }
    }

    var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    var color: Color { Color(hex: colorHex) }
}

// MARK: - Profile Store

enum ProfileStore {

    private static let currentProfileKey = "current_profile_id"

    static func all(context: ModelContext) -> [PersonProfile] {
        let descriptor = FetchDescriptor<PersonProfile>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Migrates the legacy single-user UserProfile (AppState struct) into
    /// the first PersonProfile on first launch after this update.
    @MainActor
    static func migrateIfNeeded(context: ModelContext, legacy: UserProfile) {
        guard all(context: context).isEmpty else { return }
        let profile = PersonProfile(name: legacy.name)
        profile.age = legacy.age
        profile.currentWeightKg = legacy.currentWeightKg
        profile.bodyWeightGoalKg = legacy.bodyWeightGoalKg
        profile.goalRaw = legacy.goalRaw
        profile.proteinTargetG = legacy.proteinTargetG
        profile.trainingDayCalories = legacy.trainingDayCalories
        profile.restDayCalories = legacy.restDayCalories
        profile.hasInflammatoryCondition = true   // existing user has RA context
        context.insert(profile)
        try? context.save()
        setCurrent(profile)
    }

    static func current(context: ModelContext) -> PersonProfile? {
        let profiles = all(context: context)
        guard !profiles.isEmpty else { return nil }
        if let idString = UserDefaults.standard.string(forKey: currentProfileKey),
           let id = UUID(uuidString: idString),
           let match = profiles.first(where: { $0.id == id }) {
            return match
        }
        return profiles.first
    }

    static func setCurrent(_ profile: PersonProfile) {
        UserDefaults.standard.set(profile.id.uuidString, forKey: currentProfileKey)
    }

    @discardableResult
    static func add(name: String, context: ModelContext) -> PersonProfile {
        let colors = ["2563EB", "059669", "D97706", "8B5CF6", "DC2626", "0891B2"]
        let profile = PersonProfile(name: name)
        profile.colorHex = colors[all(context: context).count % colors.count]
        context.insert(profile)
        try? context.save()
        return profile
    }

    static func delete(_ profile: PersonProfile, context: ModelContext) {
        context.delete(profile)
        try? context.save()
    }
}
