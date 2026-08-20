import Foundation
import SwiftData

// MARK: - Yesterday's Workout Seeder
// One-time data entry for the user's workout on 2026-08-19.
// Call `YesterdayWorkoutSeeder.seed(context:)` once, then delete this file.

enum YesterdayWorkoutSeeder {

    static let seedKey = "didSeedYesterdayWorkout_20260819"

    static func seedIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seedKey) else { return }
        seed(context: context)
        UserDefaults.standard.set(true, forKey: seedKey)
    }

    static func seed(context: ModelContext) {
        // Yesterday = 2026-08-19 at noon
        let cal = Calendar.current
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: .now)) else { return }
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: yesterday) ?? yesterday

        let session = TrainingSession(
            sessionType: "Manual",
            date: noon,
            durationMinutes: 75,
            isCompleted: true,
            notes: ""
        )
        session.sourceRaw = "manual"
        context.insert(session)

        // Exercise data: (name, muscleGroup, note, sets: [(weightKg, reps)])
        let exercises: [(String, String, String, [(Double, Int)])] = [
            ("Machine Chest Press", "Chest", "",
             [(15, 10), (30, 10), (35, 10)]),

            ("Lat Pulldown", "Back", "Wide grip",
             [(40, 10), (45, 10), (50, 10)]),

            ("Seated Cable Row", "Back", "",
             [(35, 12), (37.5, 12), (40, 12)]),

            ("Cable Upright Row", "Shoulders", "V-handle attachment",
             [(20, 12), (25, 12), (30, 12)]),

            ("Cable Curl", "Biceps", "V-holder attachment",
             [(25, 12), (30, 12), (35, 12)]),

            ("Hammer Curl", "Biceps", "One-hand cable, 4-exercise machine used, 12 reps each arm",
             [(10, 12), (15, 12), (15, 12)]),

            ("Rope Pushdown", "Triceps", "V-holder, 4-exercise machine used",
             [(40, 10), (45, 10), (50, 10)]),

            ("Goblet Squat", "Quads", "",
             [(20, 12), (22.5, 12), (25, 12)])
        ]

        for (orderIdx, (name, muscle, note, sets)) in exercises.enumerated() {
            let exerciseLog = ExerciseLog(
                exerciseId: name.lowercased().replacingOccurrences(of: " ", with: "_"),
                exerciseName: name,
                orderIndex: orderIdx,
                muscleGroup: muscle
            )
            exerciseLog.note = note
            context.insert(exerciseLog)
            exerciseLog.session = session

            for (setIdx, (weight, reps)) in sets.enumerated() {
                let setLog = SetLog(
                    setNumber: setIdx + 1,
                    weightKg: weight,
                    reps: reps,
                    isCompleted: true,
                    rpe: 0
                )
                context.insert(setLog)
                setLog.exercise = exerciseLog
            }
        }

        try? context.save()
    }
}
