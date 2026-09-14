import Foundation
import SwiftData

// MARK: - Experiment
//
// Closed-loop tracking: the app recommends things constantly (cut dairy,
// try magnesium, adjust sleep timing) but never used to say whether any of
// them actually worked. An Experiment is a user-declared "I'm testing X
// starting on this date," and ExperimentEngine compares the tracked metric
// before vs. after that date so the answer is a real before/after read
// against the user's own history, not a guess.

enum ExperimentMetric: String, Codable, CaseIterable, Identifiable {
    case flareFrequency
    case jointPain
    case sleepHours
    case energyLevel

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flareFrequency: return "Flare frequency"
        case .jointPain:      return "Joint pain"
        case .sleepHours:     return "Sleep"
        case .energyLevel:    return "Energy"
        }
    }

    var icon: String {
        switch self {
        case .flareFrequency: return "exclamationmark.triangle.fill"
        case .jointPain:      return "figure.walk.motion"
        case .sleepHours:     return "moon.fill"
        case .energyLevel:    return "bolt.fill"
        }
    }

    /// Whether a LOWER value is the desired direction — true for
    /// flareFrequency/jointPain, false for sleepHours/energyLevel (more is
    /// better up to a point, but "more" reads as improvement for this UI's
    /// purposes).
    var lowerIsBetter: Bool {
        switch self {
        case .flareFrequency, .jointPain: return true
        case .sleepHours, .energyLevel:   return false
        }
    }
}

@Model
class Experiment {
    var id: UUID
    var profileId: UUID? = nil
    var title: String
    var metricRaw: String
    var startDate: Date
    var notes: String
    var createdAt: Date
    var isActive: Bool = true

    var metric: ExperimentMetric {
        get { ExperimentMetric(rawValue: metricRaw) ?? .flareFrequency }
        set { metricRaw = newValue.rawValue }
    }

    init(title: String, metric: ExperimentMetric, startDate: Date, notes: String = "") {
        self.id = UUID()
        self.title = title
        self.metricRaw = metric.rawValue
        self.startDate = startDate
        self.notes = notes
        self.createdAt = .now
    }
}

enum ExperimentStore {
    @MainActor
    static func active(context: ModelContext) -> [Experiment] {
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<Experiment>(
            predicate: #Predicate<Experiment> { $0.profileId == pid && $0.isActive },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    @discardableResult
    static func add(title: String, metric: ExperimentMetric, startDate: Date, notes: String, context: ModelContext) -> Experiment {
        let exp = Experiment(title: title, metric: metric, startDate: startDate, notes: notes)
        exp.profileId = ActiveProfile.id
        context.insert(exp)
        try? context.save()
        return exp
    }

    @MainActor
    static func end(_ experiment: Experiment, context: ModelContext) {
        experiment.isActive = false
        try? context.save()
    }

    @MainActor
    static func delete(_ experiment: Experiment, context: ModelContext) {
        context.delete(experiment)
        try? context.save()
    }
}
