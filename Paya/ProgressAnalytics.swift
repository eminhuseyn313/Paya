import Foundation
import SwiftData

// MARK: - Progress Analytics
// Per-exercise progression, estimated 1RM, and personal records.

enum ProgressAnalytics {

    // Epley formula — standard e1RM estimate
    static func estimatedOneRM(weightKg: Double, reps: Int) -> Double {
        guard reps > 0, weightKg > 0 else { return 0 }
        if reps == 1 { return weightKg }
        return weightKg * (1.0 + Double(reps) / 30.0)
    }

    // MARK: - Exercises the user has actually logged

    struct LoggedExercise: Identifiable, Hashable {
        var id: String { exerciseId }
        let exerciseId: String
        let name: String
        let sessionCount: Int
    }

    static func loggedExercises(sessions: [TrainingSession]) -> [LoggedExercise] {
        var counts: [String: Int] = [:]
        for session in sessions where session.isCompleted {
            var seenThisSession: Set<String> = []
            for log in session.exercises {
                guard log.sets.contains(where: { $0.isCompleted }) else { continue }
                let key = log.exerciseName
                if seenThisSession.insert(key).inserted {
                    counts[key, default: 0] += 1
                }
            }
        }
        return counts
            .map { LoggedExercise(exerciseId: $0.key, name: $0.key, sessionCount: $0.value) }
            .sorted { $0.sessionCount > $1.sessionCount }
    }

    // MARK: - Per-exercise progression timeline

    struct ProgressionPoint: Identifiable {
        let id = UUID()
        let date: Date
        let bestE1RM: Double
        let topWeight: Double
        let totalVolume: Double
    }

    static func progression(
        exerciseId: String,
        sessions: [TrainingSession]
    ) -> [ProgressionPoint] {
        var points: [ProgressionPoint] = []
        for session in sessions where session.isCompleted {
            let matching = session.exercises.filter { $0.exerciseName == exerciseId || $0.exerciseId == exerciseId }
            guard !matching.isEmpty else { continue }
            let completed = matching.flatMap { $0.sets.filter { $0.isCompleted } }
            guard !completed.isEmpty else { continue }

            let bestE1RM = completed
                .map { estimatedOneRM(weightKg: $0.weightKg, reps: $0.reps) }
                .max() ?? 0
            let topWeight = completed.map { $0.weightKg }.max() ?? 0
            let volume = completed.reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }

            points.append(ProgressionPoint(
                date: session.date,
                bestE1RM: bestE1RM,
                topWeight: topWeight,
                totalVolume: volume
            ))
        }
        return points.sorted { $0.date < $1.date }
    }

    // MARK: - Personal Records

    struct ExercisePR {
        let exerciseId: String
        let exerciseName: String
        let bestWeight: Double
        let bestWeightReps: Int
        let bestWeightDate: Date
        let bestE1RM: Double
        let bestE1RMDate: Date
        let bestSessionVolume: Double
        let bestSessionVolumeDate: Date
    }

    static func personalRecord(
        exerciseId: String,
        sessions: [TrainingSession]
    ) -> ExercisePR? {
        var name = ""
        var bestWeight = 0.0
        var bestWeightReps = 0
        var bestWeightDate = Date.distantPast
        var bestE1RM = 0.0
        var bestE1RMDate = Date.distantPast
        var bestVolume = 0.0
        var bestVolumeDate = Date.distantPast

        for session in sessions where session.isCompleted {
            let matching = session.exercises.filter { $0.exerciseName == exerciseId || $0.exerciseId == exerciseId }
            guard !matching.isEmpty else { continue }
            let completed = matching.flatMap { $0.sets.filter { $0.isCompleted } }
            guard !completed.isEmpty else { continue }
            name = matching.first?.exerciseName ?? exerciseId

            for set in completed {
                if set.weightKg > bestWeight {
                    bestWeight = set.weightKg
                    bestWeightReps = set.reps
                    bestWeightDate = session.date
                }
                let e1rm = estimatedOneRM(weightKg: set.weightKg, reps: set.reps)
                if e1rm > bestE1RM {
                    bestE1RM = e1rm
                    bestE1RMDate = session.date
                }
            }

            let volume = completed.reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }
            if volume > bestVolume {
                bestVolume = volume
                bestVolumeDate = session.date
            }
        }

        guard bestWeight > 0 else { return nil }
        return ExercisePR(
            exerciseId: exerciseId,
            exerciseName: name,
            bestWeight: bestWeight,
            bestWeightReps: bestWeightReps,
            bestWeightDate: bestWeightDate,
            bestE1RM: bestE1RM,
            bestE1RMDate: bestE1RMDate,
            bestSessionVolume: bestVolume,
            bestSessionVolumeDate: bestVolumeDate
        )
    }

    // MARK: - Recent PR feed (last N days)

    struct PREvent: Identifiable {
        let id = UUID()
        let date: Date
        let exerciseName: String
        let kind: Kind
        let value: Double
        let reps: Int?

        enum Kind {
            case weight, e1rm, volume

            var label: String {
                switch self {
                case .weight: return "Weight PR"
                case .e1rm:   return "Strength PR"
                case .volume: return "Volume PR"
                }
            }

            var icon: String {
                switch self {
                case .weight: return "scalemass.fill"
                case .e1rm:   return "bolt.fill"
                case .volume: return "chart.bar.fill"
                }
            }

            var colorHex: String {
                switch self {
                case .weight: return "2563EB"
                case .e1rm:   return "D97706"
                case .volume: return "059669"
                }
            }
        }
    }

    static func recentPRs(
        sessions: [TrainingSession],
        daysBack: Int = 30
    ) -> [PREvent] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        let sorted = sessions.filter { $0.isCompleted }.sorted { $0.date < $1.date }

        // Running bests per exercise as we walk forward in time
        var bestWeight: [String: Double] = [:]
        var bestE1RM: [String: Double] = [:]
        var bestVolume: [String: Double] = [:]
        var events: [PREvent] = []

        for session in sorted {
            for log in session.exercises {
                let completed = log.sets.filter { $0.isCompleted }
                guard !completed.isEmpty else { continue }
                let key = log.exerciseName

                let sessionTopWeight = completed.map { $0.weightKg }.max() ?? 0
                let sessionTopWeightReps = completed
                    .filter { $0.weightKg == sessionTopWeight }
                    .map { $0.reps }.max() ?? 0
                let sessionBestE1RM = completed
                    .map { estimatedOneRM(weightKg: $0.weightKg, reps: $0.reps) }
                    .max() ?? 0
                let sessionVolume = completed.reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }

                let isRecent = session.date >= cutoff

                if sessionTopWeight > (bestWeight[key] ?? 0) {
                    if isRecent && bestWeight[key] != nil {
                        events.append(PREvent(
                            date: session.date, exerciseName: log.exerciseName,
                            kind: .weight, value: sessionTopWeight, reps: sessionTopWeightReps
                        ))
                    }
                    bestWeight[key] = sessionTopWeight
                }
                if sessionBestE1RM > (bestE1RM[key] ?? 0) {
                    if isRecent && bestE1RM[key] != nil {
                        events.append(PREvent(
                            date: session.date, exerciseName: log.exerciseName,
                            kind: .e1rm, value: sessionBestE1RM, reps: nil
                        ))
                    }
                    bestE1RM[key] = sessionBestE1RM
                }
                if sessionVolume > (bestVolume[key] ?? 0) {
                    if isRecent && bestVolume[key] != nil {
                        events.append(PREvent(
                            date: session.date, exerciseName: log.exerciseName,
                            kind: .volume, value: sessionVolume, reps: nil
                        ))
                    }
                    bestVolume[key] = sessionVolume
                }
            }
        }

        return events.sorted { $0.date > $1.date }
    }
}//
//  ProgressAnalytics.swift
//  Paya
//
//  Created by Emin Huseynzade on 11.07.26.
//

