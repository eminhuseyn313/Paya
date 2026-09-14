import Foundation

// MARK: - Muscle Activation Engine
//
// Rolls SessionIntensityEngine's per-exercise %HRmax up to per-MUSCLE-GROUP
// intensity — the same underlying heart-rate data, aggregated differently
// so it can be painted onto a body diagram instead of read as a list. An
// exercise already carries its muscleGroup (ExerciseLog.muscleGroup, set at
// log time); this just averages intensity across every exercise in the
// session that shares a muscle group.

enum MuscleActivationEngine {

    struct MuscleActivation {
        let muscleGroup: String
        let percentMaxHR: Double?
        let zone: SessionIntensityEngine.IntensityZone
        /// True when this reading has no HR behind it and is standing in on
        /// relative training load instead — still real data (actual sets ×
        /// reps × weight this session), just a coarser proxy for effort than
        /// heart rate. Callers should label these differently, not hide them.
        var isVolumeBased: Bool = false
    }

    static func analyze(session: TrainingSession, maxHR: Int) -> [String: MuscleActivation] {
        var hrsByMuscle: [String: [Double]] = [:]
        var volumeByMuscle: [String: Double] = [:]

        for exercise in session.exercises {
            let group = exercise.muscleGroup.isEmpty ? "General" : exercise.muscleGroup
            let completedSets = exercise.sets.filter { $0.isCompleted }
            let avgHRs = completedSets.compactMap { $0.avgHR }
            if !avgHRs.isEmpty {
                hrsByMuscle[group, default: []].append(contentsOf: avgHRs.map(Double.init))
            }
            let volume = completedSets.reduce(0.0) { $0 + max($1.weightKg, 1) * Double($1.reps) }
            volumeByMuscle[group, default: 0] += volume
        }

        var result: [String: MuscleActivation] = [:]
        for (group, hrs) in hrsByMuscle {
            let avg = hrs.reduce(0, +) / Double(hrs.count)
            let pct = maxHR > 0 ? avg / Double(maxHR) * 100 : nil
            result[group] = MuscleActivation(
                muscleGroup: group,
                percentMaxHR: pct,
                zone: .from(percentMaxHR: pct)
            )
        }

        // No BLE strap connected that session? Fall back to how much load
        // each muscle group actually carried, relative to the hardest-hit
        // group that same session — imprecise next to real %HRmax, but a
        // real body map beats a blank card on every session without a strap.
        let maxVolume = volumeByMuscle.values.max() ?? 0
        if maxVolume > 0 {
            for (group, volume) in volumeByMuscle where result[group] == nil {
                let relative = (volume / maxVolume) * 100
                result[group] = MuscleActivation(
                    muscleGroup: group,
                    percentMaxHR: nil,
                    zone: .from(percentMaxHR: relative),
                    isVolumeBased: true
                )
            }
        }
        return result
    }

    /// Maps this app's muscleGroup strings to which body-diagram region(s)
    /// they paint — several muscle groups the app tracks (e.g. "Hamstrings")
    /// only appear on the back view, "Chest" only on the front, etc.
    ///
    /// Was an exact-string switch ("Back" only) against a catalog that
    /// actually stores compound values like "Lats · Mid Back", "Mid Back ·
    /// Lats", "Upper Back", "Rear Delt" (singular), "Chest · Triceps" —
    /// none of those equal the literal strings the switch checked for, so
    /// any exercise tagged with a compound or slightly different muscle
    /// group silently painted nothing at all. A session full of real back
    /// work showed a blank back figure because "Lats · Mid Back" never
    /// matched "Back". Same class of bug already fixed once this session
    /// in ExerciseCurator's exact-match matching — token/substring
    /// containment instead of whole-string equality, and a compound label
    /// can now paint multiple regions at once.
    static func regions(for muscleGroup: String) -> [BodyRegion] {
        let lower = muscleGroup.lowercased()
        var result: Set<BodyRegion> = []
        if lower.contains("chest") { result.insert(.chest) }
        if lower.contains("shoulder") || lower.contains("side delt") { result.insert(.frontDelts) }
        if lower.contains("rear delt") { result.insert(.rearDelts) }
        if lower.contains("back") || lower.contains("lat") { result.insert(.back) }
        if lower.contains("bicep") { result.insert(.biceps) }
        if lower.contains("tricep") { result.insert(.triceps) }
        // "ab" alone false-positives on "abductors"/"abductor" (hip/glute
        // muscles, not abs) — real bug, reachable whenever an exercise
        // added from the library falls back to the free-exercise-db
        // dataset's own muscle names (SessionComposerView.swift,
        // TrainViewModel.addExerciseForToday), which does include
        // "Abductors" as a literal value. Match the actual ab-related
        // words instead of a bare 2-letter substring.
        if lower.contains("core") || lower.contains("abs") || lower.contains("abdomin") { result.insert(.abs) }
        if lower.contains("quad") { result.insert(.quads) }
        if lower.contains("hamstring") { result.insert(.hamstrings) }
        if lower.contains("glute") { result.insert(.glutes) }
        if lower.contains("calf") || lower.contains("calve") { result.insert(.calves) }
        return Array(result)
    }
}

/// One drawable region on the front or back body silhouette.
enum BodyRegion: String, CaseIterable {
    case chest, frontDelts, biceps, abs, quads      // front
    case rearDelts, back, triceps, glutes, hamstrings, calves   // back

    var isFront: Bool {
        switch self {
        case .chest, .frontDelts, .biceps, .abs, .quads: return true
        case .rearDelts, .back, .triceps, .glutes, .hamstrings, .calves: return false
        }
    }

    var displayName: String {
        switch self {
        case .chest: return "Chest"
        case .frontDelts: return "Front Delts"
        case .biceps: return "Biceps"
        case .abs: return "Abs"
        case .quads: return "Quads"
        case .rearDelts: return "Rear Delts"
        case .back: return "Back"
        case .triceps: return "Triceps"
        case .glutes: return "Glutes"
        case .hamstrings: return "Hamstrings"
        case .calves: return "Calves"
        }
    }
}
