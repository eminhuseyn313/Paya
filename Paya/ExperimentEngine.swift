import Foundation
import SwiftData

// MARK: - Experiment Engine
//
// Phase 5 of the correlation roadmap: closes the loop on the app's own
// recommendations. Compares a tracked metric in the window before an
// experiment's start date against the window after it, using the user's
// own HealthLog history — the same data source every other health-tracking
// surface in the app already writes to, so this needs no new logging
// habit from the user beyond what daily check-ins already capture.
//
// Also runs the same comparison against Medication start dates
// automatically (a "passive" experiment nobody had to declare) — a
// medication already has a real start date, so "did this actually help"
// is answerable with zero extra user action.

enum ExperimentEngine {

    struct Comparison {
        let metric: ExperimentMetric
        let beforeAvg: Double
        let afterAvg: Double
        let beforeDays: Int
        let afterDays: Int
        let percentChange: Double   // signed, relative to beforeAvg
        let isImprovement: Bool
        let isReady: Bool           // false if not enough after-data yet

        var summary: String {
            guard isReady else {
                return "Still gathering data — check back in a few more days."
            }
            let direction = isImprovement ? "down" : "up"
            let magnitude = abs(percentChange)
            if magnitude < 5 {
                return "No meaningful change in \(metric.displayName.lowercased()) so far."
            }
            return "\(metric.displayName) is \(direction) \(String(format: "%.0f", magnitude))% since starting, vs. the \(beforeDays) days before."
        }
    }

    /// Minimum days of after-data before a comparison is considered
    /// meaningful enough to show a verdict rather than "still gathering."
    private static let minAfterDays = 7

    static func compare(
        metric: ExperimentMetric,
        startDate: Date,
        healthLogs: [HealthLog],
        windowDays: Int = 21
    ) -> Comparison? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        guard let windowStart = calendar.date(byAdding: .day, value: -windowDays, to: start) else { return nil }
        let windowEnd = calendar.date(byAdding: .day, value: windowDays, to: start) ?? .now

        let before = healthLogs.filter { $0.date >= windowStart && $0.date < start }
        let after = healthLogs.filter { $0.date >= start && $0.date <= min(windowEnd, .now) }

        guard !before.isEmpty else { return nil }

        func value(_ logs: [HealthLog]) -> Double? {
            switch metric {
            case .flareFrequency:
                guard !logs.isEmpty else { return nil }
                return Double(logs.filter(\.isFlareDay).count) / Double(logs.count) * 100 // % of days flaring
            case .jointPain:
                let vals = logs.map { Double($0.jointPainLevel) }
                guard !vals.isEmpty else { return nil }
                return vals.reduce(0, +) / Double(vals.count)
            case .sleepHours:
                let vals = logs.map(\.sleepHours).filter { $0 > 0 }
                guard !vals.isEmpty else { return nil }
                return vals.reduce(0, +) / Double(vals.count)
            case .energyLevel:
                let vals = logs.map { Double($0.energyLevel) }
                guard !vals.isEmpty else { return nil }
                return vals.reduce(0, +) / Double(vals.count)
            }
        }

        guard let beforeAvg = value(before) else { return nil }
        let isReady = after.count >= minAfterDays
        let afterAvg = value(after) ?? beforeAvg

        let rawChange = beforeAvg == 0 ? 0 : ((afterAvg - beforeAvg) / beforeAvg) * 100
        let isImprovement = metric.lowerIsBetter ? rawChange < 0 : rawChange > 0

        return Comparison(
            metric: metric,
            beforeAvg: beforeAvg,
            afterAvg: afterAvg,
            beforeDays: before.count,
            afterDays: after.count,
            percentChange: rawChange,
            isImprovement: isImprovement,
            isReady: isReady
        )
    }

    // MARK: - Passive experiments from medications

    struct PassiveExperiment: Identifiable {
        let id = UUID()
        let title: String
        let startDate: Date
        let comparison: Comparison
    }

    /// Medications started at least `minAfterDays` ago, each compared
    /// against flare frequency and joint pain — the two metrics most
    /// directly relevant to "is this medication working."
    @MainActor
    static func passiveExperiments(context: ModelContext) -> [PassiveExperiment] {
        let pid = ActiveProfile.id
        let medDescriptor = FetchDescriptor<Medication>(
            predicate: #Predicate<Medication> { $0.profileId == pid && $0.isActive }
        )
        let medications = (try? context.fetch(medDescriptor)) ?? []
        guard !medications.isEmpty else { return [] }

        let healthDescriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.profileId == pid }
        )
        let healthLogs = (try? context.fetch(healthDescriptor)) ?? []

        let cutoff = Calendar.current.date(byAdding: .day, value: -minAfterDays, to: .now) ?? .now
        var results: [PassiveExperiment] = []
        for med in medications where med.startDate <= cutoff {
            if let cmp = compare(metric: .flareFrequency, startDate: med.startDate, healthLogs: healthLogs), cmp.isReady {
                results.append(.init(title: med.name, startDate: med.startDate, comparison: cmp))
            }
        }
        return results
    }
}
