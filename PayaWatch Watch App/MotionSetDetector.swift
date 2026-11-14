import Foundation
import CoreMotion
import Observation
import WatchKit

// MARK: - MotionSetDetector
// Streams wrist motion (25 Hz) while a phone-linked strength session is
// running and feeds RepDetector. When a set ends it publishes a SUGGESTED rep
// count — the user still confirms with Log Set. Beta: off-switch on Controls.

@MainActor
@Observable
final class MotionSetDetector {

    static let shared = MotionSetDetector()

    var detectedReps: Int?
    private(set) var isRunning = false

    /// Tempo taps while a set is in progress: 0 = off, otherwise seconds per tap
    /// (a pacing metronome for the lift/lower cadence, e.g. 3 = a tap every 3 s).
    var tempoSeconds: Int {
        didSet { UserDefaults.standard.set(tempoSeconds, forKey: "paya_tempo_seconds") }
    }
    private var lastTap = Date.distantPast

    var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "paya_auto_set_detection")
            if !enabled { stop() }
        }
    }

    /// True while resting / not on the log page — samples are dropped.
    var suspended = false {
        didSet { if suspended { detector.reset() } }
    }

    private let motion = CMMotionManager()
    private var detector = RepDetector(sampleRate: 25)

    private init() {
        enabled = UserDefaults.standard.object(forKey: "paya_auto_set_detection") as? Bool ?? true
        tempoSeconds = UserDefaults.standard.integer(forKey: "paya_tempo_seconds")
    }

    func start() {
        guard enabled, !isRunning, motion.isDeviceMotionAvailable else { return }
        detector.reset()
        isRunning = true
        motion.deviceMotionUpdateInterval = 1.0 / 25.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            let a = data.userAcceleration
            MainActor.assumeIsolated { self?.handle(a.x, a.y, a.z) }
        }
    }

    func stop() {
        guard isRunning else { return }
        motion.stopDeviceMotionUpdates()
        isRunning = false
        detector.reset()
        detectedReps = nil
    }

    func consume() { detectedReps = nil }

    private func handle(_ x: Double, _ y: Double, _ z: Double) {
        guard !suspended else { return }
        if tempoSeconds > 0, detector.isInSet, Date().timeIntervalSince(lastTap) >= Double(tempoSeconds) {
            lastTap = Date()
            WKInterfaceDevice.current().play(.click)
        }
        if let result = detector.feed(x, y, z) {
            detectedReps = result.reps
            WKInterfaceDevice.current().play(.notification)
        }
    }
}
