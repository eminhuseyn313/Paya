import Foundation
import Observation

// MARK: - OfflineSessionManager
// Runs today's planned workout entirely on the watch (phone left in the
// locker). The phone periodically pushes the plan; sets are kept locally and
// the finished session is sent with transferUserInfo, which the system
// delivers when the phone is next available. While active it drives the same
// screens as a phone-linked session by publishing into WatchConnectivityManager.

@MainActor
@Observable
final class OfflineSessionManager {

    static let shared = OfflineSessionManager()

    struct PlanExercise: Codable {
        var id: String
        var name: String
        var sets: Int
        var weightKg: Double
        var reps: Int
        var measurementRaw: String
        var muscle: String
    }
    struct LoggedSet: Codable {
        var exerciseId: String
        var name: String
        var muscle: String
        var setNumber: Int
        var weightKg: Double
        var reps: Int
    }

    private(set) var plan: [PlanExercise] = []
    private(set) var dayName = ""
    private(set) var colorHex = "2563EB"
    private(set) var isActive = false
    private var exIdx = 0
    private var setIdx = 0
    private var logged: [LoggedSet] = []
    private var startDate = Date()
    private var sessionId = UUID().uuidString

    /// Default rest between sets when running without the phone. A common
    /// 60–120 s range; the phone's learned per-exercise rest isn't available here.
    private let defaultRest = 90

    private let planKey = "paya_watch_offline_plan"

    private init() {
        if let data = UserDefaults.standard.data(forKey: planKey),
           let stored = try? JSONDecoder().decode(StoredPlan.self, from: data) {
            plan = stored.exercises; dayName = stored.dayName; colorHex = stored.colorHex
        }
        loadPersisted()
    }

    private struct StoredPlan: Codable { var exercises: [PlanExercise]; var dayName: String; var colorHex: String }

    // MARK: Crash/force-quit safety
    // The in-progress session is written to disk after every set. If the app
    // is killed mid-workout, the sets are never lost: either the workout is
    // resumed (when HealthKit hands back the live workout) or the user can
    // send what was logged to the iPhone.

    struct Persisted: Codable {
        var sessionId: String
        var startDate: Date
        var lastUpdate: Date
        var dayName: String
        var colorHex: String
        var plan: [PlanExercise]
        var exIdx: Int
        var setIdx: Int
        var logged: [LoggedSet]
    }

    private let persistKey = "paya_watch_offline_inprogress"
    private(set) var recoverable: Persisted?

    private func persist() {
        let p = Persisted(sessionId: sessionId, startDate: startDate, lastUpdate: .now, dayName: dayName,
                          colorHex: colorHex, plan: plan, exIdx: exIdx, setIdx: setIdx, logged: logged)
        if let data = try? JSONEncoder().encode(p) { UserDefaults.standard.set(data, forKey: persistKey) }
    }

    private func clearPersisted() {
        UserDefaults.standard.removeObject(forKey: persistKey)
        recoverable = nil
    }

    private func loadPersisted() {
        guard let data = UserDefaults.standard.data(forKey: persistKey),
              let p = try? JSONDecoder().decode(Persisted.self, from: data) else { return }
        // Anything older than 8 h is a stale leftover, not a workout to resume.
        if Date().timeIntervalSince(p.lastUpdate) > 8 * 3600 { clearPersisted(); return }
        recoverable = p
    }

    /// HealthKit gave the live workout back after a relaunch → pick up exactly where we were.
    func resumeIfPersisted() {
        guard !isActive, let p = recoverable else { return }
        plan = p.plan; dayName = p.dayName; colorHex = p.colorHex
        exIdx = p.exIdx; setIdx = p.setIdx; logged = p.logged
        startDate = p.startDate; sessionId = p.sessionId
        isActive = true
        recoverable = nil
        let wc = WatchConnectivityManager.shared
        wc.sessionActive = true
        wc.setsCompleted = logged.count
        wc.volumeKg = logged.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
        publish()
    }

    /// No live workout to resume — send the sets that were logged to the iPhone.
    func saveRecoverableToPhone() {
        guard let p = recoverable else { return }
        if !p.logged.isEmpty {
            let end = max(p.lastUpdate, p.startDate)
            WatchConnectivityManager.shared.sendOfflineSession(Self.payload(
                sessionId: p.sessionId, dayName: p.dayName, start: p.startDate,
                duration: end.timeIntervalSince(p.startDate), avgHR: nil, logged: p.logged))
        }
        clearPersisted()
    }

    func discardRecoverable() { clearPersisted() }

    private static func payload(sessionId: String, dayName: String, start: Date, duration: TimeInterval,
                                avgHR: Int?, logged: [LoggedSet]) -> [String: Any] {
        var payload: [String: Any] = [
            "action": "offlineSession", "sessionId": sessionId, "dayName": dayName,
            "start": start, "durationSec": duration,
            "sets": logged.map { s -> [String: Any] in
                ["exerciseId": s.exerciseId, "name": s.name, "muscle": s.muscle,
                 "setNumber": s.setNumber, "weightKg": s.weightKg, "reps": s.reps]
            },
        ]
        if let avgHR { payload["avgHR"] = avgHR }
        return payload
    }

    var hasPlan: Bool { !plan.isEmpty }

    // MARK: Plan from phone

    func loadPlan(from context: [String: Any]) {
        guard !isActive, let raw = context["planExercises"] as? [[String: Any]] else { return }
        let parsed: [PlanExercise] = raw.compactMap { d in
            guard let id = d["id"] as? String, let name = d["name"] as? String else { return nil }
            return PlanExercise(
                id: id, name: name,
                sets: d["sets"] as? Int ?? 3,
                weightKg: d["weightKg"] as? Double ?? 0,
                reps: d["reps"] as? Int ?? 10,
                measurementRaw: d["measurementRaw"] as? String ?? "weightedReps",
                muscle: d["muscle"] as? String ?? ""
            )
        }
        guard !parsed.isEmpty else { return }
        plan = parsed
        dayName = context["planDayName"] as? String ?? dayName
        colorHex = context["planColorHex"] as? String ?? colorHex
        if let data = try? JSONEncoder().encode(StoredPlan(exercises: plan, dayName: dayName, colorHex: colorHex)) {
            UserDefaults.standard.set(data, forKey: planKey)
        }
    }

    // MARK: Lifecycle

    func start() {
        guard hasPlan, !isActive, !WorkoutManager.shared.isActive else { return }
        recoverable = nil
        isActive = true
        exIdx = 0; setIdx = 0; logged = []
        startDate = Date()
        sessionId = UUID().uuidString
        WorkoutManager.shared.start(.strength, linked: false)
        publish()
        persist()
        WatchConnectivityManager.shared.sessionActive = true
    }

    func logSet(weightKg: Double, reps: Int) {
        guard isActive, exIdx < plan.count else { return }
        let ex = plan[exIdx]
        logged.append(LoggedSet(exerciseId: ex.id, name: ex.name, muscle: ex.muscle,
                                setNumber: setIdx + 1, weightKg: weightKg, reps: reps))
        let wc = WatchConnectivityManager.shared
        wc.setsCompleted = logged.count
        wc.volumeKg = logged.reduce(0) { $0 + $1.weightKg * Double($1.reps) }

        // Next set follows the weight/reps just used (straight sets).
        plan[exIdx].weightKg = weightKg
        plan[exIdx].reps = reps
        if setIdx + 1 < ex.sets {
            setIdx += 1
        } else {
            exIdx += 1; setIdx = 0
        }
        publish()
        persist()
        let rest = defaultRest
        wc.restTotalSeconds = rest
        wc.restEndDate = Date().addingTimeInterval(Double(rest))
    }

    func skipRest() { WatchConnectivityManager.shared.restEndDate = nil }

    /// Ends the workout; if any sets were logged, queues the session to the phone.
    func finish() {
        guard isActive else { return }
        let wm = WorkoutManager.shared
        let duration = max(wm.elapsedNow, Date().timeIntervalSince(startDate))
        if !logged.isEmpty {
            WatchConnectivityManager.shared.sendOfflineSession(Self.payload(
                sessionId: sessionId, dayName: dayName, start: startDate,
                duration: duration, avgHR: wm.avgHeartRate, logged: logged))
        }
        let wc = WatchConnectivityManager.shared
        MotionSetDetector.shared.stop()
        wm.end()                      // summary reads sets/volume while still "active"
        isActive = false
        wc.sessionActive = false
        wc.restEndDate = nil
        logged = []
        clearPersisted()
    }

    // MARK: Publish current position into the shared display state

    private func publish() {
        let wc = WatchConnectivityManager.shared
        wc.colorHex = colorHex
        wc.sessionLabel = dayName
        wc.adjustPct = 0
        wc.previousWeightKg = nil
        wc.previousReps = nil
        wc.prBanner = nil
        if exIdx < plan.count {
            let ex = plan[exIdx]
            wc.exerciseName = ex.name
            wc.setLabel = "Set \(setIdx + 1) of \(ex.sets)"
            wc.suggestedWeightKg = ex.weightKg
            wc.suggestedReps = ex.reps
            wc.measurementRaw = ex.measurementRaw
            wc.exerciseProgress = "\(exIdx + 1) of \(plan.count) exercises"
        } else {
            wc.exerciseName = "Plan complete ✓"
            wc.setLabel = "End to save"
            wc.exerciseProgress = "\(plan.count) of \(plan.count) exercises"
        }
    }
}
