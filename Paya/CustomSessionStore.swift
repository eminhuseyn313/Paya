import Foundation
import SwiftData

enum CustomSessionStore {

    static func fetch(code: String, context: ModelContext) -> CustomSession? {
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<CustomSession>(
            predicate: #Predicate { $0.sessionTypeRaw == code && $0.profileId == pid }
        )
        return try? context.fetch(descriptor).first
    }

    static func effectiveExercises(
        forCode code: String,
        context: ModelContext
    ) -> [ExerciseDefinition] {
        if let custom = fetch(code: code, context: context),
           !custom.exercises.isEmpty {
            return custom.sortedExercises.map { $0.toExerciseDefinition() }
        }
        if let orphan = fetch(code: code, context: context),
           orphan.exercises.isEmpty {
            context.delete(orphan)
            try? context.save()
        }
        if let builtIn = SessionType(rawValue: code) {
            return ProgramData.exercises(for: builtIn)
        }
        return []
    }

    @discardableResult
    static func createSeeded(code: String, context: ModelContext) -> CustomSession {
        let custom = CustomSession(sessionTypeRaw: code)
        custom.profileId = ActiveProfile.id
        context.insert(custom)

        if let builtIn = SessionType(rawValue: code) {
            let defaults = ProgramData.exercises(for: builtIn)
            for (index, ex) in defaults.enumerated() {
                let cse = CustomSessionExercise(
                    exerciseId: ex.id,
                    exerciseName: ex.name,
                    orderIndex: index,
                    sets: ex.sets,
                    repMin: ex.repRange.min,
                    repMax: ex.repRange.max,
                    startWeightKg: ex.startWeightKg,
                    restSeconds: ex.isJointSensitive ? 120 : 90,
                    isJointSensitive: ex.isJointSensitive,
                    notes: ex.specialProgressionRule ?? "",
                    muscleGroup: ex.muscleGroup,
                    sourceRaw: CustomSessionExercise.Source.program.rawValue
                )
                context.insert(cse)
                cse.session = custom
            }
        }
        try? context.save()
        return custom
    }

    static func resetToDefault(code: String, context: ModelContext) {
        if let existing = fetch(code: code, context: context) {
            context.delete(existing)
            try? context.save()
        }
    }

    /// Returns all exercises across all training days — used by the
    /// Smart Program Engine to analyze the full program.
    static func allExercisesAcrossDays(context: ModelContext) -> [ExerciseDefinition] {
        let dayCodes = TrainingDayStore.allSnapshots(context: context).map(\.code)
        var seen = Set<String>()
        var result: [ExerciseDefinition] = []
        for code in dayCodes {
            for exercise in effectiveExercises(forCode: code, context: context) {
                if seen.insert(exercise.name).inserted {
                    result.append(exercise)
                }
            }
        }
        return result
    }

    /// One-time adoption of pre-Phase-2 records.
    @MainActor
    static func adoptOrphans(to pid: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<CustomSession>(
            predicate: #Predicate { $0.profileId == nil }
        )
        for session in (try? context.fetch(descriptor)) ?? [] {
            session.profileId = pid
        }
    }
}
