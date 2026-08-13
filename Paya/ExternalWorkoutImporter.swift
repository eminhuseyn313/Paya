import Foundation
import HealthKit
import SwiftData

// MARK: - External Workout Importer
//
// Workouts logged through Apple's native Fitness app or the Watch's own
// Workout app never became part of this app's training history before —
// HealthKitManager already had a function to read them, but the only thing
// it fed was a single rough "active minutes" number on one Dashboard card.
// They didn't count toward streaks, progress charts, or weekly adherence.
//
// This imports them as real (read-only) TrainingSession entries — duration
// and activity type only, no exercise/set detail since none exists for a
// run or a native Fitness session — clearly tagged `sourceRaw ==
// "appleFitness"` so the UI can distinguish them from sessions actually
// logged inside Paya, and de-duplicated by HKWorkout.uuid so re-running
// this doesn't create duplicates.
enum ExternalWorkoutImporter {

    @MainActor
    static func importRecent(daysBack: Int = 14, context: ModelContext) async {
        let workouts = await HealthKitManager.shared.fetchRecentExternalWorkouts(daysBack: daysBack)
        guard !workouts.isEmpty else { return }

        let pid = ActiveProfile.id
        let existingIds: Set<String> = {
            let descriptor = FetchDescriptor<TrainingSession>(
                predicate: #Predicate<TrainingSession> { $0.externalWorkoutId != nil && $0.profileId == pid }
            )
            let sessions = (try? context.fetch(descriptor)) ?? []
            return Set(sessions.compactMap(\.externalWorkoutId))
        }()

        for workout in workouts {
            let workoutId = workout.uuid.uuidString
            guard !existingIds.contains(workoutId) else { continue }

            let hr = await averageHeartRateAsync(for: workout)
            let session = TrainingSession(
                sessionType: label(for: workout.workoutActivityType),
                date: workout.startDate,
                durationMinutes: Int(workout.duration / 60),
                isCompleted: true,
                notes: "Logged via Apple Fitness — no exercise detail available for external workouts.",
                sessionAvgHR: hr
            )
            session.profileId = pid
            session.sourceRaw = "appleFitness"
            session.externalWorkoutId = workoutId
            context.insert(session)
        }
        try? context.save()
    }

    private static func averageHeartRate(for workout: HKWorkout) -> Int? {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return nil }
        if let avg = workout.statistics(for: hrType)?.averageQuantity() {
            return Int(avg.doubleValue(for: HKUnit.count().unitDivided(by: .minute())).rounded())
        }
        return nil
    }

    private static func averageHeartRateAsync(for workout: HKWorkout) async -> Int? {
        if let sync = averageHeartRate(for: workout) { return sync }
        return await HealthKitManager.shared.fetchAverageHR(from: workout.startDate, to: workout.endDate)
    }

    private static func label(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Ride"
        case .swimming: return "Swim"
        case .yoga: return "Yoga"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .coreTraining: return "Core"
        case .hiking: return "Hike"
        case .elliptical: return "Elliptical"
        case .rowing: return "Row"
        case .stairClimbing: return "Stairs"
        case .dance, .cardioDance: return "Dance"
        case .pilates: return "Pilates"
        case .boxing, .kickboxing: return "Boxing"
        default: return "Workout"
        }
    }
}
