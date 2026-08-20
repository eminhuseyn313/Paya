import SwiftData

// MARK: - Schema Versioning
//
// Pin the current schema as V1 before the first App Store release.
// Every future model change (new property, renamed field, deleted model)
// must:
//   1. Create a new VersionedSchema (V2, V3, …)
//   2. Add a MigrationStage to PayaMigrationPlan
//   3. Update SharedModelContainer to use the migration plan
//
// Without this, a SwiftData schema change in an app update will either
// silently drop data or crash on launch — there is no automatic migration
// for non-trivial changes.
//
// Reference: https://developer.apple.com/documentation/swiftdata/versionedschema

enum PayaSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
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
        ]
    }
}

enum PayaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [PayaSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // No migrations yet — V1 is the baseline.
        // When V2 is added, add a .lightweight(fromVersion:toVersion:)
        // or .custom(fromVersion:toVersion:willMigrate:didMigrate:) here.
        []
    }
}
