import SwiftUI

// MARK: - Training Periodization Detector
// Automatically detects which training phase the user is in based on
// their volume and intensity trends over the last 4 weeks.
//
// Phases (Bompa & Haff, 2009 — Periodization: Theory & Methodology):
// • Accumulation — high volume, moderate intensity (building work capacity)
// • Intensification — lower volume, higher intensity (pushing strength)
// • Peaking — low volume, very high intensity (competition prep)
// • Deload — significantly reduced volume & intensity (recovery)
// • General — no clear pattern detected

struct PeriodizationCard: View {

    @Environment(AppState.self) private var appState
    var sessions: [TrainingSession]

    @State private var phase: TrainingPhase = .general
    @State private var weeklyData: [PhaseWeek] = []
    @State private var recommendation: String = ""

    private var useLbs: Bool { appState.profile.prefersLbs }

    var body: some View {
        Group {
            if weeklyData.count >= 2 {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: phase.icon)
                            .foregroundColor(phase.color)
                        Text("Training Phase")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(phase.label)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(phase.color)
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 4) {
                        ForEach(weeklyData) { week in
                            VStack(spacing: 4) {
                                Text(week.label)
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(Pulse.textTertiary)

                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Pulse.surfaceElevatedFallback)
                                        .frame(height: 40)

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            LinearGradient(
                                                colors: [phase.color.opacity(0.6), phase.color.opacity(0.2)],
                                                startPoint: .bottom, endPoint: .top
                                            )
                                        )
                                        .frame(height: 40 * CGFloat(week.volumeNormalized))
                                }

                                ZStack(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Pulse.surfaceElevatedFallback)
                                        .frame(height: 40)

                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(
                                            LinearGradient(
                                                colors: [Pulse.nutrition.opacity(0.6), Pulse.nutrition.opacity(0.2)],
                                                startPoint: .bottom, endPoint: .top
                                            )
                                        )
                                        .frame(height: 40 * CGFloat(week.intensityNormalized))
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    HStack(spacing: 12) {
                        HStack(spacing: 3) {
                            Circle().fill(phase.color).frame(width: 5, height: 5)
                            Text("Volume").font(.system(size: 8)).foregroundColor(Pulse.textTertiary)
                        }
                        HStack(spacing: 3) {
                            Circle().fill(Pulse.nutrition).frame(width: 5, height: 5)
                            Text("Intensity").font(.system(size: 8)).foregroundColor(Pulse.textTertiary)
                        }
                    }

                    if !recommendation.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 10))
                                .foregroundColor(phase.color)
                                .padding(.top, 1)
                            Text(recommendation)
                                .font(.system(size: 10))
                                .foregroundColor(Pulse.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Text("Phase detection based on Bompa & Haff (2009) periodization model. Volume = total tonnage, intensity = average weight per set.")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func compute() {
        let calendar = Calendar.current
        let completed = sessions.filter(\.isCompleted)

        var weeks: [PhaseWeek] = []
        for weekOffset in (0..<4).reversed() {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date())!
            let weekStartNorm = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart))!
            let weekEndNorm = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStartNorm)!

            let weekSessions = completed.filter { $0.date >= weekStartNorm && $0.date < weekEndNorm }

            var totalVolume: Double = 0
            var totalWeight: Double = 0
            var setCount = 0

            for session in weekSessions {
                for log in session.exercises {
                    for set in log.sets where set.isCompleted {
                        totalVolume += set.weightKg * Double(set.reps)
                        totalWeight += set.weightKg
                        setCount += 1
                    }
                }
            }

            let avgIntensity = setCount > 0 ? totalWeight / Double(setCount) : 0

            weeks.append(PhaseWeek(
                label: "W\(4 - weekOffset)",
                volume: totalVolume,
                avgIntensity: avgIntensity,
                sessionCount: weekSessions.count,
                volumeNormalized: 0,
                intensityNormalized: 0
            ))
        }

        guard weeks.contains(where: { $0.volume > 0 }) else { return }

        // Normalize
        let maxVol = weeks.map(\.volume).max() ?? 1
        let maxInt = weeks.map(\.avgIntensity).max() ?? 1
        weeks = weeks.map {
            PhaseWeek(
                label: $0.label,
                volume: $0.volume,
                avgIntensity: $0.avgIntensity,
                sessionCount: $0.sessionCount,
                volumeNormalized: maxVol > 0 ? $0.volume / maxVol : 0,
                intensityNormalized: maxInt > 0 ? $0.avgIntensity / maxInt : 0
            )
        }

        weeklyData = weeks

        // Detect phase from trend
        let recentWeeks = Array(weeks.suffix(2))
        let earlierWeeks = Array(weeks.prefix(2))

        let recentVol = recentWeeks.map(\.volume).reduce(0, +) / Double(max(1, recentWeeks.count))
        let earlyVol = earlierWeeks.map(\.volume).reduce(0, +) / Double(max(1, earlierWeeks.count))
        let recentInt = recentWeeks.map(\.avgIntensity).reduce(0, +) / Double(max(1, recentWeeks.count))
        let earlyInt = earlierWeeks.map(\.avgIntensity).reduce(0, +) / Double(max(1, earlierWeeks.count))

        let volChange = earlyVol > 0 ? (recentVol - earlyVol) / earlyVol : 0
        let intChange = earlyInt > 0 ? (recentInt - earlyInt) / earlyInt : 0

        if volChange < -0.3 && intChange < -0.1 {
            phase = .deload
            recommendation = "You're in a deload phase — reduced volume and intensity. Focus on recovery, sleep, and nutrition. Resume normal training in 3-5 days."
        } else if volChange < -0.15 && intChange > 0.05 {
            phase = .intensification
            recommendation = "Shifting to intensification — lower volume but heavier weights. Keep rest periods longer (3-5 min) and focus on compound lifts."
        } else if volChange > 0.1 && intChange < 0.05 {
            phase = .accumulation
            recommendation = "Building work capacity with higher volume. Great time to add accessory work and focus on muscle hypertrophy."
        } else if volChange < -0.2 && intChange > 0.1 {
            phase = .peaking
            recommendation = "Low volume, high intensity — peaking phase. Keep sessions short and heavy. Consider testing PRs this week."
        } else {
            phase = .general
            recommendation = "Training load is balanced. Consider periodizing: 3 weeks of progressive overload followed by 1 deload week."
        }
    }
}

private enum TrainingPhase {
    case accumulation, intensification, peaking, deload, general

    var label: String {
        switch self {
        case .accumulation: return "Accumulation"
        case .intensification: return "Intensification"
        case .peaking: return "Peaking"
        case .deload: return "Deload"
        case .general: return "General"
        }
    }

    var icon: String {
        switch self {
        case .accumulation: return "chart.bar.fill"
        case .intensification: return "bolt.fill"
        case .peaking: return "crown.fill"
        case .deload: return "leaf.fill"
        case .general: return "circle.grid.3x3.fill"
        }
    }

    var color: Color {
        switch self {
        case .accumulation: return Pulse.hydration
        case .intensification: return Pulse.nutrition
        case .peaking: return Pulse.ai
        case .deload: return Pulse.positive
        case .general: return Pulse.recovery
        }
    }
}

private struct PhaseWeek: Identifiable {
    let label: String
    let volume: Double
    let avgIntensity: Double
    let sessionCount: Int
    let volumeNormalized: Double
    let intensityNormalized: Double
    var id: String { label }
}
