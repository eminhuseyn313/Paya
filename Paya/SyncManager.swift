import Foundation
import SwiftData

// MARK: - Sync Manager
// Pushes all local SwiftData records to Supabase as a full backup.
// Strategy: offline-first — SwiftData is always the source of truth.
// Sync is a one-way push (local → cloud) with upsert semantics.
// Future: add pull (cloud → local) for device migration.

@MainActor
final class SyncManager {

    static let shared = SyncManager()
    private let client = SupabaseClient.shared

    private init() {}

    // MARK: - Full Sync

    func syncAll(context: ModelContext) async throws {
        guard client.isSignedIn, let uid = client.userId else {
            throw SupabaseClient.SyncError.auth("Not signed in")
        }

        client.isSyncing = true
        client.syncError = nil
        defer { client.isSyncing = false }

        do {
            // 1. Profile
            try await syncProfiles(context: context, userId: uid)

            // 2. Training
            try await syncTrainingSessions(context: context, userId: uid)
            try await syncExerciseLogs(context: context, userId: uid)
            try await syncSetLogs(context: context, userId: uid)

            // 3. Nutrition
            try await syncNutritionLogs(context: context, userId: uid)
            try await syncMealLogs(context: context, userId: uid)

            // 4. Health
            try await syncHealthLogs(context: context, userId: uid)
            try await syncBodyWeightLogs(context: context, userId: uid)
            try await syncBodyMeasurementLogs(context: context, userId: uid)
            try await syncDailyCheckIns(context: context, userId: uid)
            try await syncWaterEventLogs(context: context, userId: uid)
            try await syncBloodPressureLogs(context: context, userId: uid)
            try await syncOutdoorTimeLogs(context: context, userId: uid)
            try await syncSorenessRegionLogs(context: context, userId: uid)
            try await syncMobilityCheckIns(context: context, userId: uid)
            try await syncSymptomLogs(context: context, userId: uid)

            // 5. Supplements & Meds
            try await syncUserSupplements(context: context, userId: uid)
            try await syncMedications(context: context, userId: uid)
            try await syncMedicationDoseLogs(context: context, userId: uid)

            // 6. Templates & Config
            try await syncCustomSessions(context: context, userId: uid)
            try await syncCustomSessionExercises(context: context, userId: uid)
            try await syncTrainingDayConfigs(context: context, userId: uid)
            try await syncCustomMealTemplates(context: context, userId: uid)

            // 7. Misc
            try await syncAchievements(context: context, userId: uid)
            try await syncEnvironmentalReadings(context: context, userId: uid)
            try await syncWellnessInsightRecords(context: context, userId: uid)

            client.markSynced()
        } catch {
            client.syncError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Table Sync Methods

    private func syncProfiles(context: ModelContext, userId: UUID) async throws {
        let profiles = (try? context.fetch(FetchDescriptor<PersonProfile>())) ?? []
        let rows: [[String: Any]] = profiles.map { p in
            [
                "id": p.id.uuidString,
                "user_id": userId.uuidString,
                "name": p.name,
                "birth_year": p.birthYear as Any,
                "age": p.age,
                "sex_raw": p.sexRaw,
                "height_cm": p.heightCm,
                "current_weight_kg": p.currentWeightKg,
                "body_weight_goal_kg": p.bodyWeightGoalKg,
                "goal_raw": p.goalRaw,
                "protein_target_g": p.proteinTargetG,
                "training_day_calories": p.trainingDayCalories,
                "rest_day_calories": p.restDayCalories,
                "has_inflammatory_condition": p.hasInflammatoryCondition,
                "chronic_condition_raw": p.chronicConditionRaw,
                "color_hex": p.colorHex,
                "experience_level_raw": p.experienceLevelRaw,
                "equipment_access_raw": p.equipmentAccessRaw,
                "injury_flags_raw": p.injuryFlagsRaw,
                "preferred_training_days_per_week": p.preferredTrainingDaysPerWeek,
                "diet_preference_raw": p.dietPreferenceRaw,
                "priority_muscle_raw": p.priorityMuscleRaw,
            ]
        }
        try await upsertJSON(table: "profiles", rows: rows)
    }

    private func syncTrainingSessions(context: ModelContext, userId: UUID) async throws {
        let sessions = (try? context.fetch(FetchDescriptor<TrainingSession>())) ?? []
        let rows: [[String: Any]] = sessions.map { s in
            [
                "id": s.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": s.profileId?.uuidString as Any,
                "session_type": s.sessionType,
                "date": iso(s.date),
                "duration_minutes": s.durationMinutes,
                "is_completed": s.isCompleted,
                "notes": s.notes,
                "is_flare_day": s.isFlareDay,
                "source_raw": s.sourceRaw,
                "external_workout_id": s.externalWorkoutId as Any,
                "hr_samples": s.hrSamples as Any,
                "hr_sample_interval_seconds": s.hrSampleIntervalSeconds,
                "session_peak_hr": s.sessionPeakHR as Any,
                "session_avg_hr": s.sessionAvgHR as Any,
                "session_trimp_score": s.sessionTrimpScore as Any,
                "hr_recovery_60": s.hrRecovery60 as Any,
                "subjective_rpe": s.subjectiveRPE as Any,
                "energy_after": s.energyAfter as Any,
                "reflection_tags": s.reflectionTags,
                "reflection_notes": s.reflectionNotes as Any,
                "reflected_at": s.reflectedAt.map { iso($0) } as Any,
            ]
        }
        try await upsertJSON(table: "training_sessions", rows: rows)
    }

    private func syncExerciseLogs(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<ExerciseLog>())) ?? []
        let rows: [[String: Any]] = logs.compactMap { e in
            guard let sessionId = e.session?.id else { return nil }
            return [
                "id": e.id.uuidString,
                "user_id": userId.uuidString,
                "session_id": sessionId.uuidString,
                "exercise_id": e.exerciseId,
                "exercise_name": e.exerciseName,
                "is_personal_best": e.isPersonalBest,
                "order_index": e.orderIndex,
                "muscle_group": e.muscleGroup,
                "note": e.note,
            ]
        }
        try await upsertJSON(table: "exercise_logs", rows: rows)
    }

    private func syncSetLogs(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<SetLog>())) ?? []
        let rows: [[String: Any]] = logs.compactMap { s in
            guard let exerciseId = s.exercise?.id else { return nil }
            return [
                "id": s.id.uuidString,
                "user_id": userId.uuidString,
                "exercise_log_id": exerciseId.uuidString,
                "set_number": s.setNumber,
                "weight_kg": s.weightKg,
                "reps": s.reps,
                "is_completed": s.isCompleted,
                "rpe": s.rpe,
                "peak_hr": s.peakHR as Any,
                "avg_hr": s.avgHR as Any,
                "end_hr": s.endHR as Any,
            ]
        }
        try await upsertJSON(table: "set_logs", rows: rows)
    }

    private func syncNutritionLogs(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<NutritionLog>())) ?? []
        let rows: [[String: Any]] = logs.map { n in
            [
                "id": n.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": n.profileId?.uuidString as Any,
                "date": iso(n.date),
                "total_protein": n.totalProtein,
                "total_calories": n.totalCalories,
                "is_training_day": n.isTrainingDay,
                "protein_target": n.proteinTarget,
                "calorie_target": n.calorieTarget,
            ]
        }
        try await upsertJSON(table: "nutrition_logs", rows: rows)
    }

    private func syncMealLogs(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<MealLog>())) ?? []
        let rows: [[String: Any]] = logs.compactMap { m in
            guard let nutritionId = m.nutritionLog?.id else { return nil }
            return [
                "id": m.id.uuidString,
                "user_id": userId.uuidString,
                "nutrition_log_id": nutritionId.uuidString,
                "name": m.name,
                "food": m.food,
                "protein": m.protein,
                "calories": m.calories,
                "logged_at": iso(m.loggedAt),
                "fat_g": m.fatG,
                "carbs_g": m.carbsG,
                "fiber_g": m.fiberG,
                "sugar_g": m.sugarG,
                "sodium_mg": m.sodiumMg,
                "iron_mg": m.ironMg,
                "calcium_mg": m.calciumMg,
                "magnesium_mg": m.magnesiumMg,
                "zinc_mg": m.zincMg,
                "vitamin_d_mcg": m.vitaminDMcg,
                "potassium_mg": m.potassiumMg,
                "vitamin_c_mg": m.vitaminCMg,
            ]
        }
        try await upsertJSON(table: "meal_logs", rows: rows)
    }

    private func syncHealthLogs(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<HealthLog>())) ?? []
        let rows: [[String: Any]] = logs.map { h in
            [
                "id": h.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": h.profileId?.uuidString as Any,
                "date": iso(h.date),
                "is_flare_day": h.isFlareDay,
                "joint_pain_level": h.jointPainLevel,
                "sleep_hours": h.sleepHours,
                "energy_level": h.energyLevel,
                "notes": h.notes,
                "supplements_taken": h.supplementsTaken,
                "water_ml": h.waterMl,
            ]
        }
        try await upsertJSON(table: "health_logs", rows: rows)
    }

    private func syncBodyWeightLogs(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<BodyWeightLog>())) ?? []
        let rows: [[String: Any]] = logs.map { w in
            [
                "id": w.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": w.profileId?.uuidString as Any,
                "date": iso(w.date),
                "weight_kg": w.weightKg,
            ]
        }
        try await upsertJSON(table: "body_weight_logs", rows: rows)
    }

    private func syncBodyMeasurementLogs(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<BodyMeasurementLog>())) ?? []
        let rows: [[String: Any]] = logs.map { b in
            [
                "id": b.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": b.profileId?.uuidString as Any,
                "date": iso(b.date),
                "neck_cm": b.neckCm as Any,
                "chest_cm": b.chestCm as Any,
                "waist_cm": b.waistCm as Any,
                "hips_cm": b.hipsCm as Any,
                "bicep_cm": b.bicepCm as Any,
                "thigh_cm": b.thighCm as Any,
                "calf_cm": b.calfCm as Any,
            ]
        }
        try await upsertJSON(table: "body_measurement_logs", rows: rows)
    }

    private func syncDailyCheckIns(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<DailyCheckIn>())) ?? []
        let rows: [[String: Any]] = logs.map { c in
            [
                "id": c.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": c.profileId?.uuidString as Any,
                "date": iso(c.date),
                "soreness": c.soreness,
                "energy": c.energy,
                "symptom_tags": c.symptomTags,
            ]
        }
        try await upsertJSON(table: "daily_check_ins", rows: rows)
    }

    private func syncWaterEventLogs(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<WaterEventLog>())) ?? []
        let rows: [[String: Any]] = logs.map { w in
            [
                "id": w.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": w.profileId?.uuidString as Any,
                "date": iso(w.date),
                "ml": w.ml,
                "drink_type_raw": w.drinkTypeRaw,
            ]
        }
        try await upsertJSON(table: "water_event_logs", rows: rows)
    }

    private func syncBloodPressureLogs(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<BloodPressureLog>())) ?? []
        let rows: [[String: Any]] = logs.map { b in
            [
                "id": b.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": b.profileId?.uuidString as Any,
                "date": iso(b.date),
                "systolic": b.systolic,
                "diastolic": b.diastolic,
                "source": b.source,
            ]
        }
        try await upsertJSON(table: "blood_pressure_logs", rows: rows)
    }

    private func syncOutdoorTimeLogs(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<OutdoorTimeLog>())) ?? []
        let rows: [[String: Any]] = logs.map { o in
            [
                "id": o.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": o.profileId?.uuidString as Any,
                "date": iso(o.date),
                "minutes": o.minutes,
            ]
        }
        try await upsertJSON(table: "outdoor_time_logs", rows: rows)
    }

    private func syncSorenessRegionLogs(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<SorenessRegionLog>())) ?? []
        let rows: [[String: Any]] = logs.map { s in
            [
                "id": s.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": s.profileId?.uuidString as Any,
                "date": iso(s.date),
                "regions_raw": s.regionsRaw,
            ]
        }
        try await upsertJSON(table: "soreness_region_logs", rows: rows)
    }

    private func syncMobilityCheckIns(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<MobilityCheckIn>())) ?? []
        let rows: [[String: Any]] = logs.map { m in
            [
                "id": m.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": m.profileId?.uuidString as Any,
                "date": iso(m.date),
                "shoulder_score": m.shoulderScore,
                "hip_score": m.hipScore,
                "ankle_score": m.ankleScore,
            ]
        }
        try await upsertJSON(table: "mobility_check_ins", rows: rows)
    }

    private func syncSymptomLogs(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<SymptomLog>())) ?? []
        let rows: [[String: Any]] = logs.map { s in
            [
                "id": s.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": s.profileId?.uuidString as Any,
                "date": iso(s.date),
                "onset_date": iso(s.onsetDate),
                "tag": s.tag,
                "severity": s.severity,
                "notes": s.notes,
            ]
        }
        try await upsertJSON(table: "symptom_logs", rows: rows)
    }

    private func syncUserSupplements(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<UserSupplement>())) ?? []
        let rows: [[String: Any]] = logs.map { s in
            [
                "id": s.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": s.profileId?.uuidString as Any,
                "name": s.name,
                "dose": s.dose,
                "timing": s.timing,
                "order_index": s.orderIndex,
                "is_active": s.isActive,
                "is_auto_seeded": s.isAutoSeeded,
            ]
        }
        try await upsertJSON(table: "user_supplements", rows: rows)
    }

    private func syncMedications(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
        let rows: [[String: Any]] = logs.map { m in
            [
                "id": m.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": m.profileId?.uuidString as Any,
                "name": m.name,
                "dose": m.dose,
                "frequency_raw": m.frequencyRaw,
                "start_date": iso(m.startDate),
                "is_active": m.isActive,
                "notes": m.notes,
            ]
        }
        try await upsertJSON(table: "medications", rows: rows)
    }

    private func syncMedicationDoseLogs(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<MedicationDoseLog>())) ?? []
        let rows: [[String: Any]] = logs.map { d in
            [
                "id": d.id.uuidString,
                "user_id": userId.uuidString,
                "medication_id": d.medicationId.uuidString,
                "taken_at": iso(d.takenAt),
                "profile_id": d.profileId?.uuidString as Any,
            ]
        }
        try await upsertJSON(table: "medication_dose_logs", rows: rows)
    }

    private func syncCustomSessions(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<CustomSession>())) ?? []
        let rows: [[String: Any]] = logs.map { c in
            [
                "id": c.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": c.profileId?.uuidString as Any,
                "session_type_raw": c.sessionTypeRaw,
                "last_edited_at": iso(c.lastEditedAt),
            ]
        }
        try await upsertJSON(table: "custom_sessions", rows: rows)
    }

    private func syncCustomSessionExercises(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<CustomSessionExercise>())) ?? []
        let rows: [[String: Any]] = logs.compactMap { e in
            guard let sessionId = e.session?.id else { return nil }
            return [
                "id": e.id.uuidString,
                "user_id": userId.uuidString,
                "session_id": sessionId.uuidString,
                "exercise_id": e.exerciseId,
                "exercise_name": e.exerciseName,
                "order_index": e.orderIndex,
                "sets": e.sets,
                "rep_min": e.repMin,
                "rep_max": e.repMax,
                "start_weight_kg": e.startWeightKg,
                "rest_seconds": e.restSeconds,
                "is_joint_sensitive": e.isJointSensitive,
                "notes": e.notes,
                "muscle_group": e.muscleGroup,
                "source_raw": e.sourceRaw,
                "superset_group": e.supersetGroup as Any,
                "alternatives": e.alternatives,
            ]
        }
        try await upsertJSON(table: "custom_session_exercises", rows: rows)
    }

    private func syncTrainingDayConfigs(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<TrainingDayConfig>())) ?? []
        let rows: [[String: Any]] = logs.map { t in
            [
                "id": t.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": t.profileId?.uuidString as Any,
                "code": t.code,
                "name": t.name,
                "focus": t.focus,
                "color_hex": t.colorHex,
                "weekday": t.weekday,
                "order_index": t.orderIndex,
            ]
        }
        try await upsertJSON(table: "training_day_configs", rows: rows)
    }

    private func syncCustomMealTemplates(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<CustomMealTemplate>())) ?? []
        let rows: [[String: Any]] = logs.map { t in
            [
                "id": t.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": t.profileId?.uuidString as Any,
                "name": t.name,
                "food": t.food,
                "protein": t.protein,
                "calories": t.calories,
                "use_count": t.useCount,
            ]
        }
        try await upsertJSON(table: "custom_meal_templates", rows: rows)
    }

    private func syncAchievements(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<Achievement>())) ?? []
        let rows: [[String: Any]] = logs.map { a in
            [
                "id": a.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": a.profileId?.uuidString as Any,
                "key": a.key,
                "title": a.title,
                "subtitle": a.subtitle,
                "icon": a.icon,
                "color_hex": a.colorHex,
                "category": a.category,
                "earned_at": iso(a.earnedAt),
            ]
        }
        try await upsertJSON(table: "achievements", rows: rows)
    }

    private func syncEnvironmentalReadings(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<EnvironmentalReading>())) ?? []
        let rows: [[String: Any]] = logs.map { e in
            [
                "id": e.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": e.profileId?.uuidString as Any,
                "date": iso(e.date),
                "barometric_pressure_kpa": e.barometricPressureKPa as Any,
                "air_quality_index": e.airQualityIndex as Any,
            ]
        }
        try await upsertJSON(table: "environmental_readings", rows: rows)
    }

    private func syncWellnessInsightRecords(context: ModelContext, userId: UUID) async throws {
        let logs = (try? context.fetch(FetchDescriptor<WellnessInsightRecord>())) ?? []
        let rows: [[String: Any]] = logs.map { w in
            [
                "id": w.id.uuidString,
                "user_id": userId.uuidString,
                "profile_id": w.profileId?.uuidString as Any,
                "date": iso(w.date),
                "kind": w.kind,
            ]
        }
        try await upsertJSON(table: "wellness_insight_records", rows: rows)
    }

    // MARK: - Helpers

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func iso(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }

    /// Upsert rows as raw JSON dictionaries (avoids needing Codable DTOs for every table).
    private func upsertJSON(table: String, rows: [[String: Any]]) async throws {
        guard !rows.isEmpty else { return }

        // Filter out NSNull / nil values from the dictionaries
        let cleaned = rows.map { dict -> [String: Any] in
            dict.compactMapValues { value in
                if value is NSNull { return nil }
                if case Optional<Any>.none = value { return nil }
                return value
            }
        }

        let data = try JSONSerialization.data(withJSONObject: cleaned)
        try await client.upsertRaw(table: table, jsonData: data)
    }
}
