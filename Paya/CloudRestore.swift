import Foundation
import SwiftData

// MARK: - Cloud Restore (pull)
// Inverse of SyncManager's push. Column names / date format / FK ids mirror the
// push row dictionaries exactly. Never overwrites: rows whose `id` already
// exists locally are skipped. Every table is attempted independently so one
// failure leaves the rest (and all local data) untouched.

@MainActor
enum CloudRestore {

    struct Result {
        var profiles = 0
        var inserted = 0
        var failedTables: [String] = []
        var restoredProfile: PersonProfile?
    }

    private static let pageSize = 1000

    // MARK: Entry points

    /// Fresh-install restore: runs only when signed in AND no local PersonProfile exists.
    @discardableResult
    static func restoreIfNeeded(context: ModelContext) async -> Result {
        let client = SupabaseClient.shared
        guard client.isSignedIn, client.userId != nil else { return Result() }
        let localProfiles = (try? context.fetchCount(FetchDescriptor<PersonProfile>())) ?? 0
        guard localProfiles == 0 else { return Result() }
        return await restore(context: context)
    }

    /// Merge restore (Settings button): inserts only ids missing locally.
    @discardableResult
    static func restore(context: ModelContext) async -> Result {
        var result = Result()
        let client = SupabaseClient.shared
        guard client.isSignedIn, let uid = client.userId else { return result }
        let hadActive = ActiveProfile.id

        func run<T: PersistentModel>(_ table: String, _ type: T.Type, _ id: KeyPath<T, UUID>,
                                     make: (Row) -> T?) async -> [UUID: T] {
            do {
                let (map, n) = try await restoreTable(table: table, userId: uid, context: context, id: id, make: make)
                result.inserted += n
                if table == "profiles" { result.profiles = n }
                return map
            } catch {
                result.failedTables.append(table)
                return existing(type, id, context)
            }
        }

        // Profiles
        let profiles = await run("profiles", PersonProfile.self, \.id) { r in
            guard let name = r.str("name") else { return nil }
            let p = PersonProfile(name: name)
            if let v = r.uuid("id") { p.id = v }
            p.birthYear = r.int("birth_year")
            if let v = r.int("age") { p.age = v }
            if let v = r.str("sex_raw") { p.sexRaw = v }
            if let v = r.double("height_cm") { p.heightCm = v }
            if let v = r.double("current_weight_kg") { p.currentWeightKg = v }
            if let v = r.double("body_weight_goal_kg") { p.bodyWeightGoalKg = v }
            if let v = r.str("goal_raw") { p.goalRaw = v }
            if let v = r.double("protein_target_g") { p.proteinTargetG = v }
            if let v = r.double("training_day_calories") { p.trainingDayCalories = v }
            if let v = r.double("rest_day_calories") { p.restDayCalories = v }
            if let v = r.bool("has_inflammatory_condition") { p.hasInflammatoryCondition = v }
            if let v = r.str("chronic_condition_raw") { p.chronicConditionRaw = v }
            if let v = r.str("color_hex") { p.colorHex = v }
            if let v = r.str("experience_level_raw") { p.experienceLevelRaw = v }
            if let v = r.str("equipment_access_raw") { p.equipmentAccessRaw = v }
            if let v = r.strArray("injury_flags_raw") { p.injuryFlagsRaw = v }
            if let v = r.int("preferred_training_days_per_week") { p.preferredTrainingDaysPerWeek = v }
            if let v = r.str("diet_preference_raw") { p.dietPreferenceRaw = v }
            if let v = r.str("priority_muscle_raw") { p.priorityMuscleRaw = v }
            return p
        }

        // Training
        let sessions = await run("training_sessions", TrainingSession.self, \.id) { r in
            guard let sType = r.str("session_type") else { return nil }
            let s = TrainingSession(sessionType: sType)
            if let v = r.uuid("id") { s.id = v }
            s.profileId = r.uuid("profile_id")
            if let v = r.date("date") { s.date = v }
            if let v = r.int("duration_minutes") { s.durationMinutes = v }
            if let v = r.bool("is_completed") { s.isCompleted = v }
            if let v = r.str("notes") { s.notes = v }
            if let v = r.bool("is_flare_day") { s.isFlareDay = v }
            if let v = r.str("source_raw") { s.sourceRaw = v }
            s.externalWorkoutId = r.str("external_workout_id")
            s.hrSamples = r.intArray("hr_samples")
            if let v = r.int("hr_sample_interval_seconds") { s.hrSampleIntervalSeconds = v }
            s.sessionPeakHR = r.int("session_peak_hr")
            s.sessionAvgHR = r.int("session_avg_hr")
            s.sessionTrimpScore = r.double("session_trimp_score")
            s.hrRecovery60 = r.int("hr_recovery_60")
            s.subjectiveRPE = r.int("subjective_rpe")
            s.energyAfter = r.int("energy_after")
            if let v = r.strArray("reflection_tags") { s.reflectionTags = v }
            s.reflectionNotes = r.str("reflection_notes")
            s.reflectedAt = r.date("reflected_at")
            return s
        }

        let exercises = await run("exercise_logs", ExerciseLog.self, \.id) { r in
            guard let sid = r.uuid("session_id"), let parent = sessions[sid] else { return nil }
            let e = ExerciseLog(exerciseId: r.str("exercise_id") ?? "", exerciseName: r.str("exercise_name") ?? "")
            if let v = r.uuid("id") { e.id = v }
            if let v = r.bool("is_personal_best") { e.isPersonalBest = v }
            if let v = r.int("order_index") { e.orderIndex = v }
            if let v = r.str("muscle_group") { e.muscleGroup = v }
            if let v = r.str("note") { e.note = v }
            e.session = parent
            return e
        }

        _ = await run("set_logs", SetLog.self, \.id) { r in
            guard let eid = r.uuid("exercise_log_id"), let parent = exercises[eid] else { return nil }
            let s = SetLog(setNumber: r.int("set_number") ?? 0,
                           weightKg: r.double("weight_kg") ?? 0,
                           reps: r.int("reps") ?? 0)
            if let v = r.uuid("id") { s.id = v }
            if let v = r.bool("is_completed") { s.isCompleted = v }
            if let v = r.int("rpe") { s.rpe = v }
            s.peakHR = r.int("peak_hr")
            s.avgHR = r.int("avg_hr")
            s.endHR = r.int("end_hr")
            s.exercise = parent
            return s
        }

        // Templates & config
        let customSessions = await run("custom_sessions", CustomSession.self, \.id) { r in
            guard let code = r.str("session_type_raw") else { return nil }
            let c = CustomSession(sessionTypeRaw: code)
            if let v = r.uuid("id") { c.id = v }
            c.profileId = r.uuid("profile_id")
            if let v = r.date("last_edited_at") { c.lastEditedAt = v }
            return c
        }

        _ = await run("custom_session_exercises", CustomSessionExercise.self, \.id) { r in
            guard let sid = r.uuid("session_id"), let parent = customSessions[sid] else { return nil }
            let e = CustomSessionExercise(exerciseId: r.str("exercise_id") ?? "",
                                          exerciseName: r.str("exercise_name") ?? "",
                                          orderIndex: r.int("order_index") ?? 0)
            if let v = r.uuid("id") { e.id = v }
            if let v = r.int("sets") { e.sets = v }
            if let v = r.int("rep_min") { e.repMin = v }
            if let v = r.int("rep_max") { e.repMax = v }
            if let v = r.double("start_weight_kg") { e.startWeightKg = v }
            if let v = r.int("rest_seconds") { e.restSeconds = v }
            if let v = r.bool("is_joint_sensitive") { e.isJointSensitive = v }
            if let v = r.str("notes") { e.notes = v }
            if let v = r.str("muscle_group") { e.muscleGroup = v }
            if let v = r.str("source_raw") { e.sourceRaw = v }
            e.supersetGroup = r.int("superset_group")
            if let v = r.strArray("alternatives") { e.alternatives = v }
            e.session = parent
            return e
        }

        _ = await run("training_day_configs", TrainingDayConfig.self, \.id) { r in
            let t = TrainingDayConfig(code: r.str("code") ?? "", name: r.str("name") ?? "",
                                      focus: r.str("focus") ?? "", colorHex: r.str("color_hex") ?? "2563EB",
                                      weekday: r.int("weekday") ?? 0, orderIndex: r.int("order_index") ?? 0,
                                      profileId: r.uuid("profile_id"))
            if let v = r.uuid("id") { t.id = v }
            return t
        }

        // Body / health
        _ = await run("body_weight_logs", BodyWeightLog.self, \.id) { r in
            let w = BodyWeightLog(date: r.date("date") ?? .now, weightKg: r.double("weight_kg") ?? 0)
            if let v = r.uuid("id") { w.id = v }
            w.profileId = r.uuid("profile_id")
            return w
        }

        _ = await run("body_measurement_logs", BodyMeasurementLog.self, \.id) { r in
            let b = BodyMeasurementLog(date: r.date("date") ?? .now)
            if let v = r.uuid("id") { b.id = v }
            b.profileId = r.uuid("profile_id")
            b.neckCm = r.double("neck_cm")
            b.chestCm = r.double("chest_cm")
            b.waistCm = r.double("waist_cm")
            b.hipsCm = r.double("hips_cm")
            b.bicepCm = r.double("bicep_cm")
            b.thighCm = r.double("thigh_cm")
            b.calfCm = r.double("calf_cm")
            return b
        }

        _ = await run("health_logs", HealthLog.self, \.id) { r in
            let h = HealthLog(date: r.date("date") ?? .now,
                              isFlareDay: r.bool("is_flare_day") ?? false,
                              jointPainLevel: r.int("joint_pain_level") ?? 0,
                              sleepHours: r.double("sleep_hours") ?? 7,
                              energyLevel: r.int("energy_level") ?? 2,
                              notes: r.str("notes") ?? "",
                              supplementsTaken: r.strArray("supplements_taken") ?? [],
                              waterMl: r.int("water_ml") ?? 0)
            if let v = r.uuid("id") { h.id = v }
            h.profileId = r.uuid("profile_id")
            return h
        }

        // Nutrition
        let nutrition = await run("nutrition_logs", NutritionLog.self, \.id) { r in
            let n = NutritionLog(date: r.date("date") ?? .now,
                                 isTrainingDay: r.bool("is_training_day") ?? false,
                                 proteinTarget: r.double("protein_target") ?? 170,
                                 calorieTarget: r.double("calorie_target"))
            if let v = r.uuid("id") { n.id = v }
            n.profileId = r.uuid("profile_id")
            if let v = r.double("total_protein") { n.totalProtein = v }
            if let v = r.double("total_calories") { n.totalCalories = v }
            return n
        }

        _ = await run("meal_logs", MealLog.self, \.id) { r in
            guard let nid = r.uuid("nutrition_log_id"), let parent = nutrition[nid] else { return nil }
            let m = MealLog(name: r.str("name") ?? "", food: r.str("food") ?? "",
                            protein: r.double("protein") ?? 0, calories: r.double("calories") ?? 0,
                            loggedAt: r.date("logged_at") ?? .now,
                            fatG: r.double("fat_g") ?? 0, carbsG: r.double("carbs_g") ?? 0,
                            fiberG: r.double("fiber_g") ?? 0, sugarG: r.double("sugar_g") ?? 0,
                            sodiumMg: r.double("sodium_mg") ?? 0, ironMg: r.double("iron_mg") ?? 0,
                            calciumMg: r.double("calcium_mg") ?? 0, magnesiumMg: r.double("magnesium_mg") ?? 0,
                            zincMg: r.double("zinc_mg") ?? 0, vitaminDMcg: r.double("vitamin_d_mcg") ?? 0,
                            potassiumMg: r.double("potassium_mg") ?? 0, vitaminCMg: r.double("vitamin_c_mg") ?? 0)
            if let v = r.uuid("id") { m.id = v }
            m.nutritionLog = parent
            return m
        }

        _ = await run("daily_check_ins", DailyCheckIn.self, \.id) { r in
            let c = DailyCheckIn(date: r.date("date") ?? .now, soreness: r.int("soreness") ?? 1,
                                 energy: r.int("energy") ?? 2, symptomTags: r.strArray("symptom_tags") ?? [])
            if let v = r.uuid("id") { c.id = v }
            c.profileId = r.uuid("profile_id")
            return c
        }

        _ = await run("water_event_logs", WaterEventLog.self, \.id) { r in
            let w = WaterEventLog(date: r.date("date") ?? .now, ml: r.int("ml") ?? 0)
            if let v = r.uuid("id") { w.id = v }
            if let v = r.str("drink_type_raw") { w.drinkTypeRaw = v }
            w.profileId = r.uuid("profile_id")
            return w
        }

        _ = await run("symptom_logs", SymptomLog.self, \.id) { r in
            let s = SymptomLog(tag: r.str("tag") ?? "", onsetDate: r.date("onset_date") ?? .now,
                               severity: r.int("severity") ?? 2, notes: r.str("notes") ?? "")
            if let v = r.uuid("id") { s.id = v }
            if let v = r.date("date") { s.date = v }
            s.profileId = r.uuid("profile_id")
            return s
        }

        // Supplements & meds
        _ = await run("user_supplements", UserSupplement.self, \.id) { r in
            let s = UserSupplement(name: r.str("name") ?? "", dose: r.str("dose") ?? "",
                                   timing: r.str("timing") ?? "", orderIndex: r.int("order_index") ?? 0,
                                   isActive: r.bool("is_active") ?? true,
                                   isAutoSeeded: r.bool("is_auto_seeded") ?? true)
            if let v = r.uuid("id") { s.id = v }
            s.profileId = r.uuid("profile_id")
            return s
        }

        _ = await run("medications", Medication.self, \.id) { r in
            let m = Medication(name: r.str("name") ?? "", dose: r.str("dose") ?? "", frequency: .daily,
                               startDate: r.date("start_date") ?? .now, notes: r.str("notes") ?? "")
            if let v = r.uuid("id") { m.id = v }
            if let v = r.str("frequency_raw") { m.frequencyRaw = v }
            if let v = r.bool("is_active") { m.isActive = v }
            m.profileId = r.uuid("profile_id")
            return m
        }

        _ = await run("medication_dose_logs", MedicationDoseLog.self, \.id) { r in
            guard let mid = r.uuid("medication_id") else { return nil }
            let d = MedicationDoseLog(medicationId: mid, takenAt: r.date("taken_at") ?? .now)
            if let v = r.uuid("id") { d.id = v }
            d.profileId = r.uuid("profile_id")
            return d
        }

        _ = await run("custom_meal_templates", CustomMealTemplate.self, \.id) { r in
            let t = CustomMealTemplate(name: r.str("name") ?? "", food: r.str("food") ?? "",
                                       protein: r.double("protein") ?? 0, calories: r.double("calories") ?? 0,
                                       useCount: r.int("use_count") ?? 0)
            if let v = r.uuid("id") { t.id = v }
            t.profileId = r.uuid("profile_id")
            return t
        }

        // Activate a profile (mirrors ProfileStore.setCurrent / onboarding).
        if hadActive == nil || profiles[hadActive!] == nil,
           let first = profiles.values.sorted(by: { $0.name < $1.name }).first {
            ProfileStore.setCurrent(first)
        }
        if let activeId = ActiveProfile.id { result.restoredProfile = profiles[activeId] }
        if result.profiles > 0 { try? context.save() }
        return result
    }

    // MARK: Generic table restore

    private static func existing<T: PersistentModel>(_ type: T.Type, _ id: KeyPath<T, UUID>,
                                                     _ context: ModelContext) -> [UUID: T] {
        let all = (try? context.fetch(FetchDescriptor<T>())) ?? []
        var map: [UUID: T] = [:]
        for o in all { map[o[keyPath: id]] = o }
        return map
    }

    private static func restoreTable<T: PersistentModel>(
        table: String, userId: UUID, context: ModelContext, id: KeyPath<T, UUID>,
        make: (Row) -> T?
    ) async throws -> ([UUID: T], Int) {
        var map = existing(T.self, id, context)
        var inserted = 0
        var offset = 0
        while true {
            let query = "user_id=eq.\(userId.uuidString)&order=id.asc&limit=\(pageSize)&offset=\(offset)"
            let page = try await SupabaseClient.shared.fetchRaw(table: table, query: query)
            for dict in page {
                let row = Row(dict)
                guard let rid = row.uuid("id"), map[rid] == nil else { continue }
                guard let obj = make(row) else { continue }
                context.insert(obj)
                map[rid] = obj
                inserted += 1
            }
            if page.count < pageSize { break }
            offset += pageSize
        }
        if inserted > 0 { try context.save() }
        return (map, inserted)
    }

    // MARK: Row decoding

    struct Row {
        let d: [String: Any]
        init(_ d: [String: Any]) { self.d = d }

        func str(_ k: String) -> String? { d[k] as? String }
        func uuid(_ k: String) -> UUID? { (d[k] as? String).flatMap(UUID.init(uuidString:)) }
        func int(_ k: String) -> Int? { (d[k] as? NSNumber)?.intValue }
        func double(_ k: String) -> Double? { (d[k] as? NSNumber)?.doubleValue }
        func bool(_ k: String) -> Bool? { (d[k] as? NSNumber)?.boolValue }
        func date(_ k: String) -> Date? { (d[k] as? String).flatMap(CloudRestore.parseDate) }

        func strArray(_ k: String) -> [String]? {
            if let a = d[k] as? [String] { return a }
            if let s = d[k] as? String, let data = s.data(using: .utf8),
               let a = try? JSONSerialization.jsonObject(with: data) as? [String] { return a }
            return nil
        }
        func intArray(_ k: String) -> [Int]? {
            if let a = d[k] as? [NSNumber] { return a.map { $0.intValue } }
            if let s = d[k] as? String, let data = s.data(using: .utf8),
               let a = try? JSONSerialization.jsonObject(with: data) as? [NSNumber] { return a.map { $0.intValue } }
            return nil
        }
    }

    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let isoPlain = ISO8601DateFormatter()
    private static let dayOnly: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    fileprivate static func parseDate(_ s: String) -> Date? {
        isoFrac.date(from: s) ?? isoPlain.date(from: s) ?? dayOnly.date(from: s)
    }
}
