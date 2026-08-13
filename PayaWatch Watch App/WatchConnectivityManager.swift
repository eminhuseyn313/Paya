import Foundation
import WatchConnectivity

// MARK: - Watch Connectivity Manager (watchOS side)
// Mirrors the iPhone's active session + water total, and sends set-logged /
// water-added actions back. Uses application context for state (so the watch
// UI reflects the phone even after a relaunch) and messages for actions.

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

    var waterMl: Int = 0
    var waterTargetMl: Int = 2500

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

    func logSet(weightKg: Double, reps: Int) {
        guard WCSession.default.activationState == .activated else { return }

        guard WCSession.default.isReachable else {
            // No point sending — sendMessage would just fail. Tell the
            // user immediately rather than showing a "Logged!" confirmation
            // for a set the phone can't possibly have received.
            lastLogFailed = true
            return
        }

        WCSession.default.sendMessage(
            ["action": "logSet", "weightKg": weightKg, "reps": reps],
            replyHandler: nil,
            errorHandler: { [weak self] _ in
                Task { @MainActor in
                    self?.justLoggedSet = false
                    self?.lastLogFailed = true
                }
            }
        )
        // Session stays active — only the phone's next application-context
        // push (with the next set's suggested weight/reps) changes that.
        // Show a brief confirmation instead of dropping to "no session".
        lastLogFailed = false
        justLoggedSet = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            justLoggedSet = false
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

    func skipRest() {
        guard WCSession.default.activationState == .activated else { return }
        // Clear locally right away — no need to wait on a round trip just
        // to stop showing a countdown the user already dismissed.
        restEndDate = nil
        WCSession.default.sendMessage(["action": "skipRest"], replyHandler: nil, errorHandler: nil)
    }

    func endSession() {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.sendMessage(["action": "endSession"], replyHandler: nil, errorHandler: nil)
    }

    func sendCheckIn(_ payload: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }
        var msg = payload
        msg["action"] = "quickCheckIn"
        WCSession.default.sendMessage(msg, replyHandler: nil, errorHandler: nil)
    }

    // MARK: - Apply incoming context

    private func apply(_ context: [String: Any]) {
        justLoggedSet = false
        lastLogFailed = false
        if let active = context["sessionActive"] as? Bool {
            sessionActive = active
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
        // Present only when both keys are there — WatchSessionManager
        // removes both together once rest ends, so a partial pair would
        // mean stale data, not a real active rest window.
        if let restEnd = context["restEndDate"] as? Date, let restTotal = context["restTotalSeconds"] as? Int {
            restEndDate = restEnd
            restTotalSeconds = restTotal
        } else {
            restEndDate = nil
        }
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
