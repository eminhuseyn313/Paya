import Foundation
import EventKit

// MARK: - Calendar Service
// EventKit wrapper for the Personal Health Management timeline — reads
// work/personal calendar events so they can be shown alongside health data
// hour by hour. Read-only, no new Xcode target or entitlement needed
// (unlike WeatherKit/CloudKit, calendar access is just an Info.plist
// privacy string + a runtime permission prompt).

struct CalendarEventSummary: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarColorHex: String
}

@MainActor
@Observable
final class CalendarService {

    static let shared = CalendarService()

    private let store = EKEventStore()
    var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    private init() {}

    var isAuthorized: Bool {
        authorizationStatus == .fullAccess
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            return granted
        } catch {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            return false
        }
    }

    func events(on date: Date) -> [CalendarEventSummary] {
        guard isAuthorized else { return [] }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { event in
            CalendarEventSummary(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Untitled event",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                calendarColorHex: event.calendar?.cgColor.map { hexString(from: $0) } ?? "6B7280"
            )
        }.sorted { $0.startDate < $1.startDate }
    }

    private func hexString(from cgColor: CGColor) -> String {
        guard let components = cgColor.components, components.count >= 3 else { return "6B7280" }
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
