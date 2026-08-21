import SwiftUI

// MARK: - Pulse Design System
//
// Design direction: "Pulse" — a living, atmospheric health companion.
//
// Visual identity:
//   Dark atmospheric canvas with luminous bio-signal visualizations.
//   Organic shapes, large radial progress, ambient motion.
//   Data glows against depth — metrics feel alive, not static.
//
// Research basis:
//   WHOOP: Dark-first, large recovery/strain rings, 3-color semantic
//   Oura 2025: "One big thing" hero, color-as-biometric-state, 3 tabs
//   Apple Health: Clean layering, confident typography, subtle motion
//   Strava: Celebration moments, social proof, bold orange energy
//   Calm: Atmospheric backgrounds, breathing animations, serenity
//
// Color philosophy — state-driven, not decorative:
//   Each physiological domain has its own luminous hue.
//   Colors glow against the dark canvas like bio-signals on a monitor.
//   The base stays calm so state colors communicate instantly.

// MARK: - Color Palette

enum Pulse {

    // ━━━ Canvas (backgrounds) ━━━
    /// The deepest layer — app background
    static let canvas = Color("pulseCanvas", bundle: nil)
    /// Elevated surface — cards, sheets
    static let surface = Color("pulseSurface", bundle: nil)
    /// Highest surface — modals, popovers
    static let surfaceElevated = Color("pulseSurfaceElevated", bundle: nil)

    // ━━━ Semantic state colors ━━━
    /// Energy / Training / Active — electric warm
    static let energy = Color(hex: "FF6B3D")
    /// Recovery / Sleep / Calm — cool teal
    static let recovery = Color(hex: "3DD6C8")
    /// Nutrition / Growth — warm amber gold
    static let nutrition = Color(hex: "FFB547")
    /// Heart / Vitals — rose
    static let vitals = Color(hex: "FF5A8A")
    /// Hydration — ocean blue
    static let hydration = Color(hex: "4A9BFF")
    /// AI / Premium — violet
    static let ai = Color(hex: "8B7BF7")
    /// On-track / Positive — luminous green
    static let positive = Color(hex: "4AE68A")
    /// Caution / Warning — amber
    static let warning = Color(hex: "FFB547")
    /// Alert / Critical — coral red
    static let critical = Color(hex: "FF5A5A")

    // ━━━ Text ━━━
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.35)

    // ━━━ Gradients ━━━
    static func stateGradient(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func radialGlow(_ color: Color, intensity: CGFloat = 0.3) -> RadialGradient {
        RadialGradient(
            colors: [color.opacity(intensity), .clear],
            center: .center,
            startRadius: 0,
            endRadius: 200
        )
    }

    // ━━━ Spacing ━━━
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // ━━━ Radii ━━━
    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 20
        static let lg: CGFloat = 28
        static let xl: CGFloat = 36
        static let full: CGFloat = 999
    }

    // ━━━ Motion ━━━
    enum Motion {
        /// Micro — button press, number tick
        static let micro = Animation.spring(response: 0.25, dampingFraction: 0.8)
        /// Standard — card expand, tab switch
        static let standard = Animation.spring(response: 0.4, dampingFraction: 0.82)
        /// Dramatic — hero transitions, ring fill
        static let dramatic = Animation.spring(response: 0.7, dampingFraction: 0.72)
        /// Breathing — ambient pulse, recovery state
        static let breathing = Animation.easeInOut(duration: 3.0).repeatForever(autoreverses: true)
        /// Slow glow — atmospheric background shifts
        static let glow = Animation.easeInOut(duration: 4.0).repeatForever(autoreverses: true)
    }
}

// MARK: - Programmatic Canvas Colors (fallback when asset catalog colors not available)

extension Pulse {
    /// Dark canvas — deep navy-black
    static let canvasFallback = Color(red: 0.04, green: 0.055, blue: 0.1)
    /// Surface — charcoal with warmth
    static let surfaceFallback = Color(red: 0.08, green: 0.095, blue: 0.14)
    /// Elevated surface
    static let surfaceElevatedFallback = Color(red: 0.12, green: 0.135, blue: 0.18)
}

// MARK: - Surface Modifiers

extension View {
    /// Pulse card — organic floating surface on dark canvas
    func pulseSurface(radius: CGFloat = Pulse.Radius.lg, padding: CGFloat = Pulse.Spacing.md) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(Pulse.surfaceFallback)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            )
    }

    /// Pulse card with glow accent
    func pulseSurfaceGlow(color: Color, radius: CGFloat = Pulse.Radius.lg, padding: CGFloat = Pulse.Spacing.md) -> some View {
        self
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(Pulse.surfaceFallback)
                    RoundedRectangle(cornerRadius: radius)
                        .fill(color.opacity(0.05))
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(color.opacity(0.15), lineWidth: 0.5)
                }
            )
    }

    /// Glass surface — translucent with blur feel
    func pulseGlass(radius: CGFloat = Pulse.Radius.lg, padding: CGFloat = Pulse.Spacing.md) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
    }
}

// MARK: - Animated Ring

/// Large animated progress ring — the hero visualization
struct PulseRing: View {
    var progress: CGFloat // 0...1
    var size: CGFloat = 160
    var lineWidth: CGFloat = 12
    var color: Color = Pulse.positive
    var trackColor: Color = Color.white.opacity(0.08)
    var showGlow: Bool = true

    @State private var animatedProgress: CGFloat = 0
    @State private var glowPulse: Bool = false

    var body: some View {
        ZStack {
            // Ambient glow
            if showGlow {
                Circle()
                    .fill(Pulse.radialGlow(color, intensity: glowPulse ? 0.2 : 0.1))
                    .frame(width: size + 60, height: size + 60)
                    .animation(Pulse.Motion.glow, value: glowPulse)
            }

            // Track
            Circle()
                .stroke(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)

            // Progress arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [color, color.opacity(0.7), color],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // End cap glow
            if animatedProgress > 0.02 {
                Circle()
                    .fill(color)
                    .frame(width: lineWidth + 4, height: lineWidth + 4)
                    .shadow(color: color.opacity(0.6), radius: 8)
                    .offset(y: -(size / 2))
                    .rotationEffect(.degrees(animatedProgress * 360 - 90))
            }
        }
        .onAppear {
            let reduceMotion = UIAccessibility.isReduceMotionEnabled
            if reduceMotion {
                animatedProgress = progress
                glowPulse = true
            } else {
                withAnimation(Pulse.Motion.dramatic) {
                    animatedProgress = progress
                }
                glowPulse = true
            }
        }
        .onChange(of: progress) { _, new in
            if UIAccessibility.isReduceMotionEnabled {
                animatedProgress = new
            } else {
                withAnimation(Pulse.Motion.dramatic) {
                    animatedProgress = new
                }
            }
        }
    }
}

// MARK: - Animated Counter

/// Number that counts up with spring animation
struct PulseCounter: View {
    let value: Int
    var font: Font = .system(size: 56, weight: .bold, design: .rounded)
    var color: Color = Pulse.textPrimary

    @State private var displayValue: Int = 0

    var body: some View {
        Text("\(displayValue)")
            .font(font)
            .foregroundColor(color)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(displayValue)))
            .onAppear {
                if UIAccessibility.isReduceMotionEnabled {
                    displayValue = value
                } else {
                    withAnimation(Pulse.Motion.dramatic) {
                        displayValue = value
                    }
                }
            }
            .onChange(of: value) { _, new in
                if UIAccessibility.isReduceMotionEnabled {
                    displayValue = new
                } else {
                    withAnimation(Pulse.Motion.standard) {
                        displayValue = new
                    }
                }
            }
    }
}

// MARK: - Breathing Orb

/// Ambient breathing animation for recovery/calm states
struct BreathingOrb: View {
    var color: Color = Pulse.recovery
    var size: CGFloat = 200
    @State private var isBreathing = false

    var body: some View {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled

        ZStack {
            Circle()
                .fill(color.opacity(0.08))
                .frame(width: size * (isBreathing ? 1.15 : 0.95),
                       height: size * (isBreathing ? 1.15 : 0.95))
                .blur(radius: 30)

            Circle()
                .fill(color.opacity(0.12))
                .frame(width: size * 0.7 * (isBreathing ? 1.1 : 0.9),
                       height: size * 0.7 * (isBreathing ? 1.1 : 0.9))
                .blur(radius: 20)

            Circle()
                .fill(color.opacity(0.2))
                .frame(width: size * 0.4 * (isBreathing ? 1.05 : 0.95),
                       height: size * 0.4 * (isBreathing ? 1.05 : 0.95))
                .blur(radius: 10)
        }
        .onAppear {
            if reduceMotion {
                // Static glow — no animation
                isBreathing = true
            } else {
                withAnimation(Pulse.Motion.breathing) {
                    isBreathing = true
                }
            }
        }
    }
}

// MARK: - Hero Insight Card

/// The "one big thing" — a visually dominant daily insight
struct HeroInsight: View {
    var emoji: String
    var headline: String
    var detail: String
    var accentColor: Color
    var action: (() -> Void)? = nil

    @State private var appeared = false

    var body: some View {
        Button(action: { action?() }) {
            VStack(alignment: .leading, spacing: 12) {
                Text(emoji)
                    .font(.system(size: 36))
                    .scaleEffect(appeared ? 1 : 0.5)
                    .opacity(appeared ? 1 : 0)

                Text(headline)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Pulse.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Pulse.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if action != nil {
                    HStack(spacing: 4) {
                        Text("Learn more")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(accentColor)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .pulseSurfaceGlow(color: accentColor, padding: 20)
        }
        .buttonStyle(PulsePress(scale: 0.98))
        .onAppear {
            withAnimation(Pulse.Motion.standard.delay(0.2)) {
                appeared = true
            }
        }
    }
}

// MARK: - Metric Orb

/// A floating circular metric — used for vitals strip
struct MetricOrb: View {
    var value: String
    var unit: String
    var label: String
    var color: Color
    var size: CGFloat = 72
    var progress: CGFloat? = nil
    var action: (() -> Void)? = nil
    /// Optional freshness label shown below the metric label (e.g. "2h ago")
    var freshness: String? = nil
    /// Whether this reading is fresh — drives a subtle breathing animation on the ring
    var isFresh: Bool = true

    @State private var breathe = false

    var body: some View {
        Button(action: { action?() }) {
            VStack(spacing: 4) {
                ZStack {
                    // Ambient glow — pulses gently when fresh
                    Circle()
                        .fill(color.opacity(isFresh ? 0.08 : 0.04))
                        .frame(width: size + 8, height: size + 8)
                        .blur(radius: 8)
                        .scaleEffect(isFresh && breathe ? 1.08 : 1.0)

                    // Background circle
                    Circle()
                        .fill(color.opacity(isFresh ? 0.1 : 0.05))
                        .frame(width: size, height: size)

                    // Progress ring (optional)
                    if let progress = progress {
                        Circle()
                            .stroke(color.opacity(0.15), lineWidth: 3)
                            .frame(width: size, height: size)
                        Circle()
                            .trim(from: 0, to: min(progress, 1.0))
                            .stroke(color.opacity(isFresh ? 1.0 : 0.4), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: size, height: size)
                            .rotationEffect(.degrees(-90))
                            .animation(Pulse.Motion.standard, value: progress)
                    }

                    // Value
                    VStack(spacing: 0) {
                        Text(value)
                            .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                            .foregroundColor(isFresh ? Pulse.textPrimary : Pulse.textTertiary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        if !unit.isEmpty {
                            Text(unit)
                                .font(.system(size: size * 0.14, weight: .medium))
                                .foregroundColor(color.opacity(isFresh ? 1.0 : 0.5))
                        }
                    }
                }
                .frame(minWidth: 44, minHeight: 44) // Accessibility touch target

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Pulse.textTertiary)

                // Freshness timestamp
                if let freshness = freshness {
                    Text(freshness)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(isFresh ? color.opacity(0.6) : Pulse.warning.opacity(0.7))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .onAppear {
            guard isFresh else { return }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breathe = true
            }
        }
    }
}

// MARK: - Section Header

struct PulseSectionHeader: View {
    var title: String
    var icon: String? = nil
    var action: (() -> Void)? = nil
    var actionLabel: String = "See all"

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Pulse.textTertiary)
            }
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Pulse.textSecondary)

            Spacer()

            if let action = action {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(actionLabel)
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(Pulse.textTertiary)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Expandable Info

/// Progressive disclosure — tap to expand detail
struct PulseExpandable: View {
    var summary: String
    var detail: String
    var color: Color = Pulse.recovery
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Pulse.Motion.standard) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(summary)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Pulse.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Pulse.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PulsePress(scale: 0.99))

            if isExpanded {
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(Pulse.textSecondary)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .pulseSurfaceGlow(color: color, padding: 16)
    }
}

// MARK: - Wave Progress Bar

/// Fluid progress bar with wave animation
struct WaveProgressBar: View {
    var progress: CGFloat
    var color: Color
    var height: CGFloat = 6

    @State private var animatedProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(color.opacity(0.12))
                    .frame(height: height)

                // Fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.8), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * animatedProgress, height: height)
                    .shadow(color: color.opacity(0.4), radius: 4, y: 0)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(Pulse.Motion.dramatic) {
                animatedProgress = min(progress, 1.0)
            }
        }
        .onChange(of: progress) { _, new in
            withAnimation(Pulse.Motion.standard) {
                animatedProgress = min(new, 1.0)
            }
        }
    }
}

// MARK: - Compact Stat Row

/// Horizontal stat with label, value, optional bar
struct PulseStatRow: View {
    var label: String
    var value: String
    var target: String? = nil
    var progress: CGFloat? = nil
    var color: Color = Pulse.positive

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Pulse.textSecondary)
                Spacer()
                HStack(spacing: 2) {
                    Text(value)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.textPrimary)
                        .monospacedDigit()
                    if let target = target {
                        Text("/ \(target)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Pulse.textTertiary)
                    }
                }
            }
            if let progress = progress {
                WaveProgressBar(progress: progress, color: color)
            }
        }
    }
}

// MARK: - Quick Action Chip

struct PulseChip: View {
    var icon: String
    var label: String
    var color: Color = Pulse.hydration
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.2), lineWidth: 0.5)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pulse Button Style

/// Consistent press animation for all interactive elements
struct PulsePress: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Stronger press for large action buttons
struct PulsePrimaryPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Reduced Motion Support

extension View {
    /// Applies animation only when reduced motion is not enabled
    @ViewBuilder
    func pulseAnimation<V: Equatable>(_ animation: Animation?, value: V) -> some View {
        if UIAccessibility.isReduceMotionEnabled {
            self
        } else {
            self.animation(animation, value: value)
        }
    }
}

// MARK: - Animated Metric Text

/// A number that animates smoothly when its value changes — for health metrics
struct PulseMetricText: View {
    let value: String
    var font: Font = .system(size: 18, weight: .bold, design: .rounded)
    var color: Color = Pulse.textPrimary

    var body: some View {
        Text(value)
            .font(font)
            .foregroundColor(color)
            .monospacedDigit()
            .contentTransition(.numericText())
            .animation(Pulse.Motion.standard, value: value)
    }
}

// MARK: - Shimmer Loading Modifier

/// Shimmer effect for skeleton loading states — a luminous sweep across dark surfaces
struct PulseShimmer: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        content
            .overlay(
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(reduceMotion ? 0.03 : 0.06),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    phase = 400
                }
            }
    }
}

extension View {
    /// Apply a shimmer loading effect
    func pulseShimmer() -> some View {
        modifier(PulseShimmer())
    }
}

// MARK: - Skeleton Loading Shapes

/// A skeleton placeholder row — mimics a card's content shape while loading
struct PulseSkeletonRow: View {
    var lineCount: Int = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.06))
                .frame(width: 120, height: 14)

            ForEach(0..<lineCount, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 10)
                    .frame(maxWidth: i == lineCount - 1 ? 180 : .infinity)
            }
        }
        .pulseSurface(padding: 16)
        .pulseShimmer()
    }
}

/// A skeleton orb — mimics MetricOrb while loading
struct PulseSkeletonOrb: View {
    var size: CGFloat = 72

    var body: some View {
        VStack(spacing: 6) {
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: size, height: size)

            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.04))
                .frame(width: 40, height: 8)
        }
        .pulseShimmer()
    }
}

// MARK: - Empty State

/// Encouraging empty state — shows when there's no data yet, with a CTA
struct PulseEmptyState: View {
    var icon: String = "tray"
    var title: String
    var message: String
    var ctaLabel: String? = nil
    var ctaIcon: String? = "plus.circle.fill"
    var accentColor: Color = Pulse.hydration
    var action: (() -> Void)? = nil

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.08))
                    .frame(width: 80, height: 80)
                Circle()
                    .fill(accentColor.opacity(0.04))
                    .frame(width: 100, height: 100)
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(accentColor.opacity(0.6))
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Pulse.textPrimary)

                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Pulse.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 20)
            }

            if let label = ctaLabel, let action = action {
                Button(action: action) {
                    HStack(spacing: 6) {
                        if let ctaIcon = ctaIcon {
                            Image(systemName: ctaIcon)
                                .font(.system(size: 13, weight: .bold))
                        }
                        Text(label)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(accentColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(PulsePrimaryPress())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                appeared = true
            }
        }
    }
}

// MARK: - Success Celebration

/// Burst particle for celebrations — small circles that fly outward and fade
struct PulseCelebrationBurst: View {
    var color: Color = Pulse.positive
    var particleCount: Int = 12
    @State private var fired = false

    var body: some View {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        ZStack {
            ForEach(0..<particleCount, id: \.self) { i in
                let angle = Double(i) / Double(particleCount) * 360
                let distance: CGFloat = fired ? CGFloat.random(in: 60...120) : 0
                Circle()
                    .fill(particleColor(i))
                    .frame(width: CGFloat.random(in: 4...8), height: CGFloat.random(in: 4...8))
                    .offset(
                        x: fired ? cos(angle * .pi / 180) * distance : 0,
                        y: fired ? sin(angle * .pi / 180) * distance : 0
                    )
                    .opacity(fired ? 0 : 1)
                    .scaleEffect(fired ? 0.3 : 1)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.8)) {
                fired = true
            }
        }
    }

    private func particleColor(_ index: Int) -> Color {
        let colors: [Color] = [color, color.opacity(0.7), Pulse.nutrition, Pulse.energy, Pulse.ai]
        return colors[index % colors.count]
    }
}

/// Success checkmark with ring animation + optional celebration burst
struct PulseSuccessCheck: View {
    var size: CGFloat = 100
    var color: Color = Pulse.positive
    var showBurst: Bool = true

    @State private var ringProgress: CGFloat = 0
    @State private var checkScale: CGFloat = 0
    @State private var glowOpacity: CGFloat = 0

    var body: some View {
        ZStack {
            // Celebration burst
            if showBurst {
                PulseCelebrationBurst(color: color, particleCount: 16)
            }

            // Glow
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size + 30, height: size + 30)
                .blur(radius: 15)
                .opacity(glowOpacity)

            // Ring
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 4)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(color)
                .scaleEffect(checkScale)
        }
        .onAppear {
            let reduceMotion = UIAccessibility.isReduceMotionEnabled
            if reduceMotion {
                ringProgress = 1
                checkScale = 1
                glowOpacity = 1
            } else {
                withAnimation(.easeOut(duration: 0.6)) {
                    ringProgress = 1
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.4)) {
                    checkScale = 1
                }
                withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                    glowOpacity = 1
                }
            }
        }
    }
}

/// Inline celebration badge — "🏆 3 PRs" with glow and optional pulse
struct PulsePRBadge: View {
    let count: Int
    @State private var glowing = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 13))
            Text("\(count) PR\(count > 1 ? "s" : "")")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundColor(Pulse.nutrition)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Pulse.nutrition.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(Pulse.nutrition.opacity(glowing ? 0.3 : 0.1), lineWidth: 1)
                )
        )
        .shadow(color: Pulse.nutrition.opacity(glowing ? 0.3 : 0), radius: 8)
        .onAppear {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowing = true
            }
        }
    }
}

/// Volume delta badge — "+12% vs last" with directional color
struct PulseVolumeDelta: View {
    let delta: Double // percentage

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            Text(String(format: "%+.0f%% vs last", delta))
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundColor(delta >= 0 ? Pulse.positive : Pulse.critical)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill((delta >= 0 ? Pulse.positive : Pulse.critical).opacity(0.1))
        )
    }
}
