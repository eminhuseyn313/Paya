import SwiftData
import Foundation

// MARK: - Local Data Wiper
//
// This app treats "one Supabase account = one device": each person signs
// into their own account on their own device, rather than multiple people
// sharing one install. SyncManager pushes ALL local SwiftData rows to
// whichever account is currently signed in, without per-account scoping —
// so without this, signing out and a DIFFERENT account signing in later
// would push the first person's leftover local health data to the second
// person's cloud account on next sync. Wiping local data on sign-out closes
// that gap: a fresh sign-in always starts from an empty local store.

enum LocalDataWiper {

    @MainActor
    static func wipeAll(context: ModelContext) {
        let types: [any PersistentModel.Type] = [
            TrainingSession.self,
            ExerciseLog.self,
            SetLog.self,
            NutritionLog.self,
            MealLog.self,
            HealthLog.self,
            BodyWeightLog.self,
            CustomMealTemplate.self,
            CustomSession.self,
            CustomSessionExercise.self,
            TrainingDayConfig.self,
            UserSupplement.self,
            PersonProfile.self,
            NotificationRecord.self,
            DailyCheckIn.self,
            WaterEventLog.self,
            WellnessInsightRecord.self,
            BodyMeasurementLog.self,
            ProgressPhoto.self,
            EnvironmentalReading.self,
            Medication.self,
            MedicationDoseLog.self,
            MobilityCheckIn.self,
            BloodPressureLog.self,
            SorenessRegionLog.self,
            OutdoorTimeLog.self,
            SymptomLog.self,
            Achievement.self,
            SavedMealTemplate.self,
            BehaviorLog.self,
            BathroomLog.self,
            Experiment.self,
            NarrativeHistoryEntry.self,
        ]

        for type in types {
            try? context.delete(model: type)
        }
        try? context.save()

        // Per-device UserDefaults state that references now-deleted rows or
        // is otherwise scoped to the departing account.
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "current_profile_id")
        defaults.removeObject(forKey: "supabase_last_sync")
    }
}
