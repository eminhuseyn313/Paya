import Foundation
import SwiftData

// MARK: - Program Density Correction
//
// One-time cleanup for a bug in LostExerciseRepair's earlier logic. That
// migration restored any exercise name that appeared in a day's training
// history 2+ times, on the theory it must have been silently dropped by
// the exercise-disappearing bug it was fixing. In practice, most of what
// it swept back in wasn't the same exercise dropped repeatedly — it was
// every alternate movement the user had ever rotated through for the same
// muscle over months (e.g. Day A ended up with 5 different back-pulling
// exercises and 4 different tricep-pushdown variants that were never all
// done in the same session; they were swapped in and out over time via
// the exercise-swap feature). Real data, verified via direct query before
// writing this: Day A went from 6 exercises to 26, B from 8 to 18, C from
// 4 to 17 — clearly not a realistic single session.
//
// Hard rule, learned the expensive way from a first draft of this file
// that briefly deleted two genuinely user-programmed exercises off a live
// account: this migration may ONLY ever delete a `CustomSessionExercise`
// this app's own code added automatically — tagged by its `notes` prefix
// (LostExerciseRepair's "Restored —" or ProgramGapEngine's "Added to
// close a volume gap —"). Anything else — no matter how many exercises
// are already in the muscle group or the day — is permanent, full stop.
// A day that's honestly over any cap because the user really does train
// 9 muscle groups in one session is left alone; this migration's job is
// undoing ITS OWN over-restoration, never trimming real program data.

enum ProgramDensityCorrection {

    private static let flagKey = "program_density_correction_v1_done"
    private static let maxPerMuscleGroup = 2
    private static let maxPerDay = 8

    private static func isAutoAdded(_ ex: CustomSessionExercise) -> Bool {
        ex.notes.hasPrefix("Restored —") || ex.notes.hasPrefix("Added to close a volume gap —")
    }

    @MainActor
    static func correctIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        UserDefaults.standard.set(true, forKey: flagKey)

        let pid = ActiveProfile.id
        let days = TrainingDayStore.allSnapshots(context: context)
        guard !days.isEmpty else { return }

        var totalRemoved = 0

        for day in days {
            let dayCode = day.code
            guard let custom = CustomSessionStore.fetch(code: dayCode, context: context) else { continue }
            let exercises = custom.exercises
            guard exercises.contains(where: isAutoAdded) else { continue }

            let sessionDescriptor = FetchDescriptor<TrainingSession>(
                predicate: #Predicate<TrainingSession> { $0.sessionType == dayCode && $0.isCompleted == true && $0.profileId == pid }
            )
            let allSessions = (try? context.fetch(sessionDescriptor)) ?? []
            var occurrenceCount: [String: Int] = [:]
            for session in allSessions {
                for log in session.exercises {
                    occurrenceCount[log.exerciseName.lowercased(), default: 0] += 1
                }
            }
            func frequency(_ ex: CustomSessionExercise) -> Int {
                occurrenceCount[ex.exerciseName.lowercased()] ?? 0
            }

            // Group by canonical muscle, not the raw stored string — the same
            // "Back"/"Lats"/"Middle Back" fragmentation VolumeLandmarkEngine
            // had to normalize would otherwise let 3 near-duplicate back
            // exercises each count as their own "muscle group" and dodge the
            // 2-per-muscle cap entirely.
            let byMuscle = Dictionary(grouping: exercises, by: { VolumeLandmarkEngine.canonicalMuscleGroup($0.muscleGroup) })

            var toDelete = Set<PersistentIdentifier>()

            for (_, group) in byMuscle {
                let protectedCount = group.filter { !isAutoAdded($0) }.count
                let autoAdded = group.filter(isAutoAdded).sorted { frequency($0) > frequency($1) }
                let room = max(0, maxPerMuscleGroup - protectedCount)
                for ex in autoAdded.dropFirst(room) { toDelete.insert(ex.persistentModelID) }
            }

            // Day-wide backstop, same rule: only ever trims auto-added
            // survivors, ranked by frequency, never a protected exercise —
            // even if that leaves the day above maxPerDay.
            let protectedTotal = exercises.filter { !isAutoAdded($0) }.count
            let autoAddedSurvivors = exercises.filter { isAutoAdded($0) && !toDelete.contains($0.persistentModelID) }
                .sorted { frequency($0) > frequency($1) }
            let autoAddedRoom = max(0, maxPerDay - protectedTotal)
            for ex in autoAddedSurvivors.dropFirst(autoAddedRoom) { toDelete.insert(ex.persistentModelID) }

            guard !toDelete.isEmpty else { continue }

            for ex in exercises where toDelete.contains(ex.persistentModelID) {
                context.delete(ex)
                totalRemoved += 1
            }

            // Re-pack order indices so the surviving exercises render in a
            // clean 0..n sequence rather than the gappy indices left behind.
            let survivors = exercises.filter { !toDelete.contains($0.persistentModelID) }
                .sorted { $0.orderIndex < $1.orderIndex }
            for (index, ex) in survivors.enumerated() {
                ex.orderIndex = index
            }
        }

        if totalRemoved > 0 {
            try? context.save()
        }
    }
}
