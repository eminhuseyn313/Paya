import Foundation

// MARK: - Session Intensity Engine
//
// Per-set heart rate (peakHR/avgHR/endHR) has been captured all along via
// the BLE monitor, but nothing ever rolled it up per exercise — the session
// completion screen only ever showed one whole-session average/peak. This
// answers the real question: within one session, which exercises actually
// drove heart rate up (you pushed) and which barely moved it (you coasted),
// using %HRmax zone bands from ACSM's exercise-intensity classification
// (ACSM's Guidelines for Exercise Testing and Prescription): <64% light,
// 64-76% moderate, 77-93% vigorous, 94%+ near-maximal.

enum SessionIntensityEngine {

    struct ExerciseIntensity: Identifiable {
        var id: String { exerciseId }
        let exerciseId: String
        let exerciseName: String
        let avgHR: Double?
        let peakHR: Int?
        let percentMaxHR: Double?
        let zone: IntensityZone
    }

    enum IntensityZone: String {
        case noData = "No HR data"
        case light = "Light"
        case moderate = "Moderate"
        case vigorous = "Vigorous"
        case nearMax = "Near-max"

        var colorHex: String {
            switch self {
            case .noData: return "9CA3AF"
            case .light: return "60A5FA"
            case .moderate: return "34D399"
            case .vigorous: return "F59E0B"
            case .nearMax: return "DC2626"
            }
        }

        static func from(percentMaxHR: Double?) -> IntensityZone {
            guard let pct = percentMaxHR else { return .noData }
            switch pct {
            case 94...: return .nearMax
            case 77..<94: return .vigorous
            case 64..<77: return .moderate
            default: return .light
            }
        }
    }

    static func analyze(session: TrainingSession, maxHR: Int) -> [ExerciseIntensity] {
        session.exercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { exercise in
                let avgHRs = exercise.sets.compactMap { $0.avgHR }
                let peakHRs = exercise.sets.compactMap { $0.peakHR }
                let avg = avgHRs.isEmpty ? nil : Double(avgHRs.reduce(0, +)) / Double(avgHRs.count)
                let peak = peakHRs.max()
                let percentMax = avg.map { $0 / Double(maxHR) * 100 }

                return ExerciseIntensity(
                    exerciseId: exercise.exerciseId,
                    exerciseName: exercise.exerciseName,
                    avgHR: avg,
                    peakHR: peak,
                    percentMaxHR: percentMax,
                    zone: .from(percentMaxHR: percentMax)
                )
            }
    }

    /// Whether ANY exercise in the session has HR data worth showing —
    /// callers should hide the whole card rather than show an all-"No HR
    /// data" heatmap.
    static func hasUsableData(_ intensities: [ExerciseIntensity]) -> Bool {
        intensities.contains { $0.avgHR != nil }
    }
}
