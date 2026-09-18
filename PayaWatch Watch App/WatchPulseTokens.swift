import SwiftUI

// Pulse design tokens for watchOS — a compact subset of the phone's
// PulseDesignSystem.swift, tuned for the smaller display.

enum WatchPulse {
    static let canvas = Color(red: 0.04, green: 0.055, blue: 0.1)
    static let surface = Color(red: 0.08, green: 0.095, blue: 0.14)
    static let surfaceElevated = Color(red: 0.12, green: 0.135, blue: 0.18)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.35)

    static let positive = Color(hex: "059669")
    static let warning = Color(hex: "F59E0B")
    static let critical = Color(hex: "DC2626")
    static let energy = Color(hex: "F59E0B")
    static let hydration = Color(hex: "0891B2")
    static let vitals = Color(hex: "EC4899")
    static let recovery = Color(hex: "8B5CF6")
    static let ai = Color(hex: "818CF8")
}
