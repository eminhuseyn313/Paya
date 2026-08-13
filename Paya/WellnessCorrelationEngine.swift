import Foundation
import SwiftData

// MARK: - Wellness Correlation Engine
//
// The watch/HealthKit connection gives us a heart-rate time series; the app
// already knows exactly when meals were logged (MealLog.loggedAt) and now,
// via WaterEventLog, exactly when water was actually drunk. Nobody else in
// this app has connected those three things — this engine looks at what the
// heart rate was doing in the window after each meal and across the longest
// gap without water, and flags it when it's meaningfully off the day's own
// baseline. This is small-N pattern-spotting, not a diagnosis: it says
// "this happened today," not "this food is bad for you." Each flagged day
// is persisted (WellnessInsightRecord) so a repeat occurrence is reported
// as "this is the Nth time in the last month" instead of the engine
// re-discovering the same thing from scratch with no memory each day.

enum WellnessCorrelationEngine {

    struct Insight: Identifiable {
        let id = UUID()
        let icon: String
        let colorHex: String
        let text: String
    }

    /// Minimum intraday HR samples before we trust a baseline enough to
    /// call anything a deviation — Apple Watch typically logs a background
    /// HR sample every 5-10 minutes, so this needs several hours of wear.
    private static let minimumSamplesForBaseline = 20

    // The 90-minute post-meal window rests on real physiology — digestion
    // measurably raises heart rate via diet-induced thermogenesis, an effect
    // that's well documented to develop and fade within roughly this range
    // (Westerterp KR. "Diet induced thermogenesis." Nutr Metab (Lond). 2004)
    // — but the exact cutoff, and the 8bpm/3.5h flag thresholds below, are
    // this app's own tuning for signal-to-noise, not values taken from that
    // or any other study.
    private static let mealWindowMinutes: TimeInterval = 90 * 60
    private static let notableHRDeltaBpm = 8.0
    private static let notableHydrationGapHours = 3.5

    @MainActor
    static func analyzeToday(context: ModelContext) async -> [Insight] {
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)

        let nDescriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == pid }
        )
        let nutritionLogs = (try? context.fetch(nDescriptor)) ?? []
        let todaysMeals = (nutritionLogs.first { calendar.isDate($0.date, inSameDayAs: startOfDay) }?.meals ?? [])
            .sorted { $0.loggedAt < $1.loggedAt }

        let waterDescriptor = FetchDescriptor<WaterEventLog>(
            predicate: #Predicate<WaterEventLog> { $0.date >= startOfDay && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        let waterEvents = (try? context.fetch(waterDescriptor)) ?? []

        guard !todaysMeals.isEmpty || !waterEvents.isEmpty else { return [] }

        let hrSamples = await HealthKitManager.shared.fetchHeartRateSamples(since: startOfDay)
        guard hrSamples.count >= minimumSamplesForBaseline else { return [] }

        let baselineHR = hrSamples.map(\.bpm).reduce(0, +) / Double(hrSamples.count)

        var insights: [Insight] = []

        for meal in todaysMeals {
            let windowEnd = meal.loggedAt.addingTimeInterval(mealWindowMinutes)
            let windowSamples = hrSamples.filter { $0.date >= meal.loggedAt && $0.date <= windowEnd }
            guard windowSamples.count >= 3 else { continue }
            let windowAvg = windowSamples.map(\.bpm).reduce(0, +) / Double(windowSamples.count)
            let delta = windowAvg - baselineHR
            guard delta >= notableHRDeltaBpm else { continue }
            let time = meal.loggedAt.formatted(date: .omitted, time: .shortened)
            let occurrences = recordAndCountRecurrence(kind: "mealHR", pid: pid, today: startOfDay, context: context)
            let recurrenceNote = occurrences >= 2
                ? " This is the \(ordinal(occurrences)) time in the last month — starting to look like a real pattern, not noise."
                : " Worth watching if it repeats."
            insights.append(Insight(
                icon: "fork.knife.circle.fill", colorHex: "F97316",
                text: "Heart rate ran ~\(Int(delta))bpm above today's average in the 90 minutes after \(meal.name.lowercased()) (\(time))." + recurrenceNote
            ))
        }

        let checkpoints = [startOfDay] + waterEvents.map(\.date) + [Date.now]
        var longestGap: (start: Date, end: Date, hours: Double)? = nil
        for i in 1..<checkpoints.count {
            let hours = checkpoints[i].timeIntervalSince(checkpoints[i - 1]) / 3600
            if hours > (longestGap?.hours ?? 0) {
                longestGap = (checkpoints[i - 1], checkpoints[i], hours)
            }
        }
        if let gap = longestGap, gap.hours >= notableHydrationGapHours {
            let gapSamples = hrSamples.filter { $0.date >= gap.start && $0.date <= gap.end }
            if gapSamples.count >= 5 {
                let gapAvg = gapSamples.map(\.bpm).reduce(0, +) / Double(gapSamples.count)
                if gapAvg - baselineHR >= 5 {
                    let occurrences = recordAndCountRecurrence(kind: "hydrationHR", pid: pid, today: startOfDay, context: context)
                    let recurrenceNote = occurrences >= 2
                        ? " This is the \(ordinal(occurrences)) time this month a long water gap has lined up with elevated heart rate."
                        : ""
                    insights.append(Insight(
                        icon: "drop.circle.fill", colorHex: "0891B2",
                        text: "You went \(String(format: "%.1f", gap.hours))h without logging water this \(partOfDay(gap.start)), and heart rate ran higher than your average over that stretch." + recurrenceNote
                    ))
                }
            }
        }

        if !insights.isEmpty, let checkIn = todaysCheckIn(context: context, pid: pid, startOfDay: startOfDay), checkIn.energy == 1 {
            insights.insert(Insight(
                icon: "exclamationmark.triangle.fill", colorHex: "DC2626",
                text: "You also logged feeling drained this morning — that lines up with what your heart rate is showing below."
            ), at: 0)
        }

        if insights.isEmpty {
            insights.append(Insight(
                icon: "checkmark.seal.fill", colorHex: "059669",
                text: "Nothing unusual today — heart rate held steady around your logged meals and water."
            ))
        }
        return insights
    }

    /// Records today's occurrence of a flagged pattern (once per day, kind,
    /// and profile) and returns the total count of that kind in the
    /// trailing 30 days, including today — the basis for "this is the Nth
    /// time" instead of treating every day as a fresh discovery.
    @MainActor
    private static func recordAndCountRecurrence(kind: String, pid: UUID?, today: Date, context: ModelContext) -> Int {
        let existingTodayDescriptor = FetchDescriptor<WellnessInsightRecord>(
            predicate: #Predicate<WellnessInsightRecord> { $0.kind == kind && $0.date >= today && $0.profileId == pid }
        )
        let alreadyRecordedToday = ((try? context.fetch(existingTodayDescriptor)) ?? []).isEmpty == false
        if !alreadyRecordedToday {
            let record = WellnessInsightRecord(kind: kind)
            record.profileId = pid
            context.insert(record)
            try? context.save()
        }

        let monthAgo = Calendar.current.date(byAdding: .day, value: -30, to: today) ?? today
        let countDescriptor = FetchDescriptor<WellnessInsightRecord>(
            predicate: #Predicate<WellnessInsightRecord> { $0.kind == kind && $0.date >= monthAgo && $0.profileId == pid }
        )
        return (try? context.fetch(countDescriptor))?.count ?? (alreadyRecordedToday ? 1 : 1)
    }

    private static func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }

    private static func todaysCheckIn(context: ModelContext, pid: UUID?, startOfDay: Date) -> DailyCheckIn? {
        let descriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate<DailyCheckIn> { $0.date >= startOfDay && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.first
    }

    private static func partOfDay(_ date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default: return "night"
        }
    }
}
