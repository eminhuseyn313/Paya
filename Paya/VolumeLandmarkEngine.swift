import Foundation
import SwiftData

// MARK: - Volume Landmark Engine
//
// Weekly hard sets per muscle group against Renaissance Periodization's
// published hypertrophy volume-landmark framework (Israetel et al.: MEV —
// Minimum Effective Volume, the floor below which a muscle barely grows;
// MAV — Maximum Adaptive Volume, the range that drives the best rate of
// growth; MRV — Maximum Recoverable Volume, the ceiling past which more
// sets stop helping and start costing recovery). These are the same RP
// deload/landmark figures already cited elsewhere in this app (see
// DeloadEngine, RecoveryAdjuster). The exact numbers are RP's own public
// commentary, not a single peer-reviewed paper — presented here as
// directional guidance, not a hard target, since individual recoverable
// volume genuinely varies.

enum VolumeLandmarkEngine {

    struct Landmark {
        let mev: Int
        let mavLow: Int
        let mavHigh: Int
        let mrv: Int
    }

    enum Zone: String {
        case under = "Under"
        case growing = "Growing"
        case high = "High"
        case excessive = "Excessive"

        var colorHex: String {
            switch self {
            case .under: return "9CA3AF"
            case .growing: return "059669"
            case .high: return "D97706"
            case .excessive: return "DC2626"
            }
        }
    }

    struct MuscleVolume: Identifiable {
        var id: String { muscleGroup }
        let muscleGroup: String
        let sets: Int
        let landmark: Landmark

        var zone: Zone {
            switch sets {
            case ..<landmark.mev: return .under
            case landmark.mev..<landmark.mavLow: return .under
            case landmark.mavLow...landmark.mavHigh: return .growing
            case (landmark.mavHigh + 1)..<landmark.mrv: return .high
            default: return sets > landmark.mrv ? .excessive : .high
            }
        }

        /// Fraction of the way from 0 to a scale slightly past MRV, for a
        /// bar-style visualization.
        var fillFraction: Double {
            let scaleMax = Double(landmark.mrv) * 1.15
            return min(1.0, Double(sets) / scaleMax)
        }

        var mrvFraction: Double {
            let scaleMax = Double(landmark.mrv) * 1.15
            return Double(landmark.mrv) / scaleMax
        }

        var mavLowFraction: Double {
            let scaleMax = Double(landmark.mrv) * 1.15
            return Double(landmark.mavLow) / scaleMax
        }
    }

    /// Weekly hard-set landmarks, hypertrophy-oriented (RP's published
    /// figures). Muscle groups the app doesn't track with enough specificity
    /// (Cardio, unclassified custom exercises) are simply excluded.
    private static let landmarks: [String: Landmark] = [
        "Chest": Landmark(mev: 8, mavLow: 12, mavHigh: 20, mrv: 22),
        "Back": Landmark(mev: 10, mavLow: 14, mavHigh: 22, mrv: 25),
        "Quads": Landmark(mev: 8, mavLow: 12, mavHigh: 18, mrv: 20),
        "Hamstrings": Landmark(mev: 6, mavLow: 10, mavHigh: 16, mrv: 20),
        "Glutes": Landmark(mev: 4, mavLow: 8, mavHigh: 12, mrv: 16),
        "Side Delts": Landmark(mev: 8, mavLow: 16, mavHigh: 22, mrv: 26),
        "Shoulders": Landmark(mev: 8, mavLow: 16, mavHigh: 22, mrv: 26),
        "Rear Delts": Landmark(mev: 6, mavLow: 12, mavHigh: 20, mrv: 24),
        "Biceps": Landmark(mev: 8, mavLow: 14, mavHigh: 20, mrv: 26),
        "Triceps": Landmark(mev: 6, mavLow: 10, mavHigh: 14, mrv: 18),
        "Calves": Landmark(mev: 8, mavLow: 12, mavHigh: 16, mrv: 20),
        "Core": Landmark(mev: 0, mavLow: 8, mavHigh: 16, mrv: 20)
    ]

    /// Sets logged in the trailing 7 days, grouped by muscle. "Shoulders"
    /// (vertical-press compounds) and "Side Delts" (direct isolation) are
    /// merged into one Shoulders line — the app doesn't distinguish front-
    /// delt volume separately, and RP's own tables treat delts as one
    /// category for this purpose.
    static func weeklyVolume(sessions: [TrainingSession], now: Date = .now) -> [MuscleVolume] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let recentSessions = sessions.filter { $0.isCompleted && $0.date >= weekAgo }

        var counts: [String: Int] = [:]
        for session in recentSessions {
            for log in session.exercises {
                let hardSets = log.sets.filter { $0.isCompleted }.count
                guard hardSets > 0, !log.muscleGroup.isEmpty else { continue }
                let bucket = log.muscleGroup == "Side Delts" ? "Shoulders" : log.muscleGroup
                counts[bucket, default: 0] += hardSets
            }
        }

        return counts.compactMap { muscle, sets -> MuscleVolume? in
            guard let landmark = landmarks[muscle] else { return nil }
            return MuscleVolume(muscleGroup: muscle, sets: sets, landmark: landmark)
        }
        .sorted { $0.sets > $1.sets }
    }
}
