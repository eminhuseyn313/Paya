import Foundation
import WidgetKit

// MARK: - Widget Snapshot Writer
// The Home Screen widget runs in a separate process with no access to
// SwiftData directly, so this writes a small, deliberately narrow snapshot
// to an App Group-shared UserDefaults suite whenever the Dashboard loads,
// then tells WidgetKit to redraw immediately rather than waiting for the
// timeline's own refresh policy.

struct PayaWidgetSnapshot: Codable {
    var recoveryScore: Int?
    var recoveryBand: String?
    var trainingDayLabel: String?
    var isTrainingDay: Bool
    var waterMl: Int
    var waterTargetMl: Int
    var proteinG: Double
    var proteinTargetG: Double
    var calories: Double
    var calorieTarget: Double
    var streak: Int
    var stepsToday: Int?
    var stepGoal: Int?
    var nextExercises: [String]?
    var updatedAt: Date

    init(
        recoveryScore: Int? = nil, recoveryBand: String? = nil,
        trainingDayLabel: String? = nil, isTrainingDay: Bool = false,
        waterMl: Int = 0, waterTargetMl: Int = 2500,
        proteinG: Double = 0, proteinTargetG: Double = 0,
        calories: Double = 0, calorieTarget: Double = 0,
        streak: Int = 0, stepsToday: Int? = nil, stepGoal: Int? = nil,
        nextExercises: [String]? = nil, updatedAt: Date = .now
    ) {
        self.recoveryScore = recoveryScore
        self.recoveryBand = recoveryBand
        self.trainingDayLabel = trainingDayLabel
        self.isTrainingDay = isTrainingDay
        self.waterMl = waterMl
        self.waterTargetMl = waterTargetMl
        self.proteinG = proteinG
        self.proteinTargetG = proteinTargetG
        self.calories = calories
        self.calorieTarget = calorieTarget
        self.streak = streak
        self.stepsToday = stepsToday
        self.stepGoal = stepGoal
        self.nextExercises = nextExercises
        self.updatedAt = updatedAt
    }
}

enum WidgetSnapshotWriter {
    static let appGroupId = "group.Paya.Paya.shared"
    static let snapshotKey = "widget_snapshot"

    static func write(
        recoveryScore: Int?,
        recoveryBand: String?,
        trainingDayLabel: String?,
        isTrainingDay: Bool,
        waterMl: Int,
        waterTargetMl: Int,
        proteinG: Double = 0,
        proteinTargetG: Double = 0,
        calories: Double = 0,
        calorieTarget: Double = 0,
        streak: Int = 0,
        nextExercises: [String]? = nil
    ) {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
        let snapshot = PayaWidgetSnapshot(
            recoveryScore: recoveryScore,
            recoveryBand: recoveryBand,
            trainingDayLabel: trainingDayLabel,
            isTrainingDay: isTrainingDay,
            waterMl: waterMl,
            waterTargetMl: waterTargetMl,
            proteinG: proteinG,
            proteinTargetG: proteinTargetG,
            calories: calories,
            calorieTarget: calorieTarget,
            streak: streak,
            nextExercises: nextExercises,
            updatedAt: .now
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
