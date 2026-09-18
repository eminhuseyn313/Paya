import Foundation
import SwiftData

// MARK: - Pending Exercise Addition (Machine Lateral Raise, Session C)
//
// User asked to add "Machine Lateral Raise" — added to the exercise
// library catalog, but never actually to Session C's program nor logged
// as today's real session, because I asked which day/date it belonged to
// and moved on without an answer. User then reported it missing from
// both history and Session C. Root cause, confirmed before writing this:
// CustomSessionExercise/TrainingSession sync is one-directional
// (device → Supabase, upsert-only, no pull path — see
// SyncManager.syncCustomSessionExercises) so there was never a way to
// make this appear on-device except through app code that runs there,
// same as every other one-time migration this session.

enum PendingExerciseAddition {

    private static let flagKey = "pending_exercise_addition_machine_lateral_raise_v1_done"

    @MainActor
    static func applyIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        UserDefaults.standard.set(true, forKey: flagKey)

        let dayCode = "C"
        let exerciseName = "Machine Lateral Raise"
        let muscleGroup = "Side Delts"

        // 1. Add to Session C's program, if not already there.
        let custom = CustomSessionStore.fetch(code: dayCode, context: context)
            ?? CustomSessionStore.createSeeded(code: dayCode, context: context)
        if !custom.exercises.contains(where: { $0.exerciseName.lowercased() == exerciseName.lowercased() }) {
            let nextIndex = (custom.exercises.map(\.orderIndex).max() ?? -1) + 1
            let cse = CustomSessionExercise(
                exerciseId: "pool_machine_lateral_raise",
                exerciseName: exerciseName,
                orderIndex: nextIndex,
                sets: 3,
                repMin: 12,
                repMax: 12,
                startWeightKg: 20,
                restSeconds: 90,
                isJointSensitive: true,
                notes: "",
                muscleGroup: muscleGroup,
                sourceRaw: CustomSessionExercise.Source.library.rawValue
            )
            context.insert(cse)
            cse.session = custom
        }

        // 2. Log the session the user actually did — 15×12, 20×12, 20×12 —
        // dated today (2026-09-04, the date this was reported), not
        // whenever this migration happens to run.
        let pid = ActiveProfile.id
        var comps = DateComponents()
        comps.year = 2026; comps.month = 9; comps.day = 4; comps.hour = 12
        let sessionDate = Calendar.current.date(from: comps) ?? Date()

        let session = TrainingSession(
            sessionType: dayCode,
            date: sessionDate,
            durationMinutes: 0,
            isCompleted: true,
            notes: "Logged retroactively — reported to Paya, not entered live in the app"
        )
        session.profileId = pid
        session.sourceRaw = "manual"
        context.insert(session)

        let exerciseLog = ExerciseLog(
            exerciseId: "pool_machine_lateral_raise",
            exerciseName: exerciseName,
            orderIndex: 0,
            muscleGroup: muscleGroup
        )
        context.insert(exerciseLog)
        exerciseLog.session = session

        let sets: [(Double, Int)] = [(15, 12), (20, 12), (20, 12)]
        for (index, set) in sets.enumerated() {
            let setLog = SetLog(
                setNumber: index + 1,
                weightKg: set.0,
                reps: set.1,
                isCompleted: true,
                rpe: 0
            )
            context.insert(setLog)
            setLog.exercise = exerciseLog
        }

        try? context.save()
    }
}
