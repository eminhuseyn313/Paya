import SwiftData
import Foundation

// MARK: - Shared Model Container
// The same schema/store PayaApp's `.modelContainer(for:)` scene modifier
// uses, exposed as a singleton so background code (HealthKit observer
// queries, etc.) that runs outside the view hierarchy can read/write the
// same persisted data.

enum SharedModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
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
            BehaviorLog.self
        ])
        do {
            return try ModelContainer(for: schema)
        } catch {
            // Schema migration failed — likely a model property changed
            // between app versions. Delete the corrupted store and start
            // fresh. This is a last resort; proper VersionedSchema migrations
            // should prevent this path from ever firing.
            let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            if let appSupport = urls.first {
                let storeURL = appSupport.appendingPathComponent("default.store")
                try? FileManager.default.removeItem(at: storeURL)
                // Also remove WAL/SHM files
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            }
            do {
                return try ModelContainer(for: schema)
            } catch {
                fatalError("Failed to create ModelContainer even after store reset: \(error)")
            }
        }
    }()
}
