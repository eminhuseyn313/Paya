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

enum PayaSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}

enum PayaRadius {
    static let card: CGFloat = 20
    static let chip: CGFloat = 12
    static let button: CGFloat = 14
    static let section: CGFloat = 16
}

/// Named palette — centralised hex references so new screens don't
/// re-derive colors from memory or copy-paste. Semantic, not decorative:
/// each name describes *what it signals*, not what it looks like.
enum PayaColor {
    static let primary   = Color(hex: "2563EB")   // Blue — navigation, default accent
    static let positive  = Color(hex: "059669")    // Green — on-track, healthy
    static let warning   = Color(hex: "F59E0B")    // Amber — caution, watch
    static let critical  = Color(hex: "DC2626")    // Red — alert, danger
    static let accent    = Color(hex: "8B5CF6")    // Purple — AI, premium
    static let info      = Color(hex: "0891B2")    // Cyan — data, hydration
    static let earth     = Color(hex: "B45309")    // Brown — flare, body
}

enum PayaAnimation {
    /// The spring every score/ring/number change should use — data updates
    /// should feel alive, not snap into place.
    static let dataChange = Animation.spring(response: 0.5, dampingFraction: 0.75)
}

extension View {
    /// The app's one card style: consistent padding, a softer corner
    /// radius than the 12-14pt scattered across older screens, and
    /// deliberately no border/stroke by default — a flat, quiet surface
    /// lets the content (especially color used for status) carry the
    /// visual weight instead of a rectangle competing for attention.
    func payaCard(padding: CGFloat = PayaSpacing.md) -> some View {
        self
            .padding(padding)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: PayaRadius.card))
    }
}

/// A hero metric — the one number on a card meant to be read first, at a
/// glance, from arm's length. Rounded design + heavy weight for real
/// contrast against the supporting text next to it, rather than every
/// piece of text on a card sitting at a similar medium weight.
struct HeroNumberText: View {
    let value: String
    var size: CGFloat = 34
    var color: Color = .primary

    var body: some View {
        Text(value)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .monospacedDigit()
            .contentTransition(.numericText())
    }
}
