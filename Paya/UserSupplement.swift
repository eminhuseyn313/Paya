import Foundation
import SwiftData

// MARK: - User Supplement

@Model
class UserSupplement {
    var id: UUID
    var profileId: UUID? = nil
    var name: String
    var dose: String
    var timing: String
    var orderIndex: Int
    var isActive: Bool = true
    var isAutoSeeded: Bool = true

    init(
        name: String, dose: String, timing: String, orderIndex: Int,
        isActive: Bool = true, isAutoSeeded: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.dose = dose
        self.timing = timing
        self.orderIndex = orderIndex
        self.isActive = isActive
        self.isAutoSeeded = isAutoSeeded
    }
}

// MARK: - Store

enum UserSupplementStore {

    static func seedIfNeeded(goal: TrainingGoal, context: ModelContext) {
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<UserSupplement>(
            predicate: #Predicate { $0.profileId == pid }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }
        for (i, s) in ProgramData.supplements(for: goal).enumerated() {
            let sup = UserSupplement(name: s.name, dose: s.dose, timing: s.timing, orderIndex: i, isAutoSeeded: true)
            sup.profileId = pid
            context.insert(sup)
        }
        try? context.save()
    }

    /// Replaces the auto-seeded stack with the one for `goal`, leaving any
    /// supplements the user added themselves untouched.
    static func syncForGoal(_ goal: TrainingGoal, context: ModelContext) {
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<UserSupplement>(
            predicate: #Predicate { $0.profileId == pid }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        let custom = existing.filter { !$0.isAutoSeeded }.sorted { $0.orderIndex < $1.orderIndex }
        for s in existing where s.isAutoSeeded {
            context.delete(s)
        }

        let stack = ProgramData.supplements(for: goal)
        for (i, s) in stack.enumerated() {
            let sup = UserSupplement(name: s.name, dose: s.dose, timing: s.timing, orderIndex: i, isAutoSeeded: true)
            sup.profileId = pid
            context.insert(sup)
        }
        for (offset, s) in custom.enumerated() {
            s.orderIndex = stack.count + offset
        }
        try? context.save()
    }

    static func all(context: ModelContext) -> [UserSupplement] {
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<UserSupplement>(
            predicate: #Predicate { $0.profileId == pid },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func active(context: ModelContext) -> [UserSupplement] {
        all(context: context).filter { $0.isActive }
    }

    @discardableResult
    static func add(context: ModelContext) -> UserSupplement {
        let next = (all(context: context).map { $0.orderIndex }.max() ?? -1) + 1
        let s = UserSupplement(name: "New supplement", dose: "", timing: "", orderIndex: next, isAutoSeeded: false)
        s.profileId = ActiveProfile.id
        context.insert(s)
        try? context.save()
        return s
    }

    static func delete(_ s: UserSupplement, context: ModelContext) {
        context.delete(s)
        try? context.save()
    }

    @MainActor
    static func adoptOrphans(to pid: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<UserSupplement>(
            predicate: #Predicate { $0.profileId == nil }
        )
        for s in (try? context.fetch(descriptor)) ?? [] {
            s.profileId = pid
        }
    }
}
