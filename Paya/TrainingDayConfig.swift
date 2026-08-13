import Foundation
import SwiftData
import SwiftUI

@Model
class TrainingDayConfig {

    var id: UUID
    var profileId: UUID? = nil
    var code: String
    var name: String
    var focus: String
    var colorHex: String
    var weekday: Int
    var orderIndex: Int

    init(
        code: String,
        name: String,
        focus: String,
        colorHex: String,
        weekday: Int = 0,
        orderIndex: Int = 0,
        profileId: UUID? = nil
    ) {
        self.id = UUID()
        self.code = code
        self.name = name
        self.focus = focus
        self.colorHex = colorHex
        self.weekday = weekday
        self.orderIndex = orderIndex
        self.profileId = profileId
    }

    var color: Color { Color(hex: colorHex) }

    var weekdayName: String {
        switch weekday {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 3: return "Tuesday"
        case 4: return "Wednesday"
        case 5: return "Thursday"
        case 6: return "Friday"
        case 7: return "Saturday"
        default: return "Unassigned"
        }
    }
}

struct DaySnapshot: Equatable, Hashable {
    var code: String
    var name: String
    var focus: String
    var colorHex: String
    var weekday: Int

    var color: Color { Color(hex: colorHex) }

    static let fallback = DaySnapshot(
        code: "A", name: "Session A",
        focus: "Push · Pull · Legs + Arms",
        colorHex: "2563EB", weekday: 2
    )
}

enum TrainingDayStore {

    static let presetColors: [String] = [
        "2563EB", "059669", "D97706", "8B5CF6",
        "DC2626", "0891B2", "DB2777", "65A30D"
    ]

    private static func scoped(context: ModelContext) -> [TrainingDayConfig] {
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<TrainingDayConfig>(
            predicate: #Predicate { $0.profileId == pid },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func seedIfNeeded(context: ModelContext) {
        guard scoped(context: context).isEmpty else { return }
        let pid = ActiveProfile.id
        let defaults: [(String, String, String, String, Int)] = [
            ("A", "Session A", "Push · Pull · Legs + Arms", "2563EB", 2),
            ("B", "Session B", "Full Body · Hypertrophy", "059669", 5),
            ("C", "Session C", "Full Body · Volume", "D97706", 7)
        ]
        for (index, d) in defaults.enumerated() {
            context.insert(TrainingDayConfig(
                code: d.0, name: d.1, focus: d.2,
                colorHex: d.3, weekday: d.4,
                orderIndex: index, profileId: pid
            ))
        }
        try? context.save()
    }

    static func all(context: ModelContext) -> [TrainingDayConfig] {
        scoped(context: context)
    }

    static func snapshot(_ config: TrainingDayConfig) -> DaySnapshot {
        DaySnapshot(
            code: config.code, name: config.name, focus: config.focus,
            colorHex: config.colorHex, weekday: config.weekday
        )
    }

    static func allSnapshots(context: ModelContext) -> [DaySnapshot] {
        all(context: context).map { snapshot($0) }
    }

    static func today(context: ModelContext) -> DaySnapshot? {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return allSnapshots(context: context).first { $0.weekday == weekday }
    }

    static func nextCode(context: ModelContext) -> String {
        let used = Set(all(context: context).map { $0.code })
        let alphabet = "ABCDEFGHIJ"
        for ch in alphabet where !used.contains(String(ch)) {
            return String(ch)
        }
        return "X\(used.count)"
    }

    @discardableResult
    static func addDay(context: ModelContext) -> TrainingDayConfig {
        let code = nextCode(context: context)
        let existing = all(context: context)
        let nextOrder = (existing.map { $0.orderIndex }.max() ?? -1) + 1
        let color = presetColors[existing.count % presetColors.count]
        let config = TrainingDayConfig(
            code: code, name: "Session \(code)", focus: "Custom day",
            colorHex: color, weekday: 0,
            orderIndex: nextOrder, profileId: ActiveProfile.id
        )
        context.insert(config)
        try? context.save()
        return config
    }

    static func delete(_ config: TrainingDayConfig, context: ModelContext) {
        let code = config.code
        let pid = ActiveProfile.id
        let customDescriptor = FetchDescriptor<CustomSession>(
            predicate: #Predicate { $0.sessionTypeRaw == code && $0.profileId == pid }
        )
        if let customs = try? context.fetch(customDescriptor) {
            for c in customs { context.delete(c) }
        }
        context.delete(config)
        for (idx, day) in all(context: context).enumerated() {
            day.orderIndex = idx
        }
        try? context.save()
    }

    /// One-time adoption: assigns orphan records (nil profileId) to the given profile.
    @MainActor
    static func adoptOrphans(to pid: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<TrainingDayConfig>(
            predicate: #Predicate { $0.profileId == nil }
        )
        for day in (try? context.fetch(descriptor)) ?? [] {
            day.profileId = pid
        }
    }
}
