import Foundation
import SwiftData
import SwiftUI

// MARK: - Behavior Tag System
//
// Tappable daily behavior tags that correlate with next-day recovery.
// Inspired by Whoop's Behavior Trends ($10B feature) — rebuilt for
// privacy. Tags are stored on DailyCheckIn and fed into the
// CorrelationEngine alongside existing biometric data.
//
// Research basis: Whoop's own published data shows behaviors like
// alcohol, late screens, and stretching correlate with ±15–25% swings
// in next-day HRV (Whoop Behavior Trends, 2026).

// MARK: - Behavior Category

enum BehaviorCategory: String, CaseIterable, Identifiable {
    case recovery = "recovery"
    case lifestyle = "lifestyle"
    case nutrition = "nutrition"
    case stress = "stress"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .recovery: return "Recovery"
        case .lifestyle: return "Lifestyle"
        case .nutrition: return "Nutrition"
        case .stress: return "Stress"
        }
    }
}

// MARK: - Behavior Tag Definition

struct BehaviorTagDef: Identifiable {
    let id: String
    let label: String
    let icon: String
    let colorHex: String
    let category: BehaviorCategory
    let recoveryImpactHint: String  // shown after enough data
}

enum BehaviorTags {

    static let all: [BehaviorTagDef] = [
        // Recovery
        BehaviorTagDef(id: "cold_shower", label: "Cold shower", icon: "snowflake", colorHex: "0891B2", category: .recovery,
                       recoveryImpactHint: "Cold exposure may improve HRV via vagal activation"),
        BehaviorTagDef(id: "stretching", label: "Stretching", icon: "figure.flexibility", colorHex: "059669", category: .recovery,
                       recoveryImpactHint: "Gentle mobility work supports parasympathetic recovery"),
        BehaviorTagDef(id: "sauna", label: "Sauna / Heat", icon: "flame.fill", colorHex: "DC2626", category: .recovery,
                       recoveryImpactHint: "Heat exposure elevates HR short-term but may improve HRV next-day"),
        BehaviorTagDef(id: "massage", label: "Massage / Foam roll", icon: "hand.raised.fill", colorHex: "8B5CF6", category: .recovery,
                       recoveryImpactHint: "Soft tissue work can reduce perceived soreness and improve sleep"),

        // Lifestyle
        BehaviorTagDef(id: "alcohol", label: "Alcohol", icon: "wineglass.fill", colorHex: "B45309", category: .lifestyle,
                       recoveryImpactHint: "Even moderate alcohol suppresses HRV and disrupts deep sleep"),
        BehaviorTagDef(id: "late_screen", label: "Late screen time", icon: "iphone", colorHex: "F59E0B", category: .lifestyle,
                       recoveryImpactHint: "Blue light exposure after 9 PM delays melatonin onset"),
        BehaviorTagDef(id: "outdoor_time", label: "30+ min outdoors", icon: "sun.max.fill", colorHex: "059669", category: .lifestyle,
                       recoveryImpactHint: "Daylight exposure anchors circadian rhythm and supports sleep quality"),
        BehaviorTagDef(id: "nap", label: "Nap", icon: "moon.zzz.fill", colorHex: "2563EB", category: .lifestyle,
                       recoveryImpactHint: "20-30 min naps can restore alertness without hurting night sleep"),

        // Nutrition
        BehaviorTagDef(id: "late_meal", label: "Late meal (< 2h before bed)", icon: "fork.knife", colorHex: "DC2626", category: .nutrition,
                       recoveryImpactHint: "Eating close to sleep can reduce deep sleep and elevate resting HR"),
        BehaviorTagDef(id: "high_protein_day", label: "Hit protein target", icon: "target", colorHex: "059669", category: .nutrition,
                       recoveryImpactHint: "Adequate protein supports muscle recovery and readiness"),
        BehaviorTagDef(id: "creatine", label: "Creatine", icon: "pills.fill", colorHex: "0891B2", category: .nutrition,
                       recoveryImpactHint: "5g/day supports ATP regeneration and may improve training capacity"),

        // Stress
        BehaviorTagDef(id: "meditation", label: "Meditation", icon: "brain.head.profile.fill", colorHex: "8B5CF6", category: .stress,
                       recoveryImpactHint: "Mindfulness practice improves HRV and reduces cortisol"),
        BehaviorTagDef(id: "high_stress", label: "High-stress day", icon: "exclamationmark.triangle.fill", colorHex: "DC2626", category: .stress,
                       recoveryImpactHint: "Psychological stress suppresses HRV and impairs recovery"),
        BehaviorTagDef(id: "breathwork", label: "Breathwork", icon: "wind", colorHex: "0891B2", category: .stress,
                       recoveryImpactHint: "Coherent breathing shifts autonomic balance toward parasympathetic"),
    ]

    static func tag(for id: String) -> BehaviorTagDef? {
        all.first { $0.id == id }
    }
}

// MARK: - Behavior Log (SwiftData)

@Model
class BehaviorLog {
    var id: UUID
    var date: Date
    var tagIds: [String]    // which behaviors were active this day
    var profileId: UUID?

    init(date: Date = .now, tagIds: [String] = []) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.tagIds = tagIds
        self.profileId = ActiveProfile.id
    }
}

// MARK: - Behavior Store

enum BehaviorStore {

    @MainActor
    static func todaysLog(context: ModelContext) -> BehaviorLog? {
        let pid = ActiveProfile.id
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<BehaviorLog>(
            predicate: #Predicate<BehaviorLog> { $0.date >= startOfDay && $0.profileId == pid }
        )
        return (try? context.fetch(descriptor))?.first
    }

    @MainActor
    static func toggleTag(_ tagId: String, context: ModelContext) {
        let log: BehaviorLog
        if let existing = todaysLog(context: context) {
            log = existing
        } else {
            log = BehaviorLog()
            context.insert(log)
        }

        if let idx = log.tagIds.firstIndex(of: tagId) {
            log.tagIds.remove(at: idx)
        } else {
            log.tagIds.append(tagId)
        }
        try? context.save()
    }

    @MainActor
    static func recentLogs(daysBack: Int = 30, context: ModelContext) -> [BehaviorLog] {
        let pid = ActiveProfile.id
        let cutoff = Calendar.current.date(byAdding: .day, value: -daysBack, to: .now) ?? .now
        let descriptor = FetchDescriptor<BehaviorLog>(
            predicate: #Predicate<BehaviorLog> { $0.date >= cutoff && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

// MARK: - Behavior ↔ Recovery Correlation

enum BehaviorRecoveryEngine {

    struct BehaviorInsight: Identifiable {
        let id: String
        let tag: BehaviorTagDef
        let avgRecoveryWith: Double
        let avgRecoveryWithout: Double
        let delta: Double           // positive = behavior helps recovery
        let samplesWith: Int
        let samplesWithout: Int
        let isPositive: Bool
        let text: String
    }

    /// Correlates each behavior tag with next-day readiness scores.
    /// Requires at least 5 days with the behavior and 5 without to surface an insight.
    @MainActor
    static func computeInsights(context: ModelContext) async -> [BehaviorInsight] {
        let logs = BehaviorStore.recentLogs(daysBack: 60, context: context)
        guard logs.count >= 14 else { return [] }

        // Gather readiness scores by date
        let store = BiometricStore.shared
        if store.history.isEmpty {
            await store.loadHistory(daysBack: 60)
        }

        let calendar = Calendar.current
        var readinessByDate: [Date: Int] = [:]

        // Compute a simple readiness proxy from RHR + HRV
        for entry in store.history {
            let day = calendar.startOfDay(for: entry.date)
            // Simple readiness: higher HRV = better, lower RHR = better
            if let hrv = entry.hrv, let rhr = entry.restingHR {
                // Normalize to 0-100 scale (rough heuristic)
                let hrvScore = min(100, max(0, (hrv - 15) / 0.85))  // 15ms=0, 100ms=100
                let rhrScore = min(100, max(0, (90 - rhr) / 0.5))   // 90bpm=0, 40bpm=100
                readinessByDate[day] = Int((hrvScore * 0.6 + rhrScore * 0.4))
            }
        }

        var insights: [BehaviorInsight] = []

        for tagDef in BehaviorTags.all {
            var scoresWithBehavior: [Double] = []
            var scoresWithoutBehavior: [Double] = []

            // For each day in the log window, check if the behavior was tagged,
            // then look at NEXT day's readiness
            let allDays = Set(logs.map { calendar.startOfDay(for: $0.date) })
            for day in allDays {
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day),
                      let nextDayReadiness = readinessByDate[nextDay] else { continue }

                let dayLog = logs.first { calendar.startOfDay(for: $0.date) == day }
                let hasBehavior = dayLog?.tagIds.contains(tagDef.id) ?? false

                if hasBehavior {
                    scoresWithBehavior.append(Double(nextDayReadiness))
                } else {
                    scoresWithoutBehavior.append(Double(nextDayReadiness))
                }
            }

            guard scoresWithBehavior.count >= 5, scoresWithoutBehavior.count >= 5 else { continue }

            let avgWith = scoresWithBehavior.reduce(0, +) / Double(scoresWithBehavior.count)
            let avgWithout = scoresWithoutBehavior.reduce(0, +) / Double(scoresWithoutBehavior.count)
            let delta = avgWith - avgWithout
            let isPositive = delta > 0

            // Only surface if the delta is meaningful (>3 points)
            guard abs(delta) >= 3 else { continue }

            let pctChange = abs(delta / avgWithout * 100)
            let direction = isPositive ? "higher" : "lower"
            let text = "Days after \(tagDef.label.lowercased()), your recovery averages \(Int(pctChange))% \(direction)."

            insights.append(BehaviorInsight(
                id: tagDef.id,
                tag: tagDef,
                avgRecoveryWith: avgWith,
                avgRecoveryWithout: avgWithout,
                delta: delta,
                samplesWith: scoresWithBehavior.count,
                samplesWithout: scoresWithoutBehavior.count,
                isPositive: isPositive,
                text: text
            ))
        }

        return insights.sorted { abs($0.delta) > abs($1.delta) }
    }
}
