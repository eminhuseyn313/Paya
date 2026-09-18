import Foundation
import SwiftData

// MARK: - Program Gap Engine
//
// Compares the user's actual weekly program against Renaissance
// Periodization's published hypertrophy volume landmarks (Israetel et
// al.: MEV/MAV/MRV — the same framework VolumeLandmarkEngine already
// computes elsewhere in this app, see that file's header for full
// citation) and, for any muscle group under its Minimum Adaptive Volume
// floor, recommends ONE specific exercise and the specific session day to
// add it to — not just "your hamstrings are low," but "add Romanian
// Deadlift to Day B."
//
// Recommendation selection deliberately reuses the app's existing
// safety/personalization machinery rather than a fresh ad-hoc filter:
//   - PersonalizationEngine.isRisky(_:for:) — the same injury-keyword
//     filter ProgramAssembler uses when building a program from scratch.
//   - Equipment fit — the same fitsEquipment logic ProgramAssembler's
//     `pick` uses, inlined here since that function is private to its file.
//   - Experience level — ExercisePool entries below the user's level are
//     never suggested (same gate ExercisePool.candidates already applies).
//
// Realism, per explicit product direction: this suggests adding ONE
// exercise per gap, to the day that already trains that muscle group most
// (keeps the session's character intact) or has the fewest exercises
// (most room) if no day currently touches it — not a program rewrite. A
// user training 3 days/week doesn't get a recommendation implying they
// should train 5.

enum ProgramGapEngine {

    struct Gap: Identifiable {
        var id: String { muscleGroup }
        let muscleGroup: String
        let currentSets: Int
        let targetSets: Int          // MAV-low — the "growing zone" floor
        let recommendedExercise: PoolExercise
        let targetDayCode: String
        let targetDayName: String
        let reason: String
    }

    private static let trackedMuscles = [
        "Chest", "Back", "Quads", "Hamstrings", "Glutes",
        "Shoulders", "Rear Delts", "Biceps", "Triceps", "Calves", "Core",
    ]

    @MainActor
    static func analyze(context: ModelContext, profile: PersonProfile) -> [Gap] {
        let pid = ActiveProfile.id
        let sessionDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid && $0.isCompleted == true }
        )
        let sessions = (try? context.fetch(sessionDescriptor)) ?? []
        let volumes = VolumeLandmarkEngine.weeklyVolume(sessions: sessions)
        let volumeByMuscle = Dictionary(uniqueKeysWithValues: volumes.map { ($0.muscleGroup, $0.sets) })

        let days = TrainingDayStore.allSnapshots(context: context)
        guard !days.isEmpty else { return [] }

        // Per-day exercise lists and muscle-group tallies, computed once —
        // used both to pick the best-fit target day and to avoid
        // recommending an exercise the user is already doing anywhere.
        var dayExercises: [String: [CustomSessionExercise]] = [:]
        var allExerciseNamesInUse = Set<String>()
        for day in days {
            let exercises = CustomSessionStore.fetch(code: day.code, context: context)?.exercises ?? []
            dayExercises[day.code] = exercises
            for ex in exercises { allExerciseNamesInUse.insert(ex.exerciseName.lowercased()) }
        }

        let injuries = profile.injuryFlags
        let level = profile.experienceLevel
        let equipment = profile.equipmentAccess

        var gaps: [Gap] = []

        for muscle in trackedMuscles {
            guard let landmark = VolumeLandmarkEngine.landmarks[muscle] else { continue }
            let current = volumeByMuscle[muscle] ?? 0
            guard current < landmark.mavLow else { continue } // already in or past the growing zone

            guard let exercise = bestExercise(
                for: muscle, level: level, equipment: equipment,
                injuries: injuries, excluding: allExerciseNamesInUse
            ) else { continue }

            guard let targetDay = bestTargetDay(for: muscle, days: days, dayExercises: dayExercises) else { continue }

            let reason: String
            if current == 0 {
                reason = "\(muscle) isn't in your program at all right now. RP's hypertrophy guidance puts the minimum useful weekly volume around \(landmark.mev) sets."
            } else {
                reason = "\(muscle): \(current) sets/week, below the \(landmark.mavLow)–\(landmark.mavHigh) range RP's hypertrophy guidance associates with the best growth rate."
            }

            gaps.append(Gap(
                muscleGroup: muscle,
                currentSets: current,
                targetSets: landmark.mavLow,
                recommendedExercise: exercise,
                targetDayCode: targetDay.code,
                targetDayName: targetDay.name,
                reason: reason
            ))
        }

        return gaps
    }

    /// Gaps relevant to one specific day — what PulseTrainView shows.
    /// Ordered worst-first (muscle entirely absent, then largest deficit)
    /// so the single gap shown by default is the one most worth acting on.
    @MainActor
    static func gaps(for dayCode: String, context: ModelContext, profile: PersonProfile) -> [Gap] {
        analyze(context: context, profile: profile)
            .filter { $0.targetDayCode == dayCode }
            .sorted { ($0.currentSets, $0.currentSets - $0.targetSets) < ($1.currentSets, $1.currentSets - $1.targetSets) }
    }

    // MARK: - Exercise selection

    private static func bestExercise(
        for muscleGroup: String,
        level: ExperienceLevel,
        equipment: EquipmentAccess,
        injuries: Set<InjuryArea>,
        excluding usedNames: Set<String>
    ) -> PoolExercise? {
        func levelRank(_ l: ExperienceLevel) -> Int {
            switch l { case .beginner: return 0; case .intermediate: return 1; case .advanced: return 2 }
        }
        func fitsEquipment(_ ex: PoolExercise) -> Bool {
            switch equipment {
            case .fullGym: return true
            case .homeDumbbells: return ex.equipmentTag.worksWithDumbbellsAtHome
            case .bodyweightOnly: return ex.equipmentTag.worksBodyweightOnly
            }
        }

        let candidates = ExercisePool.all.filter {
            $0.muscleGroup == muscleGroup
                && levelRank($0.minLevel) <= levelRank(level)
                && !usedNames.contains($0.name.lowercased())
        }
        guard !candidates.isEmpty else { return nil }

        // Health first: never suggest something flagged for the user's own
        // injury areas if a safe alternative exists for this muscle.
        let safe = candidates.filter { !PersonalizationEngine.isRisky($0.name, for: injuries) }
        let pool = safe.isEmpty ? candidates : safe

        // Then equipment fit — hard filter when possible, same as
        // ProgramAssembler's own selection logic.
        let fitting = pool.filter(fitsEquipment)
        let finalPool = fitting.isEmpty ? pool : fitting

        // Prefer the most advanced appropriate variant (same tie-break
        // ProgramAssembler uses) so the suggestion doesn't default to the
        // most beginner-friendly option for an advanced lifter.
        return finalPool.max { levelRank($0.minLevel) < levelRank($1.minLevel) }
    }

    // MARK: - Target day selection

    private static func bestTargetDay(
        for muscleGroup: String,
        days: [DaySnapshot],
        dayExercises: [String: [CustomSessionExercise]]
    ) -> DaySnapshot? {
        guard !days.isEmpty else { return nil }

        // `.max`/`.min` resolve ties by keeping whichever candidate they
        // saw first — harmless when day sizes actually differ, but since
        // ProgramDensityCorrection now caps every day to the same 8-exercise
        // ceiling, every "no day touches this muscle" gap tied on exercise
        // COUNT and silently collapsed onto whichever day happens to be
        // first in `days` (Day A) every single time. A hash-based tiebreak
        // was tried first and still wasn't good enough — it's not
        // explainable ("why did this land on Day B?" has no real answer)
        // and gave no actual guarantee of spreading gaps out. Total
        // prescribed SETS for the day is a real, already-varying signal
        // (real data checked before writing this: 29/27/28 across the 3
        // days despite all being capped to 8 exercises each) and means
        // something concrete: the day with fewer total sets has more
        // actual room, which is the same reasoning the exercise-count
        // check was already going for.
        func totalSets(_ day: DaySnapshot) -> Int {
            dayExercises[day.code]?.reduce(0) { $0 + $1.sets } ?? 0
        }
        func pickAmongTies(_ candidates: [DaySnapshot]) -> DaySnapshot {
            candidates.min { totalSets($0) < totalSets($1) } ?? candidates[0]
        }

        // Prefer the day that already trains this muscle group the most —
        // adding one more exercise there keeps the day's character intact
        // rather than bolting an unrelated movement onto an unrelated day.
        let withMuscle = days.map { day -> (DaySnapshot, Int) in
            (day, dayExercises[day.code]?.filter { $0.muscleGroup == muscleGroup }.count ?? 0)
        }.filter { $0.1 > 0 }
        if let maxCount = withMuscle.map(\.1).max() {
            return pickAmongTies(withMuscle.filter { $0.1 == maxCount }.map(\.0))
        }
        // No day currently touches this muscle at all — every day is a
        // candidate, resolved straight to the one with the fewest total
        // sets (the most realistic room for one more without turning a
        // short session into a long one).
        return pickAmongTies(days)
    }

    // MARK: - Add to program

    /// Adds the recommended exercise to its target day's saved program —
    /// same insert pattern used by SessionComposerView's own "add from
    /// library" and LostExerciseRepair, so it behaves identically to
    /// adding it by hand.
    @MainActor
    static func addToProgram(_ gap: Gap, context: ModelContext) {
        guard let custom = CustomSessionStore.fetch(code: gap.targetDayCode, context: context)
            ?? Optional(CustomSessionStore.createSeeded(code: gap.targetDayCode, context: context)) else { return }
        let nextIndex = (custom.exercises.map(\.orderIndex).max() ?? -1) + 1
        let ex = gap.recommendedExercise
        let cse = CustomSessionExercise(
            exerciseId: "pool_\(ex.name.lowercased().replacingOccurrences(of: " ", with: "_"))",
            exerciseName: ex.name,
            orderIndex: nextIndex,
            sets: 3,
            repMin: 12,
            repMax: 12,
            startWeightKg: ex.startWeightKg > 0 ? ex.startWeightKg : 20,
            restSeconds: ex.jointSensitive ? 120 : 90,
            isJointSensitive: ex.jointSensitive,
            notes: "Added to close a volume gap — \(gap.muscleGroup)",
            muscleGroup: gap.muscleGroup,
            sourceRaw: CustomSessionExercise.Source.library.rawValue
        )
        context.insert(cse)
        cse.session = custom
        try? context.save()
    }
}
