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
    static func regions(for muscleGroup: String) -> [BodyRegion] {
        switch muscleGroup {
        case "Chest": return [.chest]
        case "Shoulders", "Side Delts": return [.frontDelts]
        case "Rear Delts": return [.rearDelts]
        case "Back": return [.back]
        case "Biceps": return [.biceps]
        case "Triceps": return [.triceps]
        case "Core": return [.abs]
        case "Quads": return [.quads]
        case "Hamstrings": return [.hamstrings]
        case "Glutes": return [.glutes]
        case "Calves": return [.calves]
        default: return []
        }
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
