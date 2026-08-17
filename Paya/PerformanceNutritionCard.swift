import SwiftUI
import SwiftData

// MARK: - Performance ↔ Nutrition Correlation Card
// The #1 gap in fitness apps: showing how nutrition ACTUALLY affects
// training performance. No competitor does this — Whoop ignores lifting
// specifics, Strong ignores nutrition, MFP ignores training.
// This card answers "did eating well yesterday make me train better today?"
// by pairing nutrition logs with next-day session quality metrics.
//
// Grounded in: Slater & Phillips (2011) "Nutrition guidelines for strength
// sports" — protein timing and total daily protein intake are the two
// nutrition variables most consistently linked to training performance.

struct PerformanceNutritionCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var pairs: [DayPair] = []
    @State private var proteinCorrelation: CorrelationResult?
    @State private var calorieCorrelation: CorrelationResult?
    @State private var sleepCorrelation: CorrelationResult?

    var body: some View {
        Group {
            if pairs.count >= 5 {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "link.circle.fill")
                            .foregroundColor(Pulse.ai)
                        Text("What's driving your gains?")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(pairs.count) sessions analyzed")
                            .font(.system(size: 8))
                            .foregroundColor(Pulse.textTertiary)
                    }

                    // Correlation rows
                    if let protein = proteinCorrelation {
                        correlationRow(
                            icon: "p.circle.fill",
                            label: "Protein hit → session volume",
                            correlation: protein,
                            color: Pulse.hydration
                        )
                    }

                    if let cal = calorieCorrelation {
                        correlationRow(
                            icon: "c.circle.fill",
                            label: "Calorie hit → session volume",
                            correlation: cal,
                            color: Pulse.nutrition
                        )
                    }

                    if let sleep = sleepCorrelation {
                        correlationRow(
                            icon: "moon.fill",
                            label: "Sleep 7h+ → session volume",
                            correlation: sleep,
                            color: Pulse.ai
                        )
                    }

                    // Key insight
                    if let best = bestDriver {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Pulse.nutrition)
                                .padding(.top, 1)
                            Text(best)
                                .font(.system(size: 10))
                                .foregroundColor(Pulse.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Text("Based on pairing your nutrition/sleep the day before each training session with that session's total volume. Requires 5+ paired data points.")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func correlationRow(icon: String, label: String, correlation: CorrelationResult, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                HStack(spacing: 4) {
                    Text(correlation.direction)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(correlation.directionColor)
                    Text(String(format: "%.0f%% more volume on good days", correlation.percentDiff))
                        .font(.system(size: 9))
                        .foregroundColor(Pulse.textTertiary)
                }
            }

            Spacer()

            // Visual bar
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.3))
                    .frame(width: 30, height: 8)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: max(4, 30 * CGFloat(min(1, correlation.percentDiff / 20))), height: 8)
            }
        }
        .padding(8)
        .background(color.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var bestDriver: String? {
        var results: [(String, Double)] = []
        if let p = proteinCorrelation { results.append(("protein", p.percentDiff)) }
        if let c = calorieCorrelation { results.append(("calorie", c.percentDiff)) }
        if let s = sleepCorrelation { results.append(("sleep", s.percentDiff)) }

        guard let best = results.max(by: { $0.1 < $1.1 }), best.1 > 3 else {
            if results.allSatisfy({ $0.1 < 3 }) && !results.isEmpty {
                return "No strong correlation yet — your training performance is consistent regardless of nutrition/sleep variations. That's a sign of good habits."
            }
            return nil
        }

        switch best.0 {
        case "protein":
            return String(format: "Protein is your biggest performance driver — sessions after hitting your protein target produce %.0f%% more volume. Prioritize protein the day before heavy sessions.", best.1)
        case "calorie":
            return String(format: "Calorie intake matters most — sessions after hitting calorie targets produce %.0f%% more volume. Don't under-eat before training days.", best.1)
        case "sleep":
            return String(format: "Sleep is your biggest lever — sessions after 7+ hours produce %.0f%% more volume. Protect your sleep before big training days.", best.1)
        default:
            return nil
        }
    }

    private func compute() {
        let calendar = Calendar.current
        let pid = ActiveProfile.id
        let twelveWeeksAgo = calendar.date(byAdding: .day, value: -84, to: Date())!

        // Fetch sessions
        let sessionDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> {
                $0.profileId == pid && $0.isCompleted && $0.date >= twelveWeeksAgo
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let sessions = try? modelContext.fetch(sessionDescriptor) else { return }

        // Fetch nutrition logs
        let nutritionDescriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> {
                $0.profileId == pid && $0.date >= twelveWeeksAgo
            }
        )
        let nutritionLogs = (try? modelContext.fetch(nutritionDescriptor)) ?? []
        let nutritionByDay: [Date: NutritionLog] = Dictionary(
            nutritionLogs.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { a, _ in a }
        )

        // Fetch health logs for sleep
        let healthDescriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> {
                $0.profileId == pid && $0.date >= twelveWeeksAgo
            }
        )
        let healthLogs = (try? modelContext.fetch(healthDescriptor)) ?? []
        let healthByDay: [Date: HealthLog] = Dictionary(
            healthLogs.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { a, _ in a }
        )

        // Pair: nutrition/sleep on day N → session volume on day N+1
        var dayPairs: [DayPair] = []
        for session in sessions {
            let sessionDay = calendar.startOfDay(for: session.date)
            let dayBefore = calendar.date(byAdding: .day, value: -1, to: sessionDay)!

            let volume = session.exercises.reduce(0.0) { total, log in
                total + log.sets.filter(\.isCompleted).reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
            }
            guard volume > 0 else { continue }

            let nutrition = nutritionByDay[dayBefore]
            let health = healthByDay[dayBefore]

            dayPairs.append(DayPair(
                sessionVolume: volume,
                proteinHit: nutrition.map { $0.totalProtein >= $0.proteinTarget * 0.9 },
                calorieHit: nutrition.map { $0.totalCalories >= $0.calorieTarget * 0.9 },
                sleepGood: health.map { $0.sleepHours >= 7 }
            ))
        }

        pairs = dayPairs
        guard dayPairs.count >= 5 else { return }

        // Compute correlations
        proteinCorrelation = computeCorrelation(pairs: dayPairs, keyPath: \.proteinHit)
        calorieCorrelation = computeCorrelation(pairs: dayPairs, keyPath: \.calorieHit)
        sleepCorrelation = computeCorrelation(pairs: dayPairs, keyPath: \.sleepGood)
    }

    private func computeCorrelation(pairs: [DayPair], keyPath: KeyPath<DayPair, Bool?>) -> CorrelationResult? {
        let withData = pairs.filter { $0[keyPath: keyPath] != nil }
        guard withData.count >= 4 else { return nil }

        let good = withData.filter { $0[keyPath: keyPath] == true }
        let bad = withData.filter { $0[keyPath: keyPath] == false }
        guard !good.isEmpty && !bad.isEmpty else { return nil }

        let goodAvg = good.map(\.sessionVolume).reduce(0, +) / Double(good.count)
        let badAvg = bad.map(\.sessionVolume).reduce(0, +) / Double(bad.count)

        guard badAvg > 0 else { return nil }
        let diff = ((goodAvg - badAvg) / badAvg) * 100

        return CorrelationResult(
            percentDiff: abs(diff),
            direction: diff > 3 ? "Positive" : diff < -3 ? "Negative" : "Neutral",
            directionColor: diff > 3 ? Pulse.positive : diff < -3 ? Pulse.critical : .secondary
        )
    }
}

private struct DayPair {
    let sessionVolume: Double
    let proteinHit: Bool?
    let calorieHit: Bool?
    let sleepGood: Bool?
}

private struct CorrelationResult {
    let percentDiff: Double
    let direction: String
    let directionColor: Color
}
