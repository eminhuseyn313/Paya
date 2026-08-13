import Foundation
import SwiftData

// MARK: - Custom Session Composition

@Model
class CustomSession {

    var id: UUID
    var profileId: UUID? = nil
    var sessionTypeRaw: String       // day code: "A", "B", "C", "D"...
    var lastEditedAt: Date

    @Relationship(deleteRule: .cascade)
    var exercises: [CustomSessionExercise] = []

    init(
        sessionTypeRaw: String,
        lastEditedAt: Date = .now
    ) {
        self.id = UUID()
        self.sessionTypeRaw = sessionTypeRaw
        self.lastEditedAt = lastEditedAt
    }

    var sessionType: SessionType? {
        SessionType(rawValue: sessionTypeRaw)
    }

    var sortedExercises: [CustomSessionExercise] {
        exercises.sorted { $0.orderIndex < $1.orderIndex }
    }
}

// MARK: - Custom Session Exercise

@Model
class CustomSessionExercise {

    var id: UUID
    var exerciseId: String
    var exerciseName: String
    var orderIndex: Int
    var sets: Int
    var repMin: Int
    var repMax: Int
    var startWeightKg: Double
    var restSeconds: Int
    var isJointSensitive: Bool
    var notes: String
    var muscleGroup: String
    var sourceRaw: String

    // Superset/circuit grouping — exercises sharing the same non-nil group
    // number are meant to be done back-to-back with no rest in between,
    // resting only after the whole group's round is complete. Absent
    // before this: superset support is one of the most consistently
    // requested strength-app features and had no representation at all.
    var supersetGroup: Int? = nil

    // Other exercises that hit the same movement pattern — carried through
    // from the template/pool at install time so the live session can offer
    // a same-day substitution (equipment taken, today's pain flare, boredom)
    // without editing the underlying program.
    var alternatives: [String] = []

    @Relationship(inverse: \CustomSession.exercises)
    var session: CustomSession?

    init(
        exerciseId: String,
        exerciseName: String,
        orderIndex: Int,
        sets: Int = 3,
        repMin: Int = 8,
        repMax: Int = 12,
        startWeightKg: Double = 20,
        restSeconds: Int = 90,
        isJointSensitive: Bool = false,
        notes: String = "",
        muscleGroup: String = "",
        sourceRaw: String = "library",
        alternatives: [String] = []
    ) {
        self.id = UUID()
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.orderIndex = orderIndex
        self.sets = sets
        self.repMin = repMin
        self.repMax = repMax
        self.startWeightKg = startWeightKg
        self.restSeconds = restSeconds
        self.isJointSensitive = isJointSensitive
        self.notes = notes
        self.muscleGroup = muscleGroup
        self.sourceRaw = sourceRaw
        self.alternatives = alternatives
    }

    var source: Source {
        Source(rawValue: sourceRaw) ?? .library
    }

    var measurement: ExerciseMeasurement { .infer(name: exerciseName, startWeightKg: startWeightKg) }

    enum Source: String {
        case program
        case library
    }

    func toExerciseDefinition() -> ExerciseDefinition {
        let repRange = matchedRepRange()
        return ExerciseDefinition(
            id: exerciseId,
            name: exerciseName,
            type: sets >= 3 ? .compound : .isolation,
            sets: sets,
            repRange: repRange,
            startWeightKg: startWeightKg,
            progressionNote: "Add weight when \(sets)×\(repMax)",
            isJointSensitive: isJointSensitive,
            specialProgressionRule: notes.isEmpty ? nil : notes,
            alternativeExercise: nil,
            muscleGroup: muscleGroup,
            gifURL: nil,
            alternativeGifURL: nil,
            supersetGroup: supersetGroup,
            alternatives: alternatives
        )
    }

    private func matchedRepRange() -> RepRange {
        if repMin == 8 && repMax == 10 { return .eightToTen }
        if repMin == 10 && repMax == 12 { return .tenToTwelve }
        if repMin == 12 && repMax == 15 { return .twelveToFifteen }
        if repMin == 15 && repMax == 20 { return .fifteenToTwenty }
        let mid = (repMin + repMax) / 2
        switch mid {
        case ..<10:  return .eightToTen
        case ..<12:  return .tenToTwelve
        case ..<15:  return .twelveToFifteen
        default:     return .fifteenToTwenty
        }
    }
}
