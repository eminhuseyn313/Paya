import SwiftUI

// MARK: - Design System
//
// A real, named point of view instead of ad-hoc per-screen styling: every
// card in the app so far has independently chosen its own corner radius
// (10, 12, 14 all appear), padding, and animation (or lack of one) — which
// is exactly what reads as "boring/generic" at scale, since nothing ties
// screens together. This isn't a full re-theme (that would mean touching
// every screen at once, high risk with no visual feedback loop available
// mid-session) — it's the shared vocabulary new and updated screens should
// use, piloted here on the Dashboard first.
//
// Reference points: Whoop/Oura's generous corner radii, restrained color
// (saturated color reserved for status/hero metrics, not every icon),
// spring-animated number changes instead of instant snaps, and a real
// weight contrast between hero numbers and supporting text.

// MARK: - Design System (v2 — Adaptive Depth Redesign)
//
// v1: 7 semantic colors, 20pt card radius, HeroNumberText at 34pt.
// v2: 5 semantic colors (removed cyan/brown — too many to learn in one
//     session, WHOOP succeeds with 3). Card radius tightened to 16pt for
//     a more mature feel. Hero metric enlarged to 48pt for arm's-length
//     readability (WHOOP benchmark). New reusable components: SummaryRow,
//     StatusStrip, ContextCard, PillPicker.
//
// Color philosophy (5 roles, each learnable in one session):
//   Blue    → Primary action, interactive elements
//   Green   → On-track, met goals, positive deltas
//   Amber   → Attention, moderate readiness, approaching limits
//   Red     → Action needed, low readiness, flare risk
//   Purple  → AI/premium features
//
// Backward compat: `info` and `earth` remain as typealiases so existing
// card files compile without mass refactoring. New screens should use
// the 5 canonical roles only.

enum PayaSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48  // v2: section separation in Trends tab
}

enum PayaRadius {
    static let compact: CGFloat = 8    // v2: inline data cells
    static let chip: CGFloat = 12
    static let button: CGFloat = 14
    static let section: CGFloat = 16
    static let card: CGFloat = 16      // v2: tightened from 20 — less bubbly, more mature
}

/// Named palette — 5 semantic roles. Every hue carries a meaning the user
/// can learn in one session: action (blue), on-track (green), watch (amber),
/// act (red), AI (purple).
enum PayaColor {
    static let primary   = Color(hex: "2563EB")   // Blue — navigation, interactive
    static let positive  = Color(hex: "059669")    // Green — on-track, healthy
    static let warning   = Color(hex: "D97706")    // Amber — caution, watch (darkened for contrast)
    static let critical  = Color(hex: "DC2626")    // Red — alert, danger
    static let accent    = Color(hex: "8B5CF6")    // Purple — AI, premium

    // Backward compatibility aliases — existing card files reference these.
    // New screens should NOT use these; pick from the 5 canonical roles above.
    static let info      = primary                 // Was cyan — now maps to primary blue
    static let earth     = warning                 // Was brown — now maps to warning amber
}

enum PayaAnimation {
    /// The spring every score/ring/number change should use — data updates
    /// should feel alive, not snap into place.
    static let dataChange = Animation.spring(response: 0.5, dampingFraction: 0.75)

    /// Tier transition — used when navigating between disclosure levels.
    static let tierTransition = Animation.spring(response: 0.35, dampingFraction: 0.85)
}

extension View {
    /// The app's standard card style — uses Pulse dark surfaces for the dark canvas.
    func payaCard(padding: CGFloat = PayaSpacing.md) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: PayaRadius.card)
                    .fill(Pulse.surfaceFallback)
                    .overlay(
                        RoundedRectangle(cornerRadius: PayaRadius.card)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
    }

    /// Elevated card — hero element with glow.
    func payaCardElevated(padding: CGFloat = PayaSpacing.md) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: PayaRadius.card)
                    .fill(Pulse.surfaceElevatedFallback)
                    .overlay(
                        RoundedRectangle(cornerRadius: PayaRadius.card)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
    }
}

/// A hero metric — the one number on a card meant to be read first, at a
/// glance, from arm's length. v2: enlarged from 34pt to 48pt default for
/// WHOOP-level readability.
struct HeroNumberText: View {
    let value: String
    var size: CGFloat = 48
    var color: Color = .primary

    var body: some View {
        Text(value)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}

// MARK: - Pill Picker (v2)
/// Horizontal scrollable pill selector — replaces SegmentedControl in Trends tab
/// where 4+ options make segments cramped.

struct PillPicker<T: Hashable & CaseIterable & RawRepresentable>: View where T.RawValue == String, T.AllCases == [T] {
    @Binding var selection: T
    var tint: Color = PayaColor.primary

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(T.allCases, id: \.self) { item in
                    Button {
                        withAnimation(PayaAnimation.tierTransition) { selection = item }
                    } label: {
                        Text(item.rawValue)
                            .font(.system(size: 13, weight: selection == item ? .bold : .medium))
                            .foregroundColor(selection == item ? .white : .primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selection == item ? tint : Pulse.surfaceFallback)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Summary Row (v2)
/// Hero stats bar at top of Trends sections — 3–4 large numbers in a row.

struct SummaryStatCell: View {
    var value: String
    var label: String
    var icon: String
    var color: Color
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Pulse.surfaceFallback)
            .clipShape(RoundedRectangle(cornerRadius: PayaRadius.compact))
        }
        .buttonStyle(PulsePress())
        .disabled(action == nil)
    }
}

// MARK: - Context Card (v2)
/// Time/state-aware card for the Today tab.

struct ContextCard: View {
    var icon: String
    var iconColor: Color
    var title: String
    var body_text: String  // named to avoid conflict with `body`
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 26, height: 26)
                    .background(iconColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if let actionLabel = actionLabel, let action = action {
                    Button(action: action) {
                        Text(actionLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(PayaColor.primary)
                    }
                }
            }
            Text(body_text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .payaCard(padding: 14)
    }
}
