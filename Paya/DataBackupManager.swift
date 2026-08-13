import Foundation
import SwiftData

// MARK: - Data Backup Manager
//
// The existing CSV export is read-only — useful for looking at your data
// in a spreadsheet, useless for actually getting it back after a device
// loss. "Lost years of data" from a device switch is one of the most
// consistently cited fitness-app complaints in reviews/Reddit threads.
// Real iCloud sync (CloudKit) would need entitlement/container provisioning
// tied to the developer account — not something to add blind — but a real,
// restorable JSON backup file needs none of that and directly covers the
// same fear: training history, body weight, measurements, and nutrition
// logs can be exported to one file and restored from it on any device.
//
// Progress photos are deliberately excluded from this backup (they'd make
// the file enormous) — those still rely on the device's own iCloud Backup.

struct PayaBackup: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let sessions: [BackupSession]
    let bodyWeights: [BackupWeightEntry]
    let bodyMeasurements: [BackupMeasurement]
    let nutritionLogs: [BackupNutritionLog]
    let healthLogs: [BackupHealthLog]
}

struct BackupSession: Codable {
    var sessionType: String
    var date: Date
    var durationMinutes: Int
    var isFlareDay: Bool
    var notes: String
    var sourceRaw: String
    var sessionAvgHR: Int?
    var sessionPeakHR: Int?
    var sessionTrimpScore: Double?
    var subjectiveRPE: Int?
    var exercises: [BackupExerciseLog]
}

struct BackupExerciseLog: Codable {
    var exerciseId: String
    var exerciseName: String
    var orderIndex: Int
    var isPersonalBest: Bool
    var sets: [BackupSetLog]
}

struct BackupSetLog: Codable {
    var setNumber: Int
    var weightKg: Double
    var reps: Int
    var isCompleted: Bool
    var rpe: Int
}

struct BackupWeightEntry: Codable {
    var date: Date
    var weightKg: Double
}

struct BackupMeasurement: Codable {
    var date: Date
    var neckCm: Double?
    var chestCm: Double?
    var waistCm: Double?
    var hipsCm: Double?
    var bicepCm: Double?
    var thighCm: Double?
    var calfCm: Double?
}

struct BackupNutritionLog: Codable {
    var date: Date
    var totalProtein: Double
    var totalCalories: Double
    var proteinTarget: Double
    var calorieTarget: Double
    var meals: [BackupMeal]
}

struct BackupMeal: Codable {
    var name: String
    var food: String
    var protein: Double
    var calories: Double
    var loggedAt: Date
}

struct BackupHealthLog: Codable {
    var date: Date
    var isFlareDay: Bool
    var jointPainLevel: Int
    var sleepHours: Double
    var energyLevel: Int
    var waterMl: Int
}

enum DataBackupManager {

    @MainActor
    static func export(context: ModelContext) -> Data? {
        let pid = ActiveProfile.id

        let sessions = ((try? context.fetch(FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid }
        ))) ?? []).map { session in
            BackupSession(
                sessionType: session.sessionType,
                date: session.date,
                durationMinutes: session.durationMinutes,
                isFlareDay: session.isFlareDay,
                notes: session.notes,
                sourceRaw: session.sourceRaw,
                sessionAvgHR: session.sessionAvgHR,
                sessionPeakHR: session.sessionPeakHR,
                sessionTrimpScore: session.sessionTrimpScore,
                subjectiveRPE: session.subjectiveRPE,
                exercises: session.exercises.map { ex in
                    BackupExerciseLog(
                        exerciseId: ex.exerciseId,
                        exerciseName: ex.exerciseName,
                        orderIndex: ex.orderIndex,
                        isPersonalBest: ex.isPersonalBest,
                        sets: ex.sets.map { set in
                            BackupSetLog(setNumber: set.setNumber, weightKg: set.weightKg, reps: set.reps, isCompleted: set.isCompleted, rpe: set.rpe)
                        }
                    )
                }
            )
        }

        let weights = ((try? context.fetch(FetchDescriptor<BodyWeightLog>(
            predicate: #Predicate<BodyWeightLog> { $0.profileId == pid }
        ))) ?? []).map { BackupWeightEntry(date: $0.date, weightKg: $0.weightKg) }

        let measurements = ((try? context.fetch(FetchDescriptor<BodyMeasurementLog>(
            predicate: #Predicate<BodyMeasurementLog> { $0.profileId == pid }
        ))) ?? []).map {
            BackupMeasurement(date: $0.date, neckCm: $0.neckCm, chestCm: $0.chestCm, waistCm: $0.waistCm, hipsCm: $0.hipsCm, bicepCm: $0.bicepCm, thighCm: $0.thighCm, calfCm: $0.calfCm)
        }

        let nutritionLogs = ((try? context.fetch(FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == pid }
        ))) ?? []).map { log in
            BackupNutritionLog(
                date: log.date, totalProtein: log.totalProtein, totalCalories: log.totalCalories,
                proteinTarget: log.proteinTarget, calorieTarget: log.calorieTarget,
                meals: log.meals.map { BackupMeal(name: $0.name, food: $0.food, protein: $0.protein, calories: $0.calories, loggedAt: $0.loggedAt) }
            )
        }

        let healthLogs = ((try? context.fetch(FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.profileId == pid }
        ))) ?? []).map {
            BackupHealthLog(date: $0.date, isFlareDay: $0.isFlareDay, jointPainLevel: $0.jointPainLevel, sleepHours: $0.sleepHours, energyLevel: $0.energyLevel, waterMl: $0.waterMl)
        }

        let backup = PayaBackup(
            schemaVersion: 1,
            exportedAt: .now,
            sessions: sessions,
            bodyWeights: weights,
            bodyMeasurements: measurements,
            nutritionLogs: nutritionLogs,
            healthLogs: healthLogs
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(backup)
    }

    /// Inserts everything from the backup as new records — this is a
    /// restore-onto-a-fresh-device operation, not a smart two-way merge.
    /// Running it twice on the same store will duplicate entries; the UI
    /// warns about this rather than silently deduping (dedup-by-date would
    /// silently drop a legitimate second session logged the same day).
    @MainActor
    static func importBackup(data: Data, context: ModelContext) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(PayaBackup.self, from: data)
        let pid = ActiveProfile.id
        var count = 0

        for s in backup.sessions {
            let session = TrainingSession(
                sessionType: s.sessionType, date: s.date, durationMinutes: s.durationMinutes,
                isCompleted: true, notes: s.notes, isFlareDay: s.isFlareDay,
                sessionPeakHR: s.sessionPeakHR, sessionAvgHR: s.sessionAvgHR,
                sessionTrimpScore: s.sessionTrimpScore, subjectiveRPE: s.subjectiveRPE
            )
            session.profileId = pid
            session.sourceRaw = s.sourceRaw
            for e in s.exercises {
                let exLog = ExerciseLog(exerciseId: e.exerciseId, exerciseName: e.exerciseName, orderIndex: e.orderIndex, isPersonalBest: e.isPersonalBest)
                exLog.sets = e.sets.map { SetLog(setNumber: $0.setNumber, weightKg: $0.weightKg, reps: $0.reps, isCompleted: $0.isCompleted, rpe: $0.rpe) }
                exLog.session = session
                session.exercises.append(exLog)
            }
            context.insert(session)
            count += 1
        }

        for w in backup.bodyWeights {
            let log = BodyWeightLog(date: w.date, weightKg: w.weightKg)
            log.profileId = pid
            context.insert(log)
            count += 1
        }

        for m in backup.bodyMeasurements {
            let log = BodyMeasurementLog(date: m.date)
            log.profileId = pid
            log.neckCm = m.neckCm
            log.chestCm = m.chestCm
            log.waistCm = m.waistCm
            log.hipsCm = m.hipsCm
            log.bicepCm = m.bicepCm
            log.thighCm = m.thighCm
            log.calfCm = m.calfCm
            context.insert(log)
            count += 1
        }

        for n in backup.nutritionLogs {
            let log = NutritionLog(date: n.date, isTrainingDay: false, proteinTarget: n.proteinTarget, calorieTarget: n.calorieTarget)
            log.profileId = pid
            log.totalProtein = n.totalProtein
            log.totalCalories = n.totalCalories
            log.meals = n.meals.map { MealLog(name: $0.name, food: $0.food, protein: $0.protein, calories: $0.calories, loggedAt: $0.loggedAt) }
            context.insert(log)
            count += 1
        }

        for h in backup.healthLogs {
            let log = HealthLog(date: h.date, isFlareDay: h.isFlareDay, jointPainLevel: h.jointPainLevel, sleepHours: h.sleepHours, energyLevel: h.energyLevel)
            log.profileId = pid
            log.waterMl = h.waterMl
            context.insert(log)
            count += 1
        }

        try context.save()
        return count
    }
}
