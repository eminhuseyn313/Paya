import Foundation
import HealthKit
import Observation

// MARK: - Workout engine (watchOS)
//
// Owns the HKWorkoutSession + HKLiveWorkoutBuilder so the watch can show the
// same live metrics as Apple's own Workout app (elapsed time, heart rate,
// active + total calories), save the workout to Apple Health, and relay heart
// rate to the iPhone. Works two ways:
//   • linked  — started because the iPhone began a Paya training session
//   • standalone — started from the watch itself (strength, run, walk, …)

@MainActor
@Observable
final class WorkoutManager: NSObject {

    static let shared = WorkoutManager()

    enum Kind: String, CaseIterable, Identifiable {
        case strength, run, walk, cycle, hiit, other
        var id: String { rawValue }

        var title: String {
            switch self {
            case .strength: return "Strength"
            case .run: return "Run"
            case .walk: return "Walk"
            case .cycle: return "Cycle"
            case .hiit: return "HIIT"
            case .other: return "Other"
            }
        }
        var symbol: String {
            switch self {
            case .strength: return "figure.strengthtraining.traditional"
            case .run: return "figure.run"
            case .walk: return "figure.walk"
            case .cycle: return "figure.outdoor.cycle"
            case .hiit: return "figure.highintensity.intervaltraining"
            case .other: return "figure.mixed.cardio"
            }
        }
        var hkType: HKWorkoutActivityType {
            switch self {
            case .strength: return .traditionalStrengthTraining
            case .run: return .running
            case .walk: return .walking
            case .cycle: return .cycling
            case .hiit: return .highIntensityIntervalTraining
            case .other: return .other
            }
        }
        var isOutdoor: Bool { self == .run || self == .walk || self == .cycle }
    }

    struct Summary {
        let kind: Kind
        let duration: TimeInterval
        let avgHeartRate: Int?
        let activeKcal: Int
        let totalKcal: Int
        let sets: Int?
        let volumeKg: Double?
    }

    // Live state
    var isActive = false
    var isPaused = false
    var kind: Kind = .strength
    var linkedToPhone = false
    var heartRate: Int?
    var activeKcal: Double = 0
    var basalKcal: Double = 0
    var avgHeartRate: Int?
    var lastSummary: Summary?
    var errorMessage: String?

    /// Highest HR since the last logged set, and the peak the current rest
    /// started from — drives the "↓ N bpm" recovery readout between sets.
    var setPeakHR: Int?
    var restStartPeak: Int?
    /// Lowest HR seen since the last set ended — becomes the "rested" level
    /// the NEXT rest is judged against.
    var restFloor: Int?
    var recoveredLevel: Int?

    /// HR drop from the peak at the end of the last set to now (nil if none).
    var currentRecovery: Int? {
        guard let peak = restStartPeak, let hr = heartRate, peak > hr else { return nil }
        return peak - hr
    }

    /// Heuristic, not a clinical threshold: ready once HR has fallen ~65 % of
    /// the way from this set's peak to the lowest level reached in the previous rest.
    var isHRRecovered: Bool {
        guard let peak = restStartPeak, let hr = heartRate else { return false }
        let level = recoveredLevel ?? Int(Double(peak) * 0.75)
        guard peak > level + 5 else { return false }
        return hr <= level + Int(0.35 * Double(peak - level))
    }

    func markSetEnd() {
        recoveredLevel = restFloor ?? recoveredLevel
        restFloor = nil
        restStartPeak = setPeakHR ?? heartRate
        setPeakHR = nil
    }

    var totalKcal: Double { activeKcal + basalKcal }

    /// Read from a view that re-renders on a 1s ticker — the builder isn't
    /// observable, so the clock is pulled rather than pushed.
    var elapsedNow: TimeInterval { builder?.elapsedTime ?? 0 }

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private override init() { super.init() }

    // MARK: Control

    func start(_ kind: Kind, linked: Bool) {
        guard !isActive, HKHealthStore.isHealthDataAvailable() else { return }
        self.kind = kind
        self.linkedToPhone = linked
        errorMessage = nil
        lastSummary = nil

        let hr = HKQuantityType(.heartRate)
        let active = HKQuantityType(.activeEnergyBurned)
        let basal = HKQuantityType(.basalEnergyBurned)
        let toShare: Set<HKSampleType> = [HKQuantityType.workoutType(), active]
        let toRead: Set<HKObjectType> = [hr, active, basal]

        Task { @MainActor in
            do {
                try await healthStore.requestAuthorization(toShare: toShare, read: toRead)
                try await beginSession(kind: kind, basal: basal)
            } catch {
                errorMessage = "Couldn't start the workout. Check Health permissions."
                linkedToPhone = false
            }
        }
    }

    private func beginSession(kind: Kind, basal: HKQuantityType) async throws {
        let config = HKWorkoutConfiguration()
        config.activityType = kind.hkType
        config.locationType = kind.isOutdoor ? .outdoor : .indoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
        let builder = session.associatedWorkoutBuilder()
        let source = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
        source.enableCollection(for: basal, predicate: nil)
        builder.dataSource = source
        session.delegate = self
        builder.delegate = self
        self.session = session
        self.builder = builder

        resetMetrics()
        let start = Date()
        session.startActivity(with: start)
        try await builder.beginCollection(at: start)
        isActive = true
    }

    /// After the app was killed mid-workout, HealthKit can hand the live
    /// workout session back; re-attach to it instead of losing the workout.
    func recoverIfNeeded() {
        guard !isActive, HKHealthStore.isHealthDataAvailable() else { return }
        healthStore.recoverActiveWorkoutSession { [weak self] session, _ in
            guard let session else { return }
            Task { @MainActor in self?.attach(session) }
        }
    }

    private func attach(_ session: HKWorkoutSession) {
        guard !isActive else { return }
        let builder = session.associatedWorkoutBuilder()
        session.delegate = self
        builder.delegate = self
        self.session = session
        self.builder = builder
        kind = Kind.allCases.first { $0.hkType == session.workoutConfiguration.activityType } ?? .other
        isPaused = session.state == .paused
        isActive = true
        OfflineSessionManager.shared.resumeIfPersisted()
    }

    func pause() { session?.pause() }
    func resume() { session?.resume() }

    func end() {
        guard isActive else { return }
        lastSummary = Summary(
            kind: kind,
            duration: elapsedNow,
            avgHeartRate: avgHeartRate,
            activeKcal: Int(activeKcal.rounded()),
            totalKcal: Int(totalKcal.rounded()),
            sets: (linkedToPhone || OfflineSessionManager.shared.isActive) && WatchConnectivityManager.shared.setsCompleted > 0 ? WatchConnectivityManager.shared.setsCompleted : nil,
            volumeKg: (linkedToPhone || OfflineSessionManager.shared.isActive) && WatchConnectivityManager.shared.volumeKg > 0 ? WatchConnectivityManager.shared.volumeKg : nil
        )
        isActive = false
        isPaused = false
        heartRate = nil
        MotionSetDetector.shared.stop()
        session?.end()          // builder is finished in the .ended callback
    }

    func dismissSummary() { lastSummary = nil }

    private func resetMetrics() {
        heartRate = nil; avgHeartRate = nil; setPeakHR = nil; restStartPeak = nil; restFloor = nil; recoveredLevel = nil
        activeKcal = 0; basalKcal = 0
        isPaused = false
    }

    fileprivate func apply(heartRate: Double?, average: Double?, active: Double?, basal: Double?) {
        if let heartRate {
            let bpm = Int(heartRate.rounded())
            self.heartRate = bpm
            setPeakHR = max(setPeakHR ?? 0, bpm)
            restFloor = min(restFloor ?? bpm, bpm)
        }
        if let average { avgHeartRate = Int(average.rounded()) }
        if let active { activeKcal = active }
        if let basal { basalKcal = basal }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from fromState: HKWorkoutSessionState,
                                    date: Date) {
        Task { @MainActor in
            switch toState {
            case .paused: self.isPaused = true
            case .running: self.isPaused = false
            case .ended:
                guard let builder = self.builder else { return }
                do {
                    try await builder.endCollection(at: date)
                    _ = try await builder.finishWorkout()
                } catch {
                    self.errorMessage = "Workout couldn't be saved to Health."
                }
                self.session = nil
                self.builder = nil
            default: break
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = "Workout stopped unexpectedly."
            self.isActive = false
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                                    didCollectDataOf collectedTypes: Set<HKSampleType>) {
        let bpm = HKUnit.count().unitDivided(by: .minute())
        var latest: Double?
        var average: Double?
        var active: Double?
        var basal: Double?

        for type in collectedTypes {
            guard let q = type as? HKQuantityType,
                  let stats = workoutBuilder.statistics(for: q) else { continue }
            switch q.identifier {
            case HKQuantityTypeIdentifier.heartRate.rawValue:
                latest = stats.mostRecentQuantity()?.doubleValue(for: bpm)
                average = stats.averageQuantity()?.doubleValue(for: bpm)
            case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
                active = stats.sumQuantity()?.doubleValue(for: .kilocalorie())
            case HKQuantityTypeIdentifier.basalEnergyBurned.rawValue:
                basal = stats.sumQuantity()?.doubleValue(for: .kilocalorie())
            default: break
            }
        }

        if let latest, latest > 30, latest < 250 {
            WatchConnectivityManager.relayHeartRate(Int(latest.rounded()))
        }
        Task { @MainActor in
            self.apply(heartRate: latest, average: average, active: active, basal: basal)
        }
    }
}
