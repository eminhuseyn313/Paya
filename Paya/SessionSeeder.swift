import Foundation
import SwiftData

// MARK: - Session Seeder
//
// Seeds historical training data that the user has already performed
// outside the app. Each seed block checks a UserDefaults key so it
// only runs once per device.

enum SessionSeeder {

    /// Seeds the user's Monday August 10, 2026 workout (Session A).
    /// All 9 exercises completed with ascending pyramid weights.
    @MainActor
    static func seedAugust10Monday(context: ModelContext) {
        let key = "seeded_session_2026_08_10"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let pid = ActiveProfile.id

        // August 10, 2026 at ~10:00 AM
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 10
        components.hour = 10
        components.minute = 0
        guard let sessionDate = Calendar.current.date(from: components) else { return }

        let session = TrainingSession(
            sessionType: "A",
            date: sessionDate,
            durationMinutes: 75,
            isCompleted: true,
            notes: "Monday push/pull/legs + arms — full session completed",
            isFlareDay: false
        )
        session.profileId = pid
        context.insert(session)

        // Exercise data: (id, name, muscleGroup, sets as [(weightKg, reps)])
        let exercises: [(String, String, String, [(Double, Int)])] = [
            ("mon_a1_incline_machine_press", "Incline Machine Bench Press", "Chest · Front Delt",
             [(44, 10), (49, 10), (54, 8)]),

            ("mon_a2_lat_pulldown_wide", "Lat Pull-Down — Wide Grip", "Lats · Mid Back",
             [(40, 10), (45, 10), (50, 8)]),

            ("mon_a3_seated_cable_row_single", "Seated Cable Row — Single Arm", "Mid Back · Lats",
             [(30, 10), (40, 10), (40, 8)]),

            ("mon_a4_incline_shoulder_press", "Incline Shoulder Press — Machine", "Shoulders · Front Delt",
             [(50, 10), (55, 8)]),

            ("mon_a5_cable_lateral_raise", "Cable Front-to-Lateral Raise", "Side Delt",
             [(15, 12), (20, 12), (25, 10)]),

            ("mon_a6_goblet_squat", "Goblet Squat", "Quads · Glutes",
             [(20, 10), (22.5, 10), (25, 8)]),

            ("mon_a7_overhead_tricep_rope", "Overhead Tricep Extension — Rope", "Triceps",
             [(12.5, 12), (15, 12), (17.5, 10)]),

            ("mon_a8_single_arm_pushdown", "Single-Arm Cable Pushdown", "Triceps",
             [(7.5, 12), (10, 12), (10, 10)]),

            ("mon_a9_hammer_curl", "Hammer Curl", "Biceps · Brachialis",
             [(10, 10), (12.5, 10), (15, 10)])   // last set capped at 10 reps
        ]

        for (orderIndex, exercise) in exercises.enumerated() {
            let exerciseLog = ExerciseLog(
                exerciseId: exercise.0,
                exerciseName: exercise.1,
                orderIndex: orderIndex,
                muscleGroup: exercise.2
            )
            context.insert(exerciseLog)
            exerciseLog.session = session

            for (setIndex, setData) in exercise.3.enumerated() {
                let setLog = SetLog(
                    setNumber: setIndex + 1,
                    weightKg: setData.0,
                    reps: setData.1,
                    isCompleted: true,
                    rpe: 7  // reasonable default RPE
                )
                context.insert(setLog)
                setLog.exercise = exerciseLog
            }
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }
}
