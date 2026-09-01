import Foundation
import WatchConnectivity
import HealthKit

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

    /// Queued set that failed to send — retried when reachability returns.
    /// Only one pending set at a time (the most recent failed one).
    private var pendingSet: (weightKg: Double, reps: Int)? = nil

    func logSet(weightKg: Double, reps: Int) {
        guard WCSession.default.activationState == .activated else { return }

        guard WCSession.default.isReachable else {
            // Queue for retry when phone comes back in range.
            pendingSet = (weightKg, reps)
            lastLogFailed = true
            return
        }

        pendingSet = nil
        WCSession.default.sendMessage(
            ["action": "logSet", "weightKg": weightKg, "reps": reps],
            replyHandler: nil,
            errorHandler: { [weak self] _ in
                Task { @MainActor in
                    self?.justLoggedSet = false
                    self?.lastLogFailed = true
                    // Queue for retry — the phone was reachable but the
                    // send failed (Bluetooth hiccup, phone locked, etc.)
                    self?.pendingSet = (weightKg, reps)
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

    /// Flush queued set when the phone becomes reachable again.
    fileprivate func flushPendingSet() {
        guard let set = pendingSet else { return }
        pendingSet = nil
        logSet(weightKg: set.weightKg, reps: set.reps)
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

    // MARK: - Live HR Streaming via HKWorkoutSession
    //
    // When the phone starts a training session, we start an HKWorkoutSession
    // on the watch to enable continuous wrist HR sampling (~1 Hz during
    // workouts, vs ~10 min passively — Apple Watch Technology Overview,
    // Apple 2024). We then run an anchored-object query on HKQuantityType
    // .heartRate and relay each sample to the phone via sendMessage.
    //
    // This fixes the "heartbeat not working during session" bug — the phone's
    // LiveHRManager already handles incoming ["action": "heartRate", "bpm": N]
    // messages at WatchSessionManager:328, but the watch side was never
    // starting a workout or sending those messages.

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var hrQuery: HKAnchoredObjectQuery?

    private func startWorkoutForHR() {
        // Only start once
        guard workoutSession == nil else { return }
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        healthStore.requestAuthorization(toShare: [HKQuantityType.workoutType()], read: [hrType]) { [weak self] ok, _ in
            guard ok else { return }
            Task { @MainActor in
                self?.beginWorkoutSession()
            }
        }
    }

    private func beginWorkoutSession() {
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)

            self.workoutSession = session
            self.workoutBuilder = builder

            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { _, _ in }

            // Start anchored query for live HR
            startHRQuery()
        } catch {
            // Workout session failed — log but don't crash
            print("[WatchHR] Failed to start workout session: \(error)")
        }
    }

    private func startHRQuery() {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let query = HKAnchoredObjectQuery(
            type: hrType,
            predicate: HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate),
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processHRSamples(samples)
        }
        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processHRSamples(samples)
        }
        healthStore.execute(query)
        self.hrQuery = query
    }

    private nonisolated func processHRSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else { return }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        for sample in quantitySamples {
            let bpm = Int(sample.quantity.doubleValue(for: bpmUnit))
            guard bpm > 30 && bpm < 250 else { continue }
            // Send to phone — best-effort, no error handler needed
            if WCSession.default.isReachable {
                WCSession.default.sendMessage(
                    ["action": "heartRate", "bpm": bpm],
                    replyHandler: nil,
                    errorHandler: nil
                )
            }
        }
    }

    private func stopWorkoutForHR() {
        if let query = hrQuery {
            healthStore.stop(query)
            hrQuery = nil
        }
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: Date()) { [weak self] _, _ in
            self?.workoutBuilder?.finishWorkout { _, _ in }
        }
        workoutSession = nil
        workoutBuilder = nil
    }

    // MARK: - Apply incoming context

    private func apply(_ context: [String: Any]) {
        justLoggedSet = false
        lastLogFailed = false
        let wasActive = sessionActive
        if let active = context["sessionActive"] as? Bool {
            sessionActive = active
        }

        // Start/stop HR workout session based on phone's training state
        if sessionActive && !wasActive {
            startWorkoutForHR()
        } else if !sessionActive && wasActive {
            stopWorkoutForHR()
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

        // Readiness from the phone's ReadinessEngine (baseline-relative)
        if let score = context["readinessScore"] as? Int {
            phoneReadinessScore = score
            phoneReadinessBand = context["readinessBand"] as? String
            phoneReadinessRecommendation = context["readinessRecommendation"] as? String
            phoneReadinessTimestamp = context["readinessTimestamp"] as? Date
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

    /// Fires when the phone toggles between reachable/unreachable — e.g.
    /// user walks out of Bluetooth range then comes back. Retry any queued
    /// set log so the user doesn't have to manually re-tap.
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            if session.isReachable {
                WatchConnectivityManager.shared.flushPendingSet()
            }
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {}
    #endif
}
