import Foundation
import WatchConnectivity

// MARK: - Watch Connectivity Manager (watchOS side)
// Mirrors the iPhone's active session + water total, and sends set-logged /
// water-added actions back. Uses application context for state (so the watch
// UI reflects the phone even after a relaunch) and messages for actions.
//
// NEW: starts an HKWorkoutSession when the phone's training session begins,
// streams live heart rate samples back via sendMessage so the phone's
// LiveHRManager has real-time BPM during exercises.

@MainActor
@Observable
final class WatchConnectivityManager: NSObject {

    static let shared = WatchConnectivityManager()

    var sessionActive: Bool = false
    var exerciseName: String = ""
    var setLabel: String = ""
    var suggestedWeightKg: Double = 20
    var suggestedReps: Int = 10
    var sessionLabel: String = ""
    var colorHex: String = "2563EB"
    /// Mirrors ExerciseMeasurement's rawValue from the phone target (not
    /// shared as a type across targets — plain string comparison instead of
    /// pulling the whole file into the watch target for one enum).
    var measurementRaw: String = "weightedReps"
    var showsWeightField: Bool { measurementRaw != "bodyweightReps" && measurementRaw != "timed" }
    var isTimed: Bool { measurementRaw == "timed" }

    // Health context pushed from the phone (all empty until the phone has real data)
    struct WatchMed: Identifiable { var id: String; var name: String; var dose: String; var taken: Bool }
    var flareLevel: String = ""
    var flareWorsening = false
    var flareSummary: String = ""
    var briefing: String = ""
    var postWorkoutProteinG: Int = 0
    var meds: [WatchMed] = []
    /// Shown as a banner (with haptic) once per day when the 24–48 h flare forecast worsens.
    var flareAlertBanner: String?
    private var lastSeenFlareAlert: String? = UserDefaults.standard.string(forKey: "paya_watch_last_flare_alert")

    var prefersLbs: Bool = false
    var maxHR: Int? = nil
    var previousWeightKg: Double? = nil
    var previousReps: Int? = nil
    var setsCompleted: Int = 0
    var volumeKg: Double = 0
    var adjustPct: Int = 0
    /// Personal auto-detect correction computed on the phone from real logged sets.
    var repOffset: Int = 0
    /// Shown briefly when the phone reports the set just logged was a personal record.
    var prBanner: String?
    private var lastSeenPRId: String?
    var isFlareDay: Bool = false
    var flareEnabled: Bool = false

    var waterMl: Int = 0
    var waterTargetMl: Int = 2500

    // Readiness score pushed from the phone's baseline-relative
    // ReadinessEngine — preferred over local absolute-threshold guesswork.
    var phoneReadinessScore: Int? = nil
    var phoneReadinessBand: String? = nil
    var phoneReadinessRecommendation: String? = nil
    var phoneReadinessTimestamp: Date? = nil

    // Rest timer — end date + total duration from the phone, counted down
    // locally by SessionView (against its own ticking `now`) so there's no
    // ongoing WCSession traffic just to keep a clock running.
    var restEndDate: Date? = nil
    var restTotalSeconds: Int = 0
    var exerciseProgress: String = ""

    /// Brief "Logged!" confirmation while we wait for the phone's next-set
    /// snapshot to arrive — previously the UI dropped straight to "No active
    /// session" after every single set, which read as the whole session
    /// ending rather than one set being recorded.
    var justLoggedSet: Bool = false

    /// Set the instant a logSet send genuinely fails to reach the phone
    /// (out of range, phone locked away, Bluetooth/Wi-Fi dropped — all
    /// realistic mid-gym scenarios) so the watch never shows a false
    /// "Logged!" confirmation for a set the phone never received. Cleared
    /// automatically the next time the phone's application context arrives,
    /// confirming the link is back.
    var lastLogFailed: Bool = false

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Send actions to phone

    /// Sets are sent live when the phone is reachable; otherwise (or if the
    /// live send fails) they go through `transferUserInfo`, which the system
    /// queues and delivers in order whenever the phone is next available —
    /// even hours later. Each set carries a unique id so a set that arrives
    /// both ways is only applied once on the phone.
    func logSet(weightKg: Double, reps: Int, detected: Int? = nil, hrRecovery: Int? = nil) {
        if OfflineSessionManager.shared.isActive {
            OfflineSessionManager.shared.logSet(weightKg: weightKg, reps: reps)
            justLoggedSet = true
            Task { try? await Task.sleep(for: .seconds(1.5)); justLoggedSet = false }
            return
        }
        guard WCSession.default.activationState == .activated else { return }
        var payload: [String: Any] = [
            "action": "logSet", "weightKg": weightKg, "reps": reps,
            "setId": UUID().uuidString,
        ]
        if let detected { payload["detectedReps"] = detected }
        if let hrRecovery { payload["hrRecovery"] = hrRecovery }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: { [weak self] _ in
                WCSession.default.transferUserInfo(payload)
                Task { @MainActor in self?.lastLogFailed = true }
            })
            lastLogFailed = false
        } else {
            WCSession.default.transferUserInfo(payload)
            lastLogFailed = true      // "saved, will sync" — nothing is lost
        }
        justLoggedSet = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            justLoggedSet = false
        }
    }

    func requestWarmups() {
        guard WCSession.default.activationState == .activated, WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["action": "addWarmups"], replyHandler: nil, errorHandler: nil)
    }

    func sendNote(_ text: String) {
        guard WCSession.default.activationState == .activated else { return }
        let payload: [String: Any] = ["action": "exerciseNote", "text": text]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: { _ in
                WCSession.default.transferUserInfo(payload)
            })
        } else {
            WCSession.default.transferUserInfo(payload)
        }
    }

    func addWater(_ ml: Int) {
        guard WCSession.default.activationState == .activated else { return }
        waterMl += ml
        WCSession.default.sendMessage(
            ["action": "addWater", "ml": ml],
            replyHandler: nil,
            errorHandler: { [weak self] _ in
                // Best-effort optimistic update above already happened;
                // roll it back since the phone never actually got it.
                Task { @MainActor in
                    self?.waterMl -= ml
                }
            }
        )
    }

    func setFlareDay(_ value: Bool) {
        guard WCSession.default.activationState == .activated else { return }
        isFlareDay = value   // optimistic; the phone's next snapshot confirms
        WCSession.default.sendMessage(["action": "setFlareDay", "value": value], replyHandler: nil, errorHandler: { [weak self] _ in
            Task { @MainActor in self?.isFlareDay = !value }
        })
    }

    func sendOfflineSession(_ payload: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.transferUserInfo(payload)   // delivered whenever the phone is next available
    }

    func skipRest() {
        if OfflineSessionManager.shared.isActive { OfflineSessionManager.shared.skipRest(); return }
        guard WCSession.default.activationState == .activated else { return }
        // Clear locally right away — no need to wait on a round trip just
        // to stop showing a countdown the user already dismissed.
        restEndDate = nil
        WCSession.default.sendMessage(["action": "skipRest"], replyHandler: nil, errorHandler: nil)
    }

    func endSession() {
        if OfflineSessionManager.shared.isActive { OfflineSessionManager.shared.finish(); return }
        // End the watch workout right away (it saves to Health) regardless of
        // phone reachability, then tell the phone to wrap up its session.
        if sessionActive { suppressAutoStart = true }
        WorkoutManager.shared.end()
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.sendMessage(["action": "endSession"], replyHandler: nil, errorHandler: nil)
    }

    func sendCheckIn(_ payload: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }
        var msg = payload
        msg["action"] = "quickCheckIn"
        WCSession.default.sendMessage(msg, replyHandler: nil, errorHandler: nil)
    }

    // MARK: - Live HR relay
    //
    // WorkoutManager (HKWorkoutSession + live builder) produces the heart-rate
    // samples; this just forwards them to the phone. `sendMessage` needs the
    // phone to be reachable; when it isn't (locked/pocketed mid-set) the BPM
    // goes via application context, which doesn't, so HR never goes dark.

    nonisolated static func relayHeartRate(_ bpm: Int) {
        guard WCSession.default.activationState == .activated else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(
                ["action": "heartRate", "bpm": bpm],
                replyHandler: nil,
                errorHandler: { _ in pushHRViaApplicationContext(bpm: bpm) }
            )
        } else {
            pushHRViaApplicationContext(bpm: bpm)
        }
    }

    private nonisolated static func pushHRViaApplicationContext(bpm: Int) {
        var context = WCSession.default.applicationContext
        context["watchHR"] = bpm
        try? WCSession.default.updateApplicationContext(context)
    }

    /// True after the user ends a phone-linked workout from the watch, until
    /// the phone confirms its session is over — stops a late context push
    /// from silently restarting the workout.
    private var suppressAutoStart = false

    private func startWorkoutForHR() {
        guard !suppressAutoStart else { return }
        if WorkoutManager.shared.isActive {
            WorkoutManager.shared.linkedToPhone = true   // adopt a workout already running
        } else {
            WorkoutManager.shared.start(.strength, linked: true)
        }
    }

    private func stopWorkoutForHR() {
        WorkoutManager.shared.end()
    }

    // MARK: - Start today's session from the watch

    enum StartResult { case idle, starting, started, needsPhone }
    var startResult: StartResult = .idle

    func requestStartSession() {
        guard WCSession.default.activationState == .activated, WCSession.default.isReachable else {
            startResult = .needsPhone
            return
        }
        startResult = .starting
        WCSession.default.sendMessage(
            ["action": "startSession"],
            replyHandler: { [weak self] reply in
                let ok = (reply["status"] as? String) == "started"
                Task { @MainActor in self?.startResult = ok ? .started : .needsPhone }
            },
            errorHandler: { [weak self] _ in
                Task { @MainActor in self?.startResult = .needsPhone }
            }
        )
    }

    // MARK: - Apply incoming context

    private func applyHealth(_ c: [String: Any]) {
        flareLevel = c["flareLevel"] as? String ?? flareLevel
        flareWorsening = c["flareWorsening"] as? Bool ?? flareWorsening
        flareSummary = c["flareSummary"] as? String ?? flareSummary
        briefing = c["briefing"] as? String ?? briefing
        postWorkoutProteinG = c["postWorkoutProteinG"] as? Int ?? postWorkoutProteinG
        if let rows = c["meds"] as? [[String: Any]] {
            meds = rows.compactMap { r in
                guard let id = r["id"] as? String, let name = r["name"] as? String else { return nil }
                return WatchMed(id: id, name: name, dose: r["dose"] as? String ?? "", taken: r["taken"] as? Bool ?? false)
            }
        }
        if let id = c["flareAlertId"] as? String, !id.isEmpty, id != lastSeenFlareAlert {
            lastSeenFlareAlert = id
            UserDefaults.standard.set(id, forKey: "paya_watch_last_flare_alert")
            flareAlertBanner = flareSummary.isEmpty ? "Flare risk is rising over the next 24–48 h." : flareSummary
        }
    }

    func markMedTaken(_ id: String) {
        guard let i = meds.firstIndex(where: { $0.id == id }), !meds[i].taken else { return }
        meds[i].taken = true   // optimistic; the phone confirms with its next push
        let payload: [String: Any] = ["action": "medTaken", "id": id]
        guard WCSession.default.activationState == .activated else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: { _ in
                WCSession.default.transferUserInfo(payload)
            })
        } else {
            WCSession.default.transferUserInfo(payload)
        }
    }

    func logSymptomFromAlert() {
        sendCheckIn(["energy": 2, "soreness": 1, "hasSymptom": true])
        flareAlertBanner = nil
    }

    private func apply(_ context: [String: Any]) {
        applyHealth(context)
        OfflineSessionManager.shared.loadPlan(from: context)
        if OfflineSessionManager.shared.isActive {
            // A local offline session owns the display; only keep preferences fresh.
            prefersLbs = context["prefersLbs"] as? Bool ?? prefersLbs
            maxHR = context["maxHR"] as? Int ?? maxHR
            repOffset = context["repOffset"] as? Int ?? repOffset
            waterMl = context["waterMl"] as? Int ?? waterMl
            return
        }
        justLoggedSet = false
        lastLogFailed = false
        let wasActive = sessionActive
        if let active = context["sessionActive"] as? Bool {
            sessionActive = active
        }

        // Start/stop HR workout session based on phone's training state
        if sessionActive && !wasActive {
            startWorkoutForHR()
        } else if !sessionActive {
            suppressAutoStart = false
            if wasActive { stopWorkoutForHR() }
        }
        exerciseName = context["exerciseName"] as? String ?? exerciseName
        setLabel = context["setLabel"] as? String ?? setLabel
        suggestedWeightKg = context["suggestedWeightKg"] as? Double ?? suggestedWeightKg
        suggestedReps = context["suggestedReps"] as? Int ?? suggestedReps
        sessionLabel = context["sessionLabel"] as? String ?? sessionLabel
        colorHex = context["colorHex"] as? String ?? colorHex
        measurementRaw = context["measurementRaw"] as? String ?? measurementRaw
        waterMl = context["waterMl"] as? Int ?? waterMl
        waterTargetMl = context["waterTargetMl"] as? Int ?? waterTargetMl
        exerciseProgress = context["exerciseProgress"] as? String ?? exerciseProgress
        prefersLbs = context["prefersLbs"] as? Bool ?? prefersLbs
        maxHR = context["maxHR"] as? Int ?? maxHR
        previousWeightKg = context["previousWeightKg"] as? Double
        previousReps = context["previousReps"] as? Int
        setsCompleted = context["setsCompleted"] as? Int ?? setsCompleted
        if let id = context["prId"] as? String, id != lastSeenPRId, let text = context["prText"] as? String {
            lastSeenPRId = id
            prBanner = text
        }
        adjustPct = context["adjustPct"] as? Int ?? 0
        repOffset = context["repOffset"] as? Int ?? repOffset
        isFlareDay = context["isFlareDay"] as? Bool ?? isFlareDay
        flareEnabled = context["flareEnabled"] as? Bool ?? flareEnabled
        volumeKg = context["volumeKg"] as? Double ?? volumeKg
        // Present only when both keys are there — WatchSessionManager
        // removes both together once rest ends, so a partial pair would
        // mean stale data, not a real active rest window.
        if let restEnd = context["restEndDate"] as? Date, let restTotal = context["restTotalSeconds"] as? Int {
            restEndDate = restEnd
            restTotalSeconds = restTotal
        } else {
            restEndDate = nil
        }

        // Readiness from the phone's ReadinessEngine (baseline-relative)
        if let score = context["readinessScore"] as? Int {
            phoneReadinessScore = score
            phoneReadinessBand = context["readinessBand"] as? String
            phoneReadinessRecommendation = context["readinessRecommendation"] as? String
            phoneReadinessTimestamp = context["readinessTimestamp"] as? Date
        }

        // Mirror into the App Group so the watch face complication (a
        // separate process — can't read this @Observable state directly)
        // has something fresh to show. Cheap to call on every context
        // update; the write itself is a small UserDefaults set.
        let nextSetText: String? = sessionActive && !exerciseName.isEmpty
            ? exerciseName + (showsWeightField ? " · \(String(format: "%.0f", suggestedWeightKg * (prefersLbs ? 2.20462262 : 1)))\(prefersLbs ? "lb" : "kg")×\(suggestedReps)" : " · \(suggestedReps)")
            : nil
        ComplicationSnapshotWriter.write(
            readinessScore: phoneReadinessScore,
            readinessBand: phoneReadinessBand,
            sessionLabel: sessionLabel.isEmpty ? nil : sessionLabel,
            waterMl: waterMl,
            waterTargetMl: waterTargetMl,
            nextSetText: nextSetText,
            briefing: briefing.isEmpty ? nil : briefing
        )
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if !session.applicationContext.isEmpty {
                WatchConnectivityManager.shared.apply(session.applicationContext)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            WatchConnectivityManager.shared.apply(applicationContext)
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {}
    #endif
}
