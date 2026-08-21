import SwiftUI

// MARK: - Sleep Debt Tracker
//
// Calculates accumulated sleep debt over the past 14 days relative
// to the National Sleep Foundation's 7-9h recommendation (Hirshkowitz
// et al. 2015, "National Sleep Foundation's sleep time duration
// recommendations"). Sleep debt is not a simple sum — it follows a
// decay model where older debt contributes less (Van Dongen et al.
// 2003, "The cumulative cost of additional wakefulness").
//
// Why this matters for training: sleep debt above 5 hours impairs
// testosterone production (Leproult & Van Cauter 2011), reduces
// glycogen resynthesis, and increases cortisol — all directly
// reducing training adaptations.

struct SleepDebtCard: View {

    @State private var sleepDebt: Double = 0
    @State private var recentSleep: [(day: String, hours: Double)] = []
    @State private var loaded = false

    private let targetHours: Double = 8.0  // midpoint of 7-9h recommendation

    var body: some View {
        Group {
            if loaded, !recentSleep.isEmpty {
                cardView
            }
        }
        .onAppear { compute() }
    }

    private var cardView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(debtColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 12))
                        .foregroundColor(debtColor)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("SLEEP DEBT")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(debtColor)
                    Text(debtLabel)
                        .font(.caption.weight(.semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(String(format: "%.1fh", abs(sleepDebt)))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(debtColor)
                    Text(sleepDebt <= 0 ? "surplus" : "debt")
                        .font(.system(size: 9))
                        .foregroundColor(Pulse.textTertiary)
                }
            }

            // Mini sparkline of last 7 days
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(recentSleep.suffix(7), id: \.day) { entry in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor(for: entry.hours))
                            .frame(width: 18, height: max(4, CGFloat(entry.hours / 12.0) * 40))

                        Text(entry.day)
                            .font(.system(size: 7))
                            .foregroundColor(Pulse.textTertiary)
                    }
                }
                Spacer()
            }

            // Target line label
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Pulse.positive.opacity(0.4))
                    .frame(width: 12, height: 1)
                Text("8h target")
                    .font(.system(size: 8))
                    .foregroundColor(Pulse.textTertiary)
            }

            Text(recommendation)
                .font(.system(size: 10))
                .foregroundColor(Pulse.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(1)
        }
        .payaCard(padding: 14)
    }

    // MARK: - Compute

    private func compute() {
        let store = BiometricStore.shared
        let history = store.history.suffix(14)

        guard !history.isEmpty else {
            loaded = true
            return
        }

        _ = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"

        var debt: Double = 0
        var entries: [(day: String, hours: Double)] = []

        for (index, summary) in history.enumerated() {
            let hours = summary.sleepHours ?? 0
            let deficit = targetHours - hours

            // Decay: older nights contribute less (half-life ~5 days)
            let daysAgo = Double(history.count - 1 - index)
            let weight = pow(0.87, daysAgo) // ~50% decay at 5 days

            debt += deficit * weight

            let dayLabel = formatter.string(from: summary.date)
            entries.append((day: dayLabel, hours: hours))
        }

        sleepDebt = max(-5, debt)  // cap surplus to avoid noise
        recentSleep = entries
        loaded = true
    }

    // MARK: - Presentation

    private var debtColor: Color {
        if sleepDebt <= 0 { return Pulse.positive }
        if sleepDebt < 3 { return Pulse.nutrition }
        return Pulse.critical
    }

    private var debtLabel: String {
        if sleepDebt <= 0 { return "Fully recovered" }
        if sleepDebt < 3 { return "Mild — manageable" }
        if sleepDebt < 5 { return "Moderate — prioritize sleep" }
        return "High — recovery impaired"
    }

    private var recommendation: String {
        if sleepDebt <= 0 {
            return "You're at or above your sleep target. Consistent sleep is one of the strongest predictors of training adaptation."
        }
        if sleepDebt < 3 {
            return "A small debt — an extra 30 min tonight can close this gap. Avoid caffeine after 2pm."
        }
        if sleepDebt < 5 {
            return "Sleep debt this high reduces testosterone and growth hormone output (Leproult 2011). Consider lighter sessions until you've caught up."
        }
        return "Severe sleep debt impairs reaction time, immune function, and muscle recovery. Prioritize 9h nights for the next 3 days."
    }

    private func barColor(for hours: Double) -> Color {
        if hours >= 7 { return Pulse.positive }
        if hours >= 6 { return Pulse.nutrition }
        return Pulse.critical
    }
}
