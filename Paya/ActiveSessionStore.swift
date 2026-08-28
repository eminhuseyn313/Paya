import Foundation

extension Notification.Name {
    /// Posted by ContentView when scenePhase enters .background.
    /// PulseTrainView listens for this to persist the active session.
    static let payaWillBackground = Notification.Name("payaWillBackground")
}

// MARK: - Active Session Persistence
//
// Saves the in-progress workout state to disk so that if the app is
// terminated (by the user, iOS memory pressure, or a crash) the session
// can be restored on next launch — no more lost sets.
//
// The snapshot is written:
//   • On every set toggle (completed/uncompleted)
//   • On every weight or rep edit
//   • When the app enters background (scenePhase == .background)
//   • When a session is started
//
// The snapshot is cleared:
//   • When the session is completed (data moves to SwiftData)
//   • When the session is explicitly discarded by the user
//
// Storage: JSON in UserDefaults under "paya_active_session". This is
// intentionally NOT SwiftData — the active session is transient state
// that doesn't need indexing, relationships, or migration. UserDefaults
// + Codable is simpler, faster to write (no context.save() overhead),
// and avoids the risk of SwiftData model version conflicts.

struct ActiveSessionSnapshot: Codable {
    let sessionTypeCode: String     // e.g. "A", "B", "C"
    let sessionLabel: String        // e.g. "Push/Pull/Legs + Arms"
    let startTime: Date
    let pausedElapsed: TimeInterval
    let isPaused: Bool
    let isSimpleMode: Bool
    let isFlareDay: Bool
    let exercises: [ExerciseSnapshot]

    struct ExerciseSnapshot: Codable {
        let id: String
        let name: String
        let muscleGroup: String
        let note: String
        let cableAttachment: String?
        let cablePosition: String?
        let isExpanded: Bool
        // We don't persist the full ExerciseDefinition — on restore we
        // rebuild from the program. Only the user-entered data matters.
        let sets: [SetSnapshot]
    }

    struct SetSnapshot: Codable {
        let setNumber: Int
        let weightKg: Double
        let reps: Int
        let isCompleted: Bool
        let isWarmup: Bool
        let setTypeRaw: String
        let rpe: Int
        let peakHR: Int?
        let avgHR: Int?
        let endHR: Int?
    }
}

enum ActiveSessionStore {

    private static let key = "paya_active_session"

    // MARK: - Save

    static func save(_ snapshot: ActiveSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Load

    static func load() -> ActiveSessionSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(ActiveSessionSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }

    // MARK: - Clear

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Has Pending Session

    static var hasPendingSession: Bool {
        UserDefaults.standard.data(forKey: key) != nil
    }
}
