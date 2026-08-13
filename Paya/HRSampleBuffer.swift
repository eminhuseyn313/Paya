import Foundation
import SwiftUI

@MainActor
@Observable
class HRSampleBuffer {

    static let shared = HRSampleBuffer()

    // Per-set checkpoint tracking (peak/avg since last set completion)
    private(set) var peakSinceCheckpoint: Int? = nil
    private(set) var sumSinceCheckpoint: Double = 0
    private(set) var countSinceCheckpoint: Int = 0

    // Session-wide sample array (one every `sessionSamplingIntervalSeconds`)
    private(set) var sessionSamples: [Int] = []
    let sessionSamplingIntervalSeconds: Int = 5

    private var timer: Timer?
    private var tickCounter: Int = 0

    var avgSinceCheckpoint: Int? {
        guard countSinceCheckpoint > 0 else { return nil }
        return Int(sumSinceCheckpoint / Double(countSinceCheckpoint))
    }

    func startSampling() {
        stopSampling()
        resetCheckpoint()
        sessionSamples = []
        tickCounter = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.sample()
            }
        }
    }

    func stopSampling() {
        timer?.invalidate()
        timer = nil
        resetCheckpoint()
    }

    func resetCheckpoint() {
        peakSinceCheckpoint = nil
        sumSinceCheckpoint = 0
        countSinceCheckpoint = 0
    }

    func clearSessionSamples() {
        sessionSamples = []
        tickCounter = 0
    }

    private func sample() {
        tickCounter += 1
        guard let bpm = LiveHRManager.shared.currentBPM else { return }

        // Update per-set checkpoint
        if let peak = peakSinceCheckpoint {
            if bpm > peak { peakSinceCheckpoint = bpm }
        } else {
            peakSinceCheckpoint = bpm
        }
        sumSinceCheckpoint += Double(bpm)
        countSinceCheckpoint += 1

        // Append to session-wide buffer every `sessionSamplingIntervalSeconds` seconds
        if tickCounter % sessionSamplingIntervalSeconds == 0 {
            sessionSamples.append(bpm)
        }
    }

    func snapshotAndReset() -> (peak: Int?, avg: Int?, current: Int?) {
        let peak = peakSinceCheckpoint
        let avg = avgSinceCheckpoint
        let current = LiveHRManager.shared.currentBPM
        resetCheckpoint()
        return (peak, avg, current)
    }
}
