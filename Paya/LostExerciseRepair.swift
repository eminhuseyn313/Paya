import Foundation
import SwiftData

// MARK: - Lost Exercise Repair
//
// One-time data repair, not a new feature. Root cause: PulseTrainView's
// "add exercise" call site was missing the `context:` parameter that
// addExerciseForToday's entire database-persist step is gated on — every
// exercise added mid-session from the actual live UI only ever existed in
// memory for that session. It correctly saved into that session's own
// history (completeSession reads live state, unaffected), but never made
// it back into the day's CustomSessionExercise program template. So every
// NEW session for that day started over from whatever smaller template
// was originally seeded, the user re-added exercises they'd already added
// before, and THOSE re-additions were lost too — repeating, unnoticed,
// for as long as that bug existed. Confirmed across all 3 training days
// (A: 6 saved vs 16 recently trained, B: 8 vs 17, C: 4 vs 16).
//
// The call-site bug is fixed (see PulseTrainView.swift), so this stops
// happening going forward. It does NOT retroactively repair a day's
// template that's already stuck small — this migration does that, once.
//
// Scope, per the user's explicit direction:
//   1. Scan FULL history (not just recent sessions).
//   2. Restore any exercise performed 2+ times for that day — repeated use
//      is real signal this was a genuine part of the program, not a
//      one-off swap/experiment that shouldn't come back.
//   3. Order the WHOLE resulting day (existing template exercises AND
//      restored ones together) by how often each was actually performed,
//      most-frequent first — the same "front-load what you prioritize"
//      logic TrainViewModel.loadRecentCompletionOrder already applies
//      elsewhere (Simão et al. 2012: exercise order affects volume/RPE,
//      athletes intuitively front-load movements they prioritize),
//      applied here to fix the template's stored order itself rather than
//      only a live display-time reordering.

enum LostExerciseRepair {

    private static let flagKey = "lost_exercise_repair_v3_frequency_ordered_done"

    @MainActor
    static func repairIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        UserDefaults.standard.set(true, forKey: flagKey) // set first — never retry-loop on a save failure

        let pid = ActiveProfile.id
        let days = TrainingDayStore.allSnapshots(context: context)
        guard !days.isEmpty else { return }

        var totalRestored = 0
        var totalReordered = 0

        for day in days {
            let dayCode = day.code
            guard let custom = CustomSessionStore.fetch(code: dayCode, context: context) else { continue }

            let sessionDescriptor = FetchDescriptor<TrainingSession>(
                predicate: #Predicate<TrainingSession> { $0.sessionType == dayCode && $0.isCompleted == true && $0.profileId == pid },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let allSessions = (try? context.fetch(sessionDescriptor)) ?? []
            guard !allSessions.isEmpty else { continue }

            var occurrenceCount: [String: Int] = [:]      // lowercased name -> times performed
            var mostRecentLog: [String: ExerciseLog] = [:] // lowercased name -> most recent log (newest-first walk)
            var mostRecentDate: [String: Date] = [:]       // lowercased name -> that log's session date

            for session in allSessions {
                for log in session.exercises {
                    let key = log.exerciseName.lowercased()
                    occurrenceCount[key, default: 0] += 1
                    if mostRecentLog[key] == nil {
                        mostRecentLog[key] = log
                        mostRecentDate[key] = session.date
                    }
                }
            }

            let alreadyInTemplate = Set(custom.exercises.map { $0.exerciseName.lowercased() })

            // Restore anything performed 2+ times that isn't already saved.
            let toRestore = occurrenceCount
                .filter { $0.value >= 2 && !alreadyInTemplate.contains($0.key) }
                .keys

            for key in toRestore {
                guard let log = mostRecentLog[key] else { continue }
                let completedSets = log.sets.filter(\.isCompleted)
                let lastWeight = completedSets.map(\.weightKg).max() ?? 20

                let cse = CustomSessionExercise(
                    exerciseId: log.exerciseId,
                    exerciseName: log.exerciseName,
                    orderIndex: 0, // reassigned below, for the whole day
                    sets: max(1, completedSets.count),
                    // Flat 12-rep target — established policy, not the
                    // exercise's own historical rep count (see
                    // TrainViewModel.defaultReps and the normalization in
                    // ContentView.swift).
                    repMin: 12,
                    repMax: 12,
                    startWeightKg: lastWeight,
                    restSeconds: 90,
                    isJointSensitive: false,
                    notes: "Restored — was being lost each session due to a since-fixed bug",
                    muscleGroup: log.muscleGroup,
                    sourceRaw: CustomSessionExercise.Source.library.rawValue
                )
                context.insert(cse)
                cse.session = custom
                totalRestored += 1
            }

            // Reorder the WHOLE day — existing template exercises AND the
            // ones just restored — by how often each was actually
            // performed, most-frequent first. Ties (several exercises
            // often land on the same count) break by which was done more
            // recently, so the order is fully determined by real history
            // rather than falling back to an arbitrary insertion order for
            // exercises just restored in this same pass. An exercise never
            // seen in history at all (a program exercise not yet gotten to)
            // sorts last, keeping its relative order via the original
            // orderIndex as the final tiebreak.
            let ranked = custom.exercises.sorted { a, b in
                let keyA = a.exerciseName.lowercased()
                let keyB = b.exerciseName.lowercased()
                let countA = occurrenceCount[keyA] ?? 0
                let countB = occurrenceCount[keyB] ?? 0
                if countA != countB { return countA > countB }
                let dateA = mostRecentDate[keyA]
                let dateB = mostRecentDate[keyB]
                if let dateA, let dateB, dateA != dateB { return dateA > dateB }
                return a.orderIndex < b.orderIndex
            }
            for (index, exercise) in ranked.enumerated() {
                exercise.orderIndex = index
            }
            totalReordered += ranked.count
        }

        if totalRestored > 0 || totalReordered > 0 {
            try? context.save()
        }
    }
}
