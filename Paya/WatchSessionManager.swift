import Foundation
import WatchConnectivity

// MARK: - Watch Session Manager (iOS side)
// Bridges the active training session and water intake to PayaWatch.
// Uses application context for "latest state" mirroring (session snapshot,
// water total) and messages for one-shot actions from the watch (log a set,
// add water) so the watch works even when it's not the frontmost app.

struct WatchSessionSnapshot {
    let exerciseName: String
    let setLabel: String            // "Set 2 of 4"
    let suggestedWeightKg: Double
    let suggestedReps: Int
    let sessionLabel: String
    let colorHex: String
    let measurementRaw: String      // ExerciseMeasurement rawValue-equivalent — see WatchConnectivityManager
    let exerciseProgress: String    // "3 of 7 exercises" — situational awareness without the phone
    // Rest timer — sent as an end date + total duration rather than a
    // live-ticking counter, so the watch can count down locally with no
    // ongoing WCSession traffic (battery-friendly) and stays correct even
    // if a message is dropped.
    let restEndDate: Date?
    let restTotalSeconds: Int?
}

@MainActor
@Observable
final class WatchSessionManager: NSObject {

    static let shared = WatchSessionManager()

    /// Set by TrainViewModel; invoked when the watch logs a completed set.
    var onSetLogged: ((Double, Int) -> Void)?
    /// Set by whoever owns water tracking; invoked when the watch adds water.
    var onWaterAdded: ((Int) -> Void)?
    /// Set by TrainViewModel; invoked when the watch asks to skip the rest timer.
    var onSkipRestRequested: (() -> Void)?
    /// Set by TrainViewModel; invoked when the watch asks to end the session.
    var onEndSessionRequested: (() -> Void)?
    /// Set by ContentView; invoked when the watch sends a quick check-in.
    var onCheckInReceived: ((_ energy: Int, _ soreness: Int, _ hasSymptom: Bool) -> Void)?

    // MARK: - Live heart rate from watch

    /// Latest heart rate received from the watch companion app (updated in
    /// real-time when the watch streams HR during workouts or background
    /// monitoring). This supplements BLE HR — whichever source updates more
    /// recently wins in the UI.
    var watchHeartRate: Int? = nil
    /// When the last watch HR sample arrived — used for freshness checks.
    var watchHeartRateTimestamp: Date? = nil

    // MARK: - Connection status (observable)

    /// Whether an Apple Watch is paired to this iPhone.
    var isWatchPaired: Bool = false
    /// Whether the paired watch's Paya companion app is installed.
    var isWatchAppInstalled: Bool = false
    /// Whether the watch is currently reachable (on-wrist, in range, etc.).
    var isWatchReachable: Bool = false
    /// True once WCSession activation completes — until then, pairing
    /// state is unknown and the UI should not claim "not connected."
    var hasActivated: Bool = false

    /// Human-readable connection status for the UI.
    var connectionLabel: String {
        guard WCSession.isSupported() else { return "Not supported" }
        guard hasActivated else { return "Checking…" }
        if !isWatchPaired { return "No watch paired" }
        // Show reachability even without companion app — the watch is
        // physically there and HealthKit syncs HR/HRV/etc. regardless.
        if isWatchReachable && isWatchAppInstalled { return "Connected" }
        if isWatchReachable && !isWatchAppInstalled { return "Watch connected · install Paya for live HR" }
        if isWatchAppInstalled { return "Paired · not on wrist" }
        return "Paired · HealthKit syncing"
    }

    /// Whether the watch is paired at all — used for UI indicators.
    /// Previously required `isWatchAppInstalled`, which made the UI
    /// claim "not connected" even when the watch was on the user's
    /// wrist — HealthKit data still syncs without the companion app.
    var isConnected: Bool {
        hasActivated && isWatchPaired
    }

    /// Whether the companion app is installed and two-way messaging
    /// (session push, set logging from watch) is available.
    var isFullyConnected: Bool {
        hasActivated && isWatchPaired && isWatchAppInstalled
    }

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Refresh pairing state from WCSession — safe to call anytime.
    func refreshStatus() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        isWatchPaired = WCSession.default.isPaired
        isWatchAppInstalled = WCSession.default.isWatchAppInstalled
        isWatchReachable = WCSession.default.isReachable
    }

    // MARK: - Push state to watch

    func pushSessionSnapshot(_ snapshot: WatchSessionSnapshot?) {
        guard isFullyConnected, WCSession.default.activationState == .activated else {
            // Queue for retry when connectivity returns — only the latest
            // snapshot matters (older ones are stale by definition).
            if let snapshot { pendingSnapshot = snapshot }
            return
        }
        pendingSnapshot = nil
        var context: [String: Any] = currentApplicationContext()
        if let snapshot {
            context["sessionActive"] = true
            context["exerciseName"] = snapshot.exerciseName
            context["setLabel"] = snapshot.setLabel
            context["suggestedWeightKg"] = snapshot.suggestedWeightKg
            context["suggestedReps"] = snapshot.suggestedReps
            context["sessionLabel"] = snapshot.sessionLabel
            context["colorHex"] = snapshot.colorHex
            context["measurementRaw"] = snapshot.measurementRaw
            context["exerciseProgress"] = snapshot.exerciseProgress
            // WCSession application context is plist-serialized — Date
            // survives, but only set the keys when there's an active rest
            // window so a stale rest end-date doesn't leak into the next
            // exercise's snapshot.
            if let restEnd = snapshot.restEndDate, let restTotal = snapshot.restTotalSeconds {
                context["restEndDate"] = restEnd
                context["restTotalSeconds"] = restTotal
            } else {
                context.removeValue(forKey: "restEndDate")
                context.removeValue(forKey: "restTotalSeconds")
            }
        } else {
            context["sessionActive"] = false
        }
        try? WCSession.default.updateApplicationContext(context)
    }

    func pushWaterTotal(_ ml: Int) {
        guard isFullyConnected, WCSession.default.activationState == .activated else {
            pendingWaterMl = ml
            return
        }
        pendingWaterMl = nil
        var context: [String: Any] = currentApplicationContext()
        context["waterMl"] = ml
        context["waterTargetMl"] = WaterStore.dailyTargetMl
        try? WCSession.default.updateApplicationContext(context)
    }

    /// Push the phone's baseline-relative readiness score to the watch so it
    /// doesn't have to fall back on absolute-threshold guesswork (population
    /// averages for HRV/RHR miss personal baselines by a wide margin).
    func pushReadiness(score: Int, band: String, recommendation: String?) {
        guard isFullyConnected, WCSession.default.activationState == .activated else {
            pendingReadiness = (score, band, recommendation)
            return
        }
        pendingReadiness = nil
        var context: [String: Any] = currentApplicationContext()
        context["readinessScore"] = score
        context["readinessBand"] = band
        context["readinessRecommendation"] = recommendation ?? ""
        context["readinessTimestamp"] = Date()
        try? WCSession.default.updateApplicationContext(context)
    }

    // MARK: - Pending push queue

    /// Holds the most recent snapshot that failed to send (connectivity down).
    /// Retried automatically when reachability changes. Only the latest
    /// snapshot matters — older ones are stale by definition.
    private var pendingSnapshot: WatchSessionSnapshot? = nil
    private var pendingWaterMl: Int? = nil
    private var pendingReadiness: (score: Int, band: String, recommendation: String?)? = nil

    /// Retry any queued pushes — called when reachability flips to true.
    private func flushPendingPushes() {
        guard isFullyConnected, WCSession.default.activationState == .activated else { return }
        if let snapshot = pendingSnapshot {
            pendingSnapshot = nil
            pushSessionSnapshot(snapshot)
        }
        if let ml = pendingWaterMl {
            pendingWaterMl = nil
            pushWaterTotal(ml)
        }
        if let r = pendingReadiness {
            pendingReadiness = nil
            pushReadiness(score: r.score, band: r.band, recommendation: r.recommendation)
        }
    }

    private func currentApplicationContext() -> [String: Any] {
        WCSession.default.activationState == .activated
            ? WCSession.default.applicationContext
            : [:]
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            WatchSessionManager.shared.hasActivated = true
            WatchSessionManager.shared.refreshStatus()
            // Flush anything queued before activation completed
            WatchSessionManager.shared.flushPendingPushes()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // Multi-watch switch: the old watch is disconnecting. Update status
        // so the UI reflects the transient state (Apple docs: this is brief,
        // followed by sessionDidDeactivate).
        Task { @MainActor in
            WatchSessionManager.shared.isWatchReachable = false
        }
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Multi-watch handoff complete — re-activate so the new watch's
        // delegate callbacks start flowing (Apple docs requirement).
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            WatchSessionManager.shared.refreshStatus()
            // When the watch comes back in range, flush any queued pushes
            // so the watch gets the latest state without user intervention.
            if session.isReachable {
                WatchSessionManager.shared.flushPendingPushes()
            }
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            WatchSessionManager.shared.refreshStatus()
        }
    }

    // MARK: - Incoming messages (fire-and-forget)

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            WatchSessionManager.shared.handleIncomingMessage(message)
        }
    }

    // MARK: - Incoming messages (reply expected)
    // If the watch ever sends with a replyHandler, WCSession requires this
    // overload — without it the watch times out after 60s and the user sees
    // a connectivity error. Even if we don't have meaningful reply data, we
    // must call the handler to close the channel.

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            WatchSessionManager.shared.handleIncomingMessage(message)
        }
        replyHandler(["status": "ok"])
    }

    // MARK: - Incoming application context
    // The watch can push context back to the phone (e.g. last workout HR
    // summary, complication state). Without this delegate method, those
    // updates silently vanish and the watch-side `updateApplicationContext`
    // call appears to succeed from the watch's perspective.

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            // Fallback HR delivery path: the watch prefers `sendMessage` for
            // real-time BPM (handled in `handleIncomingMessage` below), but
            // that requires the phone to be reachable. When it isn't — phone
            // locked/backgrounded mid-set, the common case during an actual
            // lift — the watch pushes the latest BPM via application context
            // instead, which doesn't require reachability. Without this
            // path, HR only ever registered for whichever set happened
            // before the phone stopped being reachable.
            if let bpm = applicationContext["watchHR"] as? Int, bpm > 30 && bpm < 250 {
                WatchSessionManager.shared.watchHeartRate = bpm
                WatchSessionManager.shared.watchHeartRateTimestamp = Date()
            }
        }
    }
}

// MARK: - Message dispatch (shared by fire-and-forget + reply-handler paths)

extension WatchSessionManager {
    fileprivate func handleIncomingMessage(_ message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        switch action {
        case "logSet":
            let weight = message["weightKg"] as? Double ?? 0
            let reps = message["reps"] as? Int ?? 0
            onSetLogged?(weight, reps)
        case "addWater":
            let ml = message["ml"] as? Int ?? 0
            onWaterAdded?(ml)
        case "skipRest":
            onSkipRestRequested?()
        case "endSession":
            onEndSessionRequested?()
        case "quickCheckIn":
            let energy = message["energy"] as? Int ?? 2
            let soreness = message["soreness"] as? Int ?? 1
            let hasSymptom = message["hasSymptom"] as? Bool ?? false
            onCheckInReceived?(energy, soreness, hasSymptom)
        case "heartRate":
            // Watch companion streams HR samples — Apple Watch writes HR
            // every ~5s during workouts, ~10min passively. This real-time
            // bridge avoids the HealthKit sync delay (up to 15 min).
            if let bpm = message["bpm"] as? Int, bpm > 30 && bpm < 250 {
                watchHeartRate = bpm
                watchHeartRateTimestamp = Date()
            }
        default:
            break
        }
    }
}
