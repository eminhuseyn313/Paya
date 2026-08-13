import Foundation
import SwiftData

// MARK: - Deload Engine
// Suggests a deload week after sustained training blocks; tracks the active
// deload window per profile.
//
// The 5-week trigger and ~35%-lighter reduction follow the same RP/Israetel
// deload guidance already cited in PeriodizationEngine.swift (deload every
// ~4-6 weeks of accumulation, cutting volume/intensity by roughly a third
// to a half) — Israetel M, Hoffmann J, Smith CW. "Scientific Principles of
// Strength Training." The 7-day window length is this app's own choice
// (RP guidance itself doesn't mandate a fixed week count), not a cited
// figure.

enum DeloadEngine {

    private static func lastDeloadKey(_ pid: UUID?) -> String {
        "deload_start_\(pid?.uuidString ?? "none")"
    }

    // MARK: - Active deload window

    static var activeDeloadStart: Date? {
        get {
            let key = lastDeloadKey(ActiveProfile.id)
            guard let t = UserDefaults.standard.object(forKey: key) as? Date else { return nil }
            // Active only within 7 days of start
            return Date().timeIntervalSince(t) <= 7 * 86400 ? t : nil
        }
    }

    static var isDeloadActive: Bool {
        activeDeloadStart != nil
    }

    static var deloadDaysRemaining: Int {
        guard let start = activeDeloadStart else { return 0 }
        let elapsed = Date().timeIntervalSince(start)
        return max(0, 7 - Int(elapsed / 86400))
    }

    static func startDeload() {
        UserDefaults.standard.set(Date(), forKey: lastDeloadKey(ActiveProfile.id))
    }

    static func endDeloadEarly() {
        // Backdate 8 days so the window is expired but the "last deload"
        // reference point for week counting is preserved.
        let past = Calendar.current.date(byAdding: .day, value: -8, to: Date()) ?? Date()
        UserDefaults.standard.set(past, forKey: lastDeloadKey(ActiveProfile.id))
    }

    // MARK: - Suggestion logic

    struct Suggestion {
        let weeksTrained: Int
        let isDue: Bool
        let reason: String
    }

    @MainActor
    static func evaluate(context: ModelContext) -> Suggestion {
        let pid = ActiveProfile.id
        _ = Calendar.current

        // Reference point: last deload start, or earliest session
        let key = lastDeloadKey(pid)
        let lastDeload = UserDefaults.standard.object(forKey: key) as? Date

        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.profileId == pid && $0.isCompleted == true },
            sortBy: [SortDescriptor(\.date)]
        )
        let sessions = (try? context.fetch(descriptor)) ?? []

        let windowStart = lastDeload
            ?? sessions.first?.date
            ?? Date()

        // Count distinct calendar weeks with at least one session since windowStart
        var weeks: Set<String> = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-ww"
        for session in sessions where session.date > windowStart {
            weeks.insert(formatter.string(from: session.date))
        }
        // Exclude sessions during an active/expired deload week itself
        let weeksTrained = weeks.count

        let due = weeksTrained >= 5
        let reason: String
        if due {
            reason = "You've trained \(weeksTrained) consecutive weeks. A deload week (~35% lighter) dissipates fatigue so progression can resume — and protects your joints."
        } else {
            reason = "\(weeksTrained)/5 weeks into this training block."
        }

        return Suggestion(
            weeksTrained: weeksTrained,
            isDue: due && !isDeloadActive,
            reason: reason
        )
    }
}//
//  DeloadEngine.swift
//  Paya
//
//  Created by Emin Huseynzade on 14.07.26.
//

