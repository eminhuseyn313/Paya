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

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Push state to watch

    func pushSessionSnapshot(_ snapshot: WatchSessionSnapshot?) {
        guard WCSession.default.activationState == .activated, WCSession.default.isWatchAppInstalled else { return }
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
        guard WCSession.default.activationState == .activated, WCSession.default.isWatchAppInstalled else { return }
        var context: [String: Any] = currentApplicationContext()
        context["waterMl"] = ml
        context["waterTargetMl"] = WaterStore.dailyTargetMl
        try? WCSession.default.updateApplicationContext(context)
    }

    /// Push the phone's baseline-relative readiness score to the watch so it
    /// doesn't have to fall back on absolute-threshold guesswork (population
    /// averages for HRV/RHR miss personal baselines by a wide margin).
    func pushReadiness(score: Int, band: String, recommendation: String?) {
        guard WCSession.default.activationState == .activated, WCSession.default.isWatchAppInstalled else { return }
        var context: [String: Any] = currentApplicationContext()
        context["readinessScore"] = score
        context["readinessBand"] = band
        context["readinessRecommendation"] = recommendation ?? ""
        context["readinessTimestamp"] = Date()
        try? WCSession.default.updateApplicationContext(context)
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
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            guard let action = message["action"] as? String else { return }
            switch action {
            case "logSet":
                let weight = message["weightKg"] as? Double ?? 0
                let reps = message["reps"] as? Int ?? 0
                WatchSessionManager.shared.onSetLogged?(weight, reps)
            case "addWater":
                let ml = message["ml"] as? Int ?? 0
                WatchSessionManager.shared.onWaterAdded?(ml)
            case "skipRest":
                WatchSessionManager.shared.onSkipRestRequested?()
            case "endSession":
                WatchSessionManager.shared.onEndSessionRequested?()
            case "quickCheckIn":
                let energy = message["energy"] as? Int ?? 2
                let soreness = message["soreness"] as? Int ?? 1
                let hasSymptom = message["hasSymptom"] as? Bool ?? false
                WatchSessionManager.shared.onCheckInReceived?(energy, soreness, hasSymptom)
            default:
                break
            }
        }
    }
}
