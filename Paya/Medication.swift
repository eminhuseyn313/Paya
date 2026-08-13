import Foundation
import SwiftData

// MARK: - Medication Frequency

enum MedicationFrequency: String, CaseIterable, Codable, Identifiable {
    case daily, weekly, biweekly, monthly, asNeeded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .biweekly: return "Every 2 weeks"
        case .monthly: return "Monthly"
        case .asNeeded: return "As needed"
        }
    }

    /// Days until the next dose is due, counted from the last one taken.
    /// nil for "as needed" — those are never automatically due.
    var intervalDays: Int? {
        switch self {
        case .daily: return 1
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30
        case .asNeeded: return nil
        }
    }
}

// MARK: - Medication

@Model
class Medication {
    var id: UUID
    var profileId: UUID? = nil
    var name: String
    var dose: String
    var frequencyRaw: String
    var startDate: Date
    var isActive: Bool = true
    var notes: String = ""

    init(name: String, dose: String, frequency: MedicationFrequency, startDate: Date = .now, notes: String = "") {
        self.id = UUID()
        self.name = name
        self.dose = dose
        self.frequencyRaw = frequency.rawValue
        self.startDate = startDate
        self.notes = notes
    }

    var frequency: MedicationFrequency {
        get { MedicationFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }
}

// MARK: - Medication Dose Log

@Model
class MedicationDoseLog {
    var id: UUID
    var medicationId: UUID
    var takenAt: Date
    var profileId: UUID? = nil

    init(medicationId: UUID, takenAt: Date = .now) {
        self.id = UUID()
        self.medicationId = medicationId
        self.takenAt = takenAt
    }
}

// MARK: - Store

enum MedicationStore {

    static func active(context: ModelContext) -> [Medication] {
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<Medication>(
            predicate: #Predicate { $0.profileId == pid && $0.isActive == true },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func all(context: ModelContext) -> [Medication] {
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<Medication>(
            predicate: #Predicate { $0.profileId == pid },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    static func add(name: String, dose: String, frequency: MedicationFrequency, context: ModelContext) -> Medication {
        let med = Medication(name: name, dose: dose, frequency: frequency)
        med.profileId = ActiveProfile.id
        context.insert(med)
        try? context.save()
        return med
    }

    static func delete(_ medication: Medication, context: ModelContext) {
        let id = medication.id
        let logDescriptor = FetchDescriptor<MedicationDoseLog>(
            predicate: #Predicate { $0.medicationId == id }
        )
        for log in (try? context.fetch(logDescriptor)) ?? [] {
            context.delete(log)
        }
        context.delete(medication)
        try? context.save()
    }

    static func logDose(_ medication: Medication, at date: Date = .now, context: ModelContext) {
        let log = MedicationDoseLog(medicationId: medication.id, takenAt: date)
        log.profileId = ActiveProfile.id
        context.insert(log)
        try? context.save()
    }

    static func lastTaken(_ medication: Medication, context: ModelContext) -> Date? {
        let id = medication.id
        let descriptor = FetchDescriptor<MedicationDoseLog>(
            predicate: #Predicate { $0.medicationId == id },
            sortBy: [SortDescriptor(\.takenAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.first?.takenAt
    }

    static func takenToday(_ medication: Medication, context: ModelContext) -> Bool {
        guard let last = lastTaken(medication, context: context) else { return false }
        return Calendar.current.isDateInToday(last)
    }

    /// Next due date — from the last dose taken (or the medication's start
    /// date if never logged) plus its interval. Nil for "as needed" meds.
    static func nextDueDate(_ medication: Medication, context: ModelContext) -> Date? {
        guard let interval = medication.frequency.intervalDays else { return nil }
        let anchor = lastTaken(medication, context: context) ?? medication.startDate
        return Calendar.current.date(byAdding: .day, value: interval, to: anchor)
    }

    static func isDueToday(_ medication: Medication, context: ModelContext) -> Bool {
        guard let due = nextDueDate(medication, context: context) else { return false }
        return due <= .now
    }

    /// True if there's a daily+ dose log for the given day — used by
    /// CorrelationEngine as a simple "did you take your meds today" input.
    static func anyDoseTaken(on date: Date, context: ModelContext) -> Bool {
        let pid = ActiveProfile.id
        let dayStart = Calendar.current.startOfDay(for: date)
        guard let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        let descriptor = FetchDescriptor<MedicationDoseLog>(
            predicate: #Predicate<MedicationDoseLog> { $0.takenAt >= dayStart && $0.takenAt < dayEnd && $0.profileId == pid }
        )
        return !((try? context.fetch(descriptor)) ?? []).isEmpty
    }
}
