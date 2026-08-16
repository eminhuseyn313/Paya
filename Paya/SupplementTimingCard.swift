import SwiftUI
import SwiftData

// MARK: - Supplement Timing Timeline Card
// Visual timeline showing when to take each supplement, timed to
// today's training schedule. Replaces 3+ standalone apps.
//
// Evidence-based timing from ISSN position stands:
// - Creatine monohydrate 3-5g: timing doesn't matter (Kreider et al.
//   2017 ISSN), but post-workout may slightly improve uptake
// - Caffeine 3-6mg/kg: 30-60 min pre-workout (Goldstein et al. 2010)
// - Protein 20-40g: within 2h post-workout, but total daily intake
//   matters more (Schoenfeld & Aragon 2018)
// - Beta-alanine 3.2-6.4g: split across day, timing irrelevant
//   (Trexler et al. 2015 ISSN)
// - Vitamin D 1000-5000 IU: with fat-containing meal (Dawson-Hughes
//   2017)
// - Fish oil/omega-3: with meals for absorption (Schuchardt & Hahn 2013)
// - Magnesium: evening, 200-400mg (Abbasi et al. 2012)

struct SupplementTimingCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var timelineEntries: [TimingEntry] = []
    @State private var hasSupplements = false

    struct TimingEntry: Identifiable {
        let id = UUID()
        let name: String
        let dose: String
        let timeLabel: String
        let hour: Int            // for sorting
        let icon: String
        let color: Color
        let rationale: String
        let isPassed: Bool
    }

    var body: some View {
        Group {
            if hasSupplements && !timelineEntries.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "pills.fill")
                            .foregroundColor(Pulse.recovery)
                        Text("Supplement timing")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if appState.isTrainingDay {
                            Text("Training day")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Pulse.positive)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Pulse.positive.opacity(0.1))
                                .clipShape(Capsule())
                        } else {
                            Text("Rest day")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Pulse.textTertiary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Pulse.surfaceElevatedFallback)
                                .clipShape(Capsule())
                        }
                    }

                    // Timeline
                    VStack(spacing: 0) {
                        ForEach(Array(timelineEntries.enumerated()), id: \.element.id) { index, entry in
                            HStack(alignment: .top, spacing: 10) {
                                // Timeline dot + line
                                VStack(spacing: 0) {
                                    Circle()
                                        .fill(entry.isPassed ? entry.color.opacity(0.3) : entry.color)
                                        .frame(width: 10, height: 10)
                                    if index < timelineEntries.count - 1 {
                                        Rectangle()
                                            .fill(Pulse.surfaceElevatedFallback)
                                            .frame(width: 2)
                                            .frame(maxHeight: .infinity)
                                    }
                                }
                                .frame(width: 10)

                                // Content
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(entry.timeLabel)
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(entry.isPassed ? .secondary : entry.color)
                                            .frame(width: 50, alignment: .leading)

                                        Image(systemName: entry.icon)
                                            .font(.system(size: 10))
                                            .foregroundColor(entry.color)

                                        Text(entry.name)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(entry.isPassed ? .secondary : .primary)
                                            .strikethrough(entry.isPassed)

                                        Text(entry.dose)
                                            .font(.system(size: 10))
                                            .foregroundColor(Pulse.textTertiary)
                                    }

                                    Text(entry.rationale)
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary.opacity(0.8))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.bottom, index < timelineEntries.count - 1 ? 10 : 0)

                                Spacer(minLength: 0)
                            }
                        }
                    }

                    Text("Timing from ISSN position stands. Creatine: Kreider et al. 2017. Caffeine: Goldstein et al. 2010. Protein: Schoenfeld & Aragon 2018.")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { buildTimeline() }
    }

    // MARK: - Build Timeline

    private func buildTimeline() {
        let supplements = UserSupplementStore.active(context: modelContext)
        guard !supplements.isEmpty else { return }
        hasSupplements = true

        let isTrainingDay = appState.isTrainingDay
        let currentHour = Calendar.current.component(.hour, from: Date())

        // Estimate training time (use user's typical time or default 17:00)
        let trainingHour = 17

        var entries: [TimingEntry] = []

        for supp in supplements {
            let nameLC = supp.name.lowercased()
            let timing = classifyTiming(name: nameLC, isTrainingDay: isTrainingDay, trainingHour: trainingHour)

            entries.append(TimingEntry(
                name: supp.name,
                dose: supp.dose,
                timeLabel: timing.label,
                hour: timing.hour,
                icon: timing.icon,
                color: timing.color,
                rationale: timing.rationale,
                isPassed: currentHour > timing.hour
            ))
        }

        // Sort by hour
        timelineEntries = entries.sorted { $0.hour < $1.hour }
    }

    private struct TimingInfo {
        let label: String
        let hour: Int
        let icon: String
        let color: Color
        let rationale: String
    }

    private func classifyTiming(name: String, isTrainingDay: Bool, trainingHour: Int) -> TimingInfo {
        // Caffeine
        if name.contains("caffeine") || name.contains("pre-workout") || name.contains("pre workout") {
            let hour = isTrainingDay ? max(6, trainingHour - 1) : 8
            let label = isTrainingDay ? "\(formatHour(hour))" : "Morning"
            return TimingInfo(
                label: label,
                hour: hour,
                icon: "bolt.fill",
                color: Pulse.nutrition,
                rationale: isTrainingDay
                    ? "30-60 min before training for peak effect (Goldstein 2010). Avoid after 2pm for sleep quality."
                    : "Morning only on rest days. Skip if sleep was poor — caffeine masks fatigue without resolving it."
            )
        }

        // Creatine
        if name.contains("creatine") {
            let hour = isTrainingDay ? trainingHour + 1 : 9
            return TimingInfo(
                label: isTrainingDay ? "Post-train" : "Morning",
                hour: hour,
                icon: "atom",
                color: Pulse.hydration,
                rationale: "Timing doesn't matter (ISSN 2017), but post-workout with carbs may slightly improve muscle uptake."
            )
        }

        // Protein
        if name.contains("protein") || name.contains("whey") || name.contains("casein") {
            let hour = isTrainingDay ? trainingHour + 1 : 12
            return TimingInfo(
                label: isTrainingDay ? "Post-train" : "With meal",
                hour: hour,
                icon: "fork.knife",
                color: Pulse.positive,
                rationale: isTrainingDay
                    ? "Within 2h post-training. Total daily intake matters more than timing (Schoenfeld & Aragon 2018)."
                    : "Distribute evenly across meals — 20-40g per serving for optimal MPS."
            )
        }

        // Vitamin D
        if name.contains("vitamin d") || name.contains("d3") {
            return TimingInfo(
                label: "Breakfast",
                hour: 8,
                icon: "sun.max.fill",
                color: Pulse.nutrition,
                rationale: "Take with a fat-containing meal for absorption (Dawson-Hughes 2017)."
            )
        }

        // Fish oil / omega-3
        if name.contains("fish oil") || name.contains("omega") {
            return TimingInfo(
                label: "With meal",
                hour: 12,
                icon: "drop.fill",
                color: Pulse.recovery,
                rationale: "With food for absorption. Split dose if taking >2g (Schuchardt & Hahn 2013)."
            )
        }

        // Magnesium
        if name.contains("magnesium") || name.contains("mg ") {
            return TimingInfo(
                label: "Evening",
                hour: 21,
                icon: "moon.fill",
                color: Pulse.ai,
                rationale: "Evening dosing may support sleep quality and muscle recovery (Abbasi et al. 2012)."
            )
        }

        // Beta-alanine
        if name.contains("beta-alanine") || name.contains("beta alanine") {
            return TimingInfo(
                label: "Any time",
                hour: 10,
                icon: "sparkles",
                color: Pulse.recovery,
                rationale: "Timing doesn't matter — beta-alanine works by saturation, not acute effect (ISSN 2015). Split to reduce tingling."
            )
        }

        // ZMA / Zinc
        if name.contains("zma") || name.contains("zinc") {
            return TimingInfo(
                label: "Bedtime",
                hour: 22,
                icon: "moon.stars.fill",
                color: Pulse.ai,
                rationale: "Take on empty stomach before bed. Don't combine with calcium — it blocks zinc absorption."
            )
        }

        // Default
        return TimingInfo(
            label: "With meal",
            hour: 9,
            icon: "pill.fill",
            color: Pulse.positive,
            rationale: "Follow the dosing instructions on the label."
        )
    }

    private func formatHour(_ hour: Int) -> String {
        if hour == 12 { return "12pm" }
        if hour > 12 { return "\(hour - 12)pm" }
        return "\(hour)am"
    }
}
