import SwiftUI

// MARK: - Warm-up Move

struct WarmupMove: Identifiable {
    let id: String
    let name: String
    let duration: String         // "30s" or "10 reps each side"
    let durationSeconds: Int     // for timer/auto-advance, 0 if rep-based
    let instructions: String
    let purpose: String          // what it primes
    let icon: String             // SF Symbol
    let isJointSensitive: Bool
}

// MARK: - Warm-up Routine

struct WarmupRoutine: Identifiable {
    let id: String
    let sessionType: SessionType
    let totalMinutes: Int
    let title: String
    let subtitle: String
    let moves: [WarmupMove]
}
