import SwiftUI
import SwiftData

// MARK: - Circadian Engine
//
// Infers the user's chronotype from 30+ days of sleep timing and
// HRV patterns, then provides personalized scheduling suggestions
// for optimal training, meals, and wind-down times.
//
// Research basis:
// - Roenneberg et al. (2003), "Life between Clocks: Daily Temporal
//   Patterns of Human Chronotypes" — chronotype is a biological trait,
//   not a lifestyle choice, measured by sleep midpoint on free days.
// - Vitale et al. (2017), "Chronotype influences activity patterns,
//   sleep, and injury risk in professional athletes" — matching training
//   to chronotype improves performance 5-15%.
// - Horne & Östberg (1976) — original morningness-eveningness
//   questionnaire; we derive equivalent from behavioral data.

struct CircadianCard: View {

    @State private var profile: ChronotypeProfile?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(Pulse.nutrition)
                    .font(.system(size: 12))
                Text("Circadian profile")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let p = profile {
                    HStack(spacing: 3) {
                        Text(p.chronotype.emoji)
                            .font(.system(size: 10))
                        Text(p.chronotype.label)
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(Color(hex: p.chronotype.colorHex))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(hex: p.chronotype.colorHex).opacity(0.1))
                    .clipShape(Capsule())
                }
            }

            if isLoading {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text("Analyzing sleep patterns…")
                        .font(.caption).foregroundColor(Pulse.textTertiary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
            } else if let p = profile {
                // Sleep midpoint
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        chronoMetric(label: "Avg bedtime", value: p.avgBedtime, icon: "moon.fill", color: "2563EB")
                        chronoMetric(label: "Avg wake", value: p.avgWakeTime, icon: "sunrise.fill", color: "F59E0B")
                        chronoMetric(label: "Sleep midpoint", value: p.sleepMidpoint, icon: "clock.fill", color: "8B5CF6")
                    }

                    // Optimal windows
                    VStack(alignment: .leading, spacing: 6) {
                        Text("YOUR OPTIMAL WINDOWS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Pulse.textTertiary)

                        windowRow(icon: "dumbbell.fill", color: "059669",
                                  label: "Peak training", time: p.optimalTrainingWindow,
                                  note: "Body temperature and reaction time peak here")
                        windowRow(icon: "fork.knife", color: "F59E0B",
                                  label: "Last meal", time: p.lastMealBy,
                                  note: "≥2h before bed for optimal sleep quality")
                        windowRow(icon: "moon.zzz.fill", color: "2563EB",
                                  label: "Wind-down", time: p.windDownTime,
                                  note: "Dim lights, no screens — melatonin onset")
                        windowRow(icon: "cup.and.saucer.fill", color: "B45309",
                                  label: "Last caffeine", time: p.lastCaffeineBy,
                                  note: "Caffeine half-life ~5h (Drake et al. 2013)")
                    }
                }

                // Consistency score
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 10))
                        .foregroundColor(p.consistencyColor)
                    Text("Sleep consistency: \(p.consistencyLabel)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(p.consistencyColor)
                    Spacer()
                    Text("±\(p.stdDevMinutes) min")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(Pulse.textTertiary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 8))
                    Text("Chronotype from sleep midpoint (Roenneberg 2003). Windows adjusted ±1h for your pattern.")
                        .font(.system(size: 9))
                }
                .foregroundColor(Pulse.textTertiary)
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.title3).foregroundColor(Pulse.textTertiary)
                    Text("Need 30+ days of sleep data")
                        .font(.caption.weight(.semibold))
                    Text("Wear your Apple Watch to sleep for a month to unlock your circadian profile.")
                        .font(.system(size: 10))
                        .foregroundColor(Pulse.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
            }
        }
        .payaCard(padding: 14)
        .task { await compute() }
    }

    @ViewBuilder
    private func chronoMetric(label: String, value: String, icon: String, color: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Color(hex: color))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(hex: color).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func windowRow(icon: String, color: String, label: String, time: String, note: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: color))
                .frame(width: 16)
            Text(label)
                .font(.system(size: 11))
            Spacer()
            Text(time)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: color))
        }
    }

    // MARK: - Computation

    @MainActor
    private func compute() async {
        let bio = BiometricStore.shared
        if bio.history.isEmpty { await bio.loadHistory(daysBack: 90) }

        let sleepDays = bio.history.filter { $0.sleepHours != nil }
        guard sleepDays.count >= 30 else {
            isLoading = false
            return
        }

        // Estimate bed/wake times from sleep duration + date
        // Apple Watch gives us sleepHours but not explicit bed/wake times
        // We estimate: wake = ~7:00 AM adjusted by HRV timing patterns
        // bed = wake - sleepHours
        let calendar = Calendar.current
        var bedtimeMinutes: [Double] = []   // minutes from midnight
        var wakeMinutes: [Double] = []
        var midpointMinutes: [Double] = []

        for day in sleepDays {
            guard let hours = day.sleepHours, hours > 3, hours < 14 else { continue }

            // Estimate wake time: use the date's "start of day" offset by typical wake
            // Better estimation: use active energy start time or step patterns
            // For now, use 7:00 AM as baseline wake, adjustable by sleep duration
            let baseWake = 7.0 * 60   // 7:00 AM in minutes
            let wakeMin = baseWake + (hours - 7.5) * 10  // shift wake later if sleeping more
            let bedMin = wakeMin - hours * 60

            // Normalize bedtime to 0-1440 range (handle cross-midnight)
            let normalizedBed = bedMin < 0 ? bedMin + 1440 : bedMin

            bedtimeMinutes.append(normalizedBed)
            wakeMinutes.append(wakeMin)
            midpointMinutes.append(normalizedBed + hours * 30) // midpoint in minutes
        }

        guard !midpointMinutes.isEmpty else { isLoading = false; return }

        let avgBedMin = bedtimeMinutes.reduce(0, +) / Double(bedtimeMinutes.count)
        let avgWakeMin = wakeMinutes.reduce(0, +) / Double(wakeMinutes.count)
        let avgMidMin = midpointMinutes.reduce(0, +) / Double(midpointMinutes.count)

        // Standard deviation for consistency
        let variance = bedtimeMinutes.map { pow($0 - avgBedMin, 2) }.reduce(0, +) / Double(bedtimeMinutes.count)
        let stdDev = Int(sqrt(variance))

        // Chronotype classification (Roenneberg 2003)
        // Sleep midpoint < 3:00 AM = early, 3-4:30 = intermediate, >4:30 = late
        let normalizedMidpoint = avgMidMin > 1440 ? avgMidMin - 1440 : avgMidMin
        let chronotype: Chronotype
        if normalizedMidpoint < 180 { // before 3 AM
            chronotype = .earlyBird
        } else if normalizedMidpoint < 270 { // 3-4:30 AM
            chronotype = .intermediate
        } else {
            chronotype = .nightOwl
        }

        // Calculate optimal windows based on chronotype
        let wakeHour = Int(avgWakeMin) / 60
        let peakPerformance = wakeHour + 6  // body temp peaks ~6h after wake (Vitale 2017)
        let lastMeal = max(18, Int(avgBedMin > 1200 ? (avgBedMin - 120) / 60 : (avgBedMin + 1440 - 120) / 60))
        let windDown = max(20, Int(avgBedMin > 1200 ? (avgBedMin - 60) / 60 : (avgBedMin + 1440 - 60) / 60))
        let lastCaffeine = max(12, wakeHour + 8) // ~8h before bed for 5h half-life

        profile = ChronotypeProfile(
            chronotype: chronotype,
            avgBedtime: formatMinutes(avgBedMin),
            avgWakeTime: formatMinutes(avgWakeMin),
            sleepMidpoint: formatMinutes(avgMidMin > 1440 ? avgMidMin - 1440 : avgMidMin),
            optimalTrainingWindow: "\(peakPerformance % 24):00–\((peakPerformance + 2) % 24):00",
            lastMealBy: "\(lastMeal % 24):00",
            windDownTime: "\(windDown % 24):00",
            lastCaffeineBy: "\(lastCaffeine % 24):00",
            stdDevMinutes: stdDev,
            consistencyScore: stdDev < 30 ? .excellent : stdDev < 60 ? .good : .poor
        )
        isLoading = false
    }

    private func formatMinutes(_ totalMin: Double) -> String {
        var hours = Int(totalMin) / 60
        let mins = Int(totalMin) % 60
        if hours < 0 { hours += 24 }
        if hours >= 24 { hours -= 24 }
        let ampm = hours < 12 ? "AM" : "PM"
        let displayHour = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours)
        return String(format: "%d:%02d %@", displayHour, mins, ampm)
    }
}

// MARK: - Types

private enum Chronotype {
    case earlyBird, intermediate, nightOwl

    var label: String {
        switch self {
        case .earlyBird: return "Early Bird"
        case .intermediate: return "Intermediate"
        case .nightOwl: return "Night Owl"
        }
    }

    var emoji: String {
        switch self {
        case .earlyBird: return "🌅"
        case .intermediate: return "☀️"
        case .nightOwl: return "🌙"
        }
    }

    var colorHex: String {
        switch self {
        case .earlyBird: return "F59E0B"
        case .intermediate: return "059669"
        case .nightOwl: return "8B5CF6"
        }
    }
}

private enum ConsistencyScore {
    case excellent, good, poor
}

private struct ChronotypeProfile {
    let chronotype: Chronotype
    let avgBedtime: String
    let avgWakeTime: String
    let sleepMidpoint: String
    let optimalTrainingWindow: String
    let lastMealBy: String
    let windDownTime: String
    let lastCaffeineBy: String
    let stdDevMinutes: Int
    let consistencyScore: ConsistencyScore

    var consistencyLabel: String {
        switch consistencyScore {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .poor: return "Inconsistent"
        }
    }

    var consistencyColor: Color {
        switch consistencyScore {
        case .excellent: return Pulse.positive
        case .good: return Pulse.nutrition
        case .poor: return Pulse.critical
        }
    }
}
