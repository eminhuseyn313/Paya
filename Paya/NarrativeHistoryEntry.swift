import Foundation
import SwiftData

// MARK: - Narrative History Entry
//
// DailyNarrativeEngine computes fresh every time and was never persisted —
// so there was no way to see how "today's story" evolved over weeks, only
// today's snapshot. One entry per day (written when the daily briefing is
// generated — see NotificationManager.scheduleDailyBriefing's call site in
// PulseDashboard.loadData) turns the narrative engine into a journal: "3
// weeks of rising stress load, then it broke" is a pattern only visible
// across entries, never from a single day's headline alone.

@Model
class NarrativeHistoryEntry {
    var id: UUID
    var profileId: UUID? = nil
    var date: Date
    var headline: String
    var source: String       // e.g. "Flare risk", "Stress load"
    var icon: String
    var colorHex: String

    init(date: Date, headline: String, source: String, icon: String, colorHex: String) {
        self.id = UUID()
        self.date = date
        self.headline = headline
        self.source = source
        self.icon = icon
        self.colorHex = colorHex
    }
}

enum NarrativeHistoryStore {
    @MainActor
    static func record(headline: DailyNarrativeEngine.Narrative.Point, context: ModelContext) {
        let pid = ActiveProfile.id
        let today = Calendar.current.startOfDay(for: .now)

        // One entry per day — if today's already recorded (e.g. a retry),
        // update it in place rather than duplicating.
        let descriptor = FetchDescriptor<NarrativeHistoryEntry>(
            predicate: #Predicate<NarrativeHistoryEntry> { $0.profileId == pid && $0.date == today }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.headline = headline.text
            existing.source = headline.source
            existing.icon = headline.icon
            existing.colorHex = headline.colorHex
        } else {
            let entry = NarrativeHistoryEntry(
                date: today,
                headline: headline.text,
                source: headline.source,
                icon: headline.icon,
                colorHex: headline.colorHex
            )
            entry.profileId = pid
            context.insert(entry)
        }
        try? context.save()
    }

    @MainActor
    static func recent(days: Int = 30, context: ModelContext) -> [NarrativeHistoryEntry] {
        let pid = ActiveProfile.id
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let descriptor = FetchDescriptor<NarrativeHistoryEntry>(
            predicate: #Predicate<NarrativeHistoryEntry> { $0.profileId == pid && $0.date >= cutoff },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
