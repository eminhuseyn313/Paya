import SwiftUI

// MARK: - Strength Radar
// Spider chart showing relative strength across 6 movement patterns.
// Whoop shows strain distribution; this shows STRENGTH distribution —
// where your body is strong vs weak at a glance.

struct StrengthRadarCard: View {

    @Environment(AppState.self) private var appState
    var sessions: [TrainingSession]

    @State private var axes: [RadarAxis] = []
    @State private var weakest: String = ""
    @State private var strongest: String = ""

    private var useLbs: Bool { appState.profile.prefersLbs }

    private let patterns: [(key: String, label: String, icon: String, matches: [String])] = [
        ("push_h", "H. Push", "arrow.right", ["bench", "push-up", "chest press", "floor press"]),
        ("push_v", "V. Push", "arrow.up", ["overhead press", "ohp", "military", "shoulder press", "arnold"]),
        ("pull_h", "H. Pull", "arrow.left", ["row", "cable row", "seal row", "t-bar"]),
        ("pull_v", "V. Pull", "arrow.down", ["pull-up", "pullup", "chin-up", "chinup", "pulldown", "lat pull"]),
        ("squat", "Squat", "arrow.up.arrow.down", ["squat", "leg press", "lunge", "split squat", "hack"]),
        ("hinge", "Hinge", "arrow.turn.down.right", ["deadlift", "rdl", "romanian", "hip thrust", "good morning", "glute bridge"]),
    ]

    var body: some View {
        Group {
            if axes.count == 6 {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "hexagon.fill")
                            .foregroundColor(Pulse.hydration)
                        Text("Strength Radar")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Pulse.textPrimary)
                        Spacer()
                    }

                    RadarChartView(axes: axes)
                        .frame(height: 200)
                        .padding(.horizontal, 8)

                    HStack(spacing: 16) {
                        if !strongest.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Pulse.positive)
                                Text("Strongest: \(strongest)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Pulse.positive)
                            }
                        }
                        if !weakest.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Pulse.critical)
                                Text("Weakest: \(weakest)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Pulse.critical)
                            }
                        }
                    }

                    Text("Relative strength across 6 movement patterns. Based on estimated 1RM (Epley). A balanced hexagon means balanced development.")
                        .font(.system(size: 9))
                        .foregroundColor(Pulse.textTertiary)
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func compute() {
        let completed = sessions.filter(\.isCompleted)
        var patternBest: [String: Double] = [:]

        for session in completed {
            for log in session.exercises {
                let name = log.exerciseName.lowercased()
                for pattern in patterns {
                    if pattern.matches.contains(where: { name.contains($0) }) {
                        let best = log.sets.filter(\.isCompleted)
                            .map { set -> Double in
                                guard set.reps > 0 else { return set.weightKg }
                                return set.weightKg * (1 + Double(set.reps) / 30.0)
                            }
                            .max() ?? 0
                        if best > (patternBest[pattern.key] ?? 0) {
                            patternBest[pattern.key] = best
                        }
                    }
                }
            }
        }

        guard patternBest.count >= 3 else { return }

        let maxE1RM = patternBest.values.max() ?? 1
        guard maxE1RM > 0 else { return }

        axes = patterns.map { pattern in
            let value = patternBest[pattern.key] ?? 0
            let normalized = value / maxE1RM
            let display = useLbs ? value * 2.20462 : value
            return RadarAxis(
                label: pattern.label,
                value: normalized,
                rawValue: display,
                icon: pattern.icon
            )
        }

        if let maxPattern = patternBest.max(by: { $0.value < $1.value }) {
            strongest = patterns.first { $0.key == maxPattern.key }?.label ?? ""
        }
        let filledPatterns = patternBest.filter { $0.value > 0 }
        if let minPattern = filledPatterns.min(by: { $0.value < $1.value }) {
            weakest = patterns.first { $0.key == minPattern.key }?.label ?? ""
        }
    }
}

// MARK: - Radar Chart Drawing

private struct RadarAxis: Identifiable {
    let label: String
    let value: CGFloat   // 0–1 normalized
    let rawValue: Double
    let icon: String
    var id: String { label }
}

private struct RadarChartView: View {

    var axes: [RadarAxis]

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 24
            let count = axes.count

            ZStack {
                // Grid rings
                ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { ring in
                    Path { path in
                        for i in 0..<count {
                            let angle = angleFor(index: i, total: count)
                            let r = radius * ring
                            let pt = pointAt(center: center, radius: r, angle: angle)
                            if i == 0 { path.move(to: pt) }
                            else { path.addLine(to: pt) }
                        }
                        path.closeSubpath()
                    }
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                }

                // Spoke lines
                ForEach(0..<count, id: \.self) { i in
                    let angle = angleFor(index: i, total: count)
                    let pt = pointAt(center: center, radius: radius, angle: angle)
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: pt)
                    }
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                }

                // Data polygon fill
                Path { path in
                    for i in 0..<count {
                        let angle = angleFor(index: i, total: count)
                        let r = radius * max(0.05, axes[i].value)
                        let pt = pointAt(center: center, radius: r, angle: angle)
                        if i == 0 { path.move(to: pt) }
                        else { path.addLine(to: pt) }
                    }
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Pulse.hydration.opacity(0.25), Pulse.ai.opacity(0.15)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                // Data polygon stroke
                Path { path in
                    for i in 0..<count {
                        let angle = angleFor(index: i, total: count)
                        let r = radius * max(0.05, axes[i].value)
                        let pt = pointAt(center: center, radius: r, angle: angle)
                        if i == 0 { path.move(to: pt) }
                        else { path.addLine(to: pt) }
                    }
                    path.closeSubpath()
                }
                .stroke(
                    LinearGradient(
                        colors: [Pulse.hydration, Pulse.ai],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )

                // Data points
                ForEach(0..<count, id: \.self) { i in
                    let angle = angleFor(index: i, total: count)
                    let r = radius * max(0.05, axes[i].value)
                    let pt = pointAt(center: center, radius: r, angle: angle)
                    Circle()
                        .fill(Pulse.hydration)
                        .frame(width: 6, height: 6)
                        .position(pt)
                }

                // Labels
                ForEach(0..<count, id: \.self) { i in
                    let angle = angleFor(index: i, total: count)
                    let labelR = radius + 18
                    let pt = pointAt(center: center, radius: labelR, angle: angle)
                    VStack(spacing: 1) {
                        Text(axes[i].label)
                            .font(.system(size: 8, weight: .bold))
                        Text(String(format: "%.0f", axes[i].rawValue))
                            .font(.system(size: 7, weight: .semibold, design: .rounded))
                            .foregroundColor(Pulse.hydration)
                    }
                    .foregroundColor(Pulse.textTertiary)
                    .position(pt)
                }
            }
        }
    }

    private func angleFor(index: Int, total: Int) -> Double {
        let fraction = Double(index) / Double(total)
        return fraction * 2 * .pi - .pi / 2
    }

    private func pointAt(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }
}
