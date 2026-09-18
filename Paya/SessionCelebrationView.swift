import SwiftUI

// MARK: - Session Celebration View
//
// Post-session celebration that compares total lifted volume to real-world
// objects. Shows after "Finish Session" and before the ReflectionSheet.
//
// Weight comparisons grounded in real-world averages:
//   - Grocery bag:       5 kg   (USDA shopping trip avg)
//   - Golden retriever: 30 kg   (AKC breed standard)
//   - Adult kangaroo:   66 kg   (National Geographic)
//   - Giant panda:     100 kg   (WWF species profile)
//   - Grand piano:     480 kg   (Steinway Model D)
//   - Horse:           500 kg   (American Quarter Horse Assn.)
//   - Polar bear:      600 kg   (NOAA species data)
//   - Compact car:   1,200 kg   (EPA curb weight avg)
//   - Pickup truck:  2,200 kg   (NHTSA fleet average)
//   - African elephant: 6,000 kg (IUCN Red List)
//   - T-Rex:          8,000 kg   (Hutchinson et al. 2011, PLoS ONE)
//   - School bus:    11,000 kg   (NHTSA Type C spec)
//   - Space Shuttle: 78,000 kg   (NASA orbiter dry mass)

struct SessionCelebrationView: View {

    @Environment(AppState.self) private var appState
    let session: TrainingSession
    let onContinue: () -> Void

    @State private var showContent = false
    @State private var showComparison = false
    @State private var showButton = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var particlePhase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var totalVolume: Double {
        session.exercises.reduce(0.0) { total, ex in
            total + ex.sets
                .filter { $0.isCompleted }
                .reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }
        }
    }

    private var totalReps: Int {
        session.exercises.reduce(0) { total, ex in
            total + ex.sets.filter { $0.isCompleted }.reduce(0) { $0 + $1.reps }
        }
    }

    private var hasVolume: Bool { totalVolume > 10 }

    private var comparison: WeightComparison {
        WeightComparison.best(for: totalVolume)
    }

    private var multiplier: Double {
        guard comparison.weightKg > 0 else { return 1 }
        return totalVolume / comparison.weightKg
    }

    private var heroColor: Color {
        hasVolume ? comparison.glowColor : Pulse.positive
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Ambient radial glow behind the icon
            RadialGradient(
                colors: [
                    heroColor.opacity(showContent ? 0.25 : 0),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 200
            )
            .scaleEffect(pulseScale)
            .ignoresSafeArea()

            if !reduceMotion {
                CelebrationParticles(color: heroColor, phase: particlePhase)
                    .opacity(showContent ? 1 : 0)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                Spacer()

                // Top label
                Text("SESSION COMPLETE")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(3)
                    .foregroundColor(heroColor.opacity(0.7))
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 10)

                Spacer().frame(height: 28)

                // Hero icon
                ZStack {
                    Circle()
                        .fill(heroColor.opacity(0.08))
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseScale)

                    Circle()
                        .fill(heroColor.opacity(0.04))
                        .frame(width: 200, height: 200)
                        .scaleEffect(pulseScale * 0.95)

                    Image(systemName: hasVolume ? comparison.sfSymbol : "figure.strengthtraining.traditional")
                        .font(.system(size: 72, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [heroColor, heroColor.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: heroColor.opacity(0.5), radius: 20)
                }
                .scaleEffect(showContent ? 1 : 0.5)
                .opacity(showContent ? 1 : 0)

                Spacer().frame(height: 32)

                // Main metric
                VStack(spacing: 6) {
                    if hasVolume {
                        Text(volumeString)
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                        Text("total \(useLbs ? "lbs" : "kg") moved")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Pulse.textSecondary)
                    } else {
                        Text("\(totalReps)")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                        Text("total reps crushed")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Pulse.textSecondary)
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

                Spacer().frame(height: 36)

                // Comparison card — only for weighted sessions
                if hasVolume {
                    VStack(spacing: 12) {
                        Text("That's like lifting")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Pulse.textTertiary)

                        HStack(spacing: 14) {
                            HStack(spacing: -8) {
                                ForEach(0..<min(max(Int(multiplier.rounded()), 1), 5), id: \.self) { i in
                                    Image(systemName: comparison.sfSymbol)
                                        .font(.system(size: 28, weight: .medium))
                                        .foregroundColor(comparison.glowColor)
                                        .background(
                                            Circle()
                                                .fill(Color.black)
                                                .frame(width: 44, height: 44)
                                        )
                                        .offset(x: showComparison ? 0 : CGFloat(i) * -20)
                                        .opacity(showComparison ? 1 : 0)
                                        .animation(
                                            .spring(response: 0.5, dampingFraction: 0.7)
                                                .delay(Double(i) * 0.08),
                                            value: showComparison
                                        )
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(comparisonText)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(comparison.subtitle)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Pulse.textTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(heroColor.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 32)
                    .scaleEffect(showComparison ? 1 : 0.9)
                    .opacity(showComparison ? 1 : 0)
                } else {
                    // Bodyweight session encouragement
                    VStack(spacing: 8) {
                        Text("Pure bodyweight power")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("You moved your own body through \(totalReps) reps across \(totalSets) sets")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Pulse.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(heroColor.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 32)
                    .scaleEffect(showComparison ? 1 : 0.9)
                    .opacity(showComparison ? 1 : 0)
                }

                Spacer().frame(height: 20)

                // Session stats row
                HStack(spacing: 24) {
                    StatPill(label: "Duration", value: "\(session.durationMinutes)m")
                    StatPill(label: "Sets", value: "\(totalSets)")
                    StatPill(label: "Exercises", value: "\(session.exercises.count)")
                }
                .opacity(showComparison ? 1 : 0)

                Spacer()

                // Continue button
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(heroColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showContent = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.4)) {
                showComparison = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.8)) {
                showButton = true
            }
            if !reduceMotion {
                withAnimation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
                ) {
                    pulseScale = 1.08
                }
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    particlePhase = 1
                }
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private var useLbs: Bool { appState.profile.prefersLbs }

    private var displayVolume: Double {
        useLbs ? totalVolume * 2.20462 : totalVolume
    }

    private var volumeString: String {
        if displayVolume >= 1000 {
            return String(format: "%.1fk", displayVolume / 1000)
        }
        return "\(Int(displayVolume))"
    }

    private var comparisonText: String {
        let count = multiplier
        if count < 1.1 {
            return "1 \(comparison.name)"
        } else if count < 2 {
            return String(format: "%.1f× %@", count, comparison.namePlural)
        } else {
            return "\(Int(count.rounded()))× \(comparison.namePlural)"
        }
    }

    private var totalSets: Int {
        session.exercises.reduce(0) { total, ex in
            total + ex.sets.filter { $0.isCompleted }.count
        }
    }
}

// MARK: - Stat Pill

private struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Pulse.textTertiary)
        }
    }
}

// MARK: - Weight Comparison Model

struct WeightComparison {
    let name: String
    let namePlural: String
    let weightKg: Double
    let sfSymbol: String
    let glowColor: Color
    let subtitle: String

    static let all: [WeightComparison] = [
        WeightComparison(
            name: "grocery bag", namePlural: "grocery bags",
            weightKg: 5, sfSymbol: "bag.fill",
            glowColor: Pulse.nutrition,
            subtitle: "~5 kg each"
        ),
        WeightComparison(
            name: "golden retriever", namePlural: "golden retrievers",
            weightKg: 30, sfSymbol: "dog.fill",
            glowColor: Pulse.warning,
            subtitle: "~30 kg each"
        ),
        WeightComparison(
            name: "kangaroo", namePlural: "kangaroos",
            weightKg: 66, sfSymbol: "hare.fill",
            glowColor: Pulse.energy,
            subtitle: "~66 kg each"
        ),
        WeightComparison(
            name: "giant panda", namePlural: "giant pandas",
            weightKg: 100, sfSymbol: "pawprint.fill",
            glowColor: Pulse.textPrimary,
            subtitle: "~100 kg each"
        ),
        WeightComparison(
            name: "grand piano", namePlural: "grand pianos",
            weightKg: 480, sfSymbol: "pianokeys",
            glowColor: Pulse.ai,
            subtitle: "Steinway Model D — ~480 kg"
        ),
        WeightComparison(
            name: "horse", namePlural: "horses",
            weightKg: 500, sfSymbol: "figure.equestrian.sports",
            glowColor: Pulse.energy,
            subtitle: "Quarter horse — ~500 kg"
        ),
        WeightComparison(
            name: "polar bear", namePlural: "polar bears",
            weightKg: 600, sfSymbol: "snowflake",
            glowColor: Pulse.hydration,
            subtitle: "Adult male — ~600 kg"
        ),
        WeightComparison(
            name: "compact car", namePlural: "compact cars",
            weightKg: 1200, sfSymbol: "car.fill",
            glowColor: Pulse.hydration,
            subtitle: "~1,200 kg curb weight"
        ),
        WeightComparison(
            name: "pickup truck", namePlural: "pickup trucks",
            weightKg: 2200, sfSymbol: "truck.box.fill",
            glowColor: Pulse.energy,
            subtitle: "~2,200 kg average"
        ),
        WeightComparison(
            name: "African elephant", namePlural: "African elephants",
            weightKg: 6000, sfSymbol: "leaf.fill",
            glowColor: Pulse.positive,
            subtitle: "~6,000 kg — largest land animal"
        ),
        WeightComparison(
            name: "T-Rex", namePlural: "T-Rexes",
            weightKg: 8000, sfSymbol: "fossil.shell.fill",
            glowColor: Pulse.critical,
            subtitle: "~8,000 kg — Hutchinson et al. 2011"
        ),
        WeightComparison(
            name: "school bus", namePlural: "school buses",
            weightKg: 11000, sfSymbol: "bus.fill",
            glowColor: Pulse.warning,
            subtitle: "NHTSA Type C — ~11,000 kg"
        ),
        WeightComparison(
            name: "Space Shuttle", namePlural: "Space Shuttles",
            weightKg: 78000, sfSymbol: "airplane",
            glowColor: Pulse.ai,
            subtitle: "NASA orbiter — ~78,000 kg dry"
        ),
    ]

    static func best(for volume: Double) -> WeightComparison {
        // Pick the comparison that gives a multiplier between 1 and ~10,
        // preferring comparisons where the number is small and punchy
        // (e.g. "2× elephants" over "400× grocery bags").
        let sorted = all.sorted { a, b in
            let aRatio = volume / a.weightKg
            let bRatio = volume / b.weightKg
            let aScore = aRatio >= 1 ? aRatio : 1 / aRatio * 100
            let bScore = bRatio >= 1 ? bRatio : 1 / bRatio * 100
            return aScore < bScore
        }
        // Pick the best that gives >= 1× (we don't want "0.5× elephants")
        if let match = sorted.first(where: { volume / $0.weightKg >= 0.8 }) {
            return match
        }
        return all[0]
    }
}

// MARK: - Celebration Particles

struct CelebrationParticles: View {
    let color: Color
    let phase: CGFloat

    var body: some View {
        Canvas { context, size in
            let count = 30
            for i in 0..<count {
                let progress = (Double(i) / Double(count) + phase).truncatingRemainder(dividingBy: 1.0)
                let x = size.width * (0.1 + 0.8 * sin(Double(i) * 2.3 + phase * .pi * 2).magnitude)
                let y = size.height * (1.0 - progress)
                let opacity = sin(progress * .pi) * 0.4
                let radius = 1.5 + sin(Double(i) * 1.7) * 1.5

                context.opacity = opacity
                context.fill(
                    Circle().path(in: CGRect(
                        x: x - radius,
                        y: y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .color(color)
                )
            }
        }
    }
}
