import Foundation
import SwiftData

enum NotificationCategory: String, Codable, CaseIterable, Identifiable {
    case training, meal, supplement, hydration, recovery, weighIn, milestone, flareRisk, restTimer, medication, eyeCare, circadian, postWorkoutNutrition, weeklyDigest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .training: return "Training reminders"
        case .meal: return "Meal reminders"
        case .supplement: return "Supplement reminders"
        case .hydration: return "Hydration reminders"
        case .recovery: return "Recovery prompts"
        case .weighIn: return "Weigh-in reminders"
        case .milestone: return "Milestones"
        case .flareRisk: return "Flare-risk alerts"
        case .restTimer: return "Rest timer"
        case .medication: return "Medication reminders"
        case .eyeCare: return "Eye care reminders"
        case .circadian: return "Morning light reminders"
        case .postWorkoutNutrition: return "Post-workout nutrition"
        case .weeklyDigest: return "Weekly review"
        }
    }
}

enum NotificationDestination: String, Codable {
    case home, train, nutrition, health, progress, settings
}

@Model
final class NotificationRecord {
    @Attribute(.unique) var id: UUID
    var profileId: UUID
    var categoryRaw: String
    var title: String
    var message: String
    var createdAt: Date
    var readAt: Date?
    var destinationRaw: String?
    var deduplicationKey: String?

    init(
        category: NotificationCategory,
        title: String,
        message: String,
        profileId: UUID,
        createdAt: Date = .now,
        readAt: Date? = nil,
        destination: NotificationDestination? = nil,
        deduplicationKey: String? = nil
    ) {
        self.id = UUID()
        self.profileId = profileId
        self.categoryRaw = category.rawValue
        self.title = title
        self.message = message
        self.createdAt = createdAt
        self.readAt = readAt
        self.destinationRaw = destination?.rawValue
        self.deduplicationKey = deduplicationKey
    }

    var category: NotificationCategory {
        get { NotificationCategory(rawValue: categoryRaw) ?? .training }
        set { categoryRaw = newValue.rawValue }
    }

    var destination: NotificationDestination? {
        get { destinationRaw.flatMap(NotificationDestination.init(rawValue:)) }
        set { destinationRaw = newValue?.rawValue }
    }
}

enum NotificationCenterStore {

    @discardableResult
    static func createIfNeeded(
        _ record: NotificationRecord,
        context: ModelContext
    ) throws -> NotificationRecord? {
        if let key = record.deduplicationKey?.trimmingCharacters(in: .whitespacesAndNewlines),
           !key.isEmpty {
            let profileId = record.profileId
            let descriptor = FetchDescriptor<NotificationRecord>(
                predicate: #Predicate { notification in
                    notification.profileId == profileId && notification.deduplicationKey == key
                }
            )
            if !(try context.fetch(descriptor)).isEmpty {
                return nil
            }
            record.deduplicationKey = key
        }

        context.insert(record)
        try context.save()
        return record
    }

    static func unreadCount(profileId: UUID, context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<NotificationRecord>(
            predicate: #Predicate { notification in
                notification.profileId == profileId && notification.readAt == nil
            }
        )
        return try context.fetchCount(descriptor)
    }

    static func markRead(_ record: NotificationRecord, context: ModelContext) throws {
        guard record.readAt == nil else { return }
        record.readAt = .now
        try context.save()
    }

    static func markAllRead(profileId: UUID, context: ModelContext) throws {
        let descriptor = FetchDescriptor<NotificationRecord>(
            predicate: #Predicate { notification in
                notification.profileId == profileId && notification.readAt == nil
            }
        )
        for record in try context.fetch(descriptor) {
            record.readAt = .now
        }
        try context.save()
    }

    static func delete(_ record: NotificationRecord, context: ModelContext) throws {
        context.delete(record)
        try context.save()
    }
}
