import SwiftUI
import SwiftData

// MARK: - Optimal Training Window Card
// Predicts the user's best training window today based on circadian
// performance research and their actual sleep data.
//
// Grounded in:
// - Chtourou & Souissi (2012): peak neuromuscular performance occurs
//   at body temperature maximum, typically 16:00–19:00 for "neither"
//   chronotypes, shifted earlier for morning types and later for
//   evening types.
// - Sedliak et al. (2009): training consistently at the same time of
//   day yields 22% better strength adaptations than varying times.
// - Küüsmaa et al. (2016): afternoon training shows 3-8% higher
//   peak force output vs morning training in untrained populations.
//
// The card uses wake time (from sleep data) as a chronotype proxy —
// wake before 06:30 = morning type (shift window 2h earlier),
// wake after 08:30 = evening type (shift window 1h later),
// otherwise = neutral (standard 16:00–19:00 peak).

struct OptimalTrainingWindowCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var windowStart = ""
    @State private var windowEnd = ""
    @State private var chronotype = ""
    @State private var sleepHours: Double?
    @State private var wakeTime: String?
    @State private var hoursUntilWindow: Int?
    @State private var isInWindow = false
    @State private var hasData = false
    @State private var consistencyNote: String?

    var body: some View {
        Group {
            if hasData {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "clock.badge.checkmark.fill")
                            .foregroundColor(Color(hex: "8B5CF6"))
                        Text("Optimal training window")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(chronotype)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "8B5CF6"))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color(hex: "8B5CF6").opacity(0.1))
                            .clipShape(Capsule())
                    }

                    // Time window display
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(windowStart)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                Text("–")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.secondary)
                                Text(windowEnd)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                            }

                            if isInWindow {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: "059669"))
                                        .frame(width: 6, height: 6)
                                    Text("You're in the window now")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color(hex: "059669"))
                                }
                            } else if let hours = hoursUntilWindow {
                                if hours > 0 {
                                    Text("In ~\(hours) hours")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Window passed for today")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Spacer()

                        // Timeline visual
                        timelineVisual()
                    }

                    // Sleep context
                    if let sleep = sleepHours, let wake = wakeTime {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(Color(hex: "8B5CF6"))
                                Text(String(format: "%.1fh sleep", sleep))
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            HStack(spacing: 4) {
                                Image(systemName: "sunrise.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(Color(hex: "F59E0B"))
                                Text("Woke ~\(wake)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Consistency note
                    if let note = consistencyNote {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "F59E0B"))
                                .padding(.top, 1)
                            Text(note)
                                .font(.system(size: 10))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Text("Chtourou & Souissi (2012): neuromuscular peak at body temp max. Sedliak et al. (2009): consistent training time → 22% better strength gains.")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    // MARK: - Timeline Visual

    private func timelineVisual() -> some View {
        let currentHour = Calendar.current.component(.hour, from: Date())
        return VStack(spacing: 3) {
            HStack(spacing: 2) {
                ForEach(6..<23, id: \.self) { hour in
                    let isWindow = isHourInWindow(hour)
                    let isCurrent = hour == currentHour
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            isCurrent ? Color(hex: "DC2626") :
                            isWindow ? Color(hex: "8B5CF6") :
                            Color(.tertiarySystemBackground)
                        )
                        .frame(width: 6, height: isCurrent ? 18 : (isWindow ? 14 : 10))
                }
            }
            HStack {
                Text("6am")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
                Spacer()
                Text("10pm")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
            }
            .frame(width: CGFloat((23 - 6) * 8))
        }
    }

    private func isHourInWindow(_ hour: Int) -> Bool {
        guard let startH = windowStartHour, let endH = windowEndHour else { return false }
        return hour >= startH && hour < endH
    }

    @State private var windowStartHour: Int?
    @State private var windowEndHour: Int?

    // MARK: - Compute

    private func compute() {
        let calendar = Calendar.current
        let pid = ActiveProfile.id
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Get sleep data
        let healthDesc = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> {
                $0.profileId == pid && $0.date >= yesterday
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let healthLog = (try? modelContext.fetch(healthDesc))?.first
        sleepHours = healthLog?.sleepHours

        // Estimate wake time from sleep hours
        // Assume bedtime ~23:00 if no data, derive wake from sleep duration
        let sleep = healthLog?.sleepHours ?? 7.0
        let estimatedWakeHour = 23.0 + sleep
        let normalizedWake = estimatedWakeHour >= 24 ? estimatedWakeHour - 24 : estimatedWakeHour
        let wakeHour = Int(normalizedWake)
        let wakeMinute = Int((normalizedWake - Double(wakeHour)) * 60)
        wakeTime = String(format: "%d:%02d", wakeHour, wakeMinute)

        // Determine chronotype and window
        var peakStart: Int
        var peakEnd: Int

        if normalizedWake < 6.5 {
            // Early bird — shift window earlier
            chronotype = "Early bird"
            peakStart = 14
            peakEnd = 17
        } else if normalizedWake > 8.5 {
            // Night owl — shift window later
            chronotype = "Night owl"
            peakStart = 17
            peakEnd = 20
        } else {
            // Neutral
            chronotype = "Neutral"
            peakStart = 16
            peakEnd = 19
        }

        // Adjust if sleep-deprived (< 6h) — delay by 1h
        if sleep < 6 {
            peakStart += 1
            peakEnd += 1
        }

        windowStartHour = peakStart
        windowEndHour = peakEnd
        windowStart = String(format: "%d:00", peakStart > 12 ? peakStart - 12 : peakStart)
        windowEnd = String(format: "%d:00", peakEnd > 12 ? peakEnd - 12 : peakEnd)
        if peakStart >= 12 { windowStart += "pm" }
        if peakEnd >= 12 { windowEnd += "pm" }

        // Current position relative to window
        let currentHour = calendar.component(.hour, from: Date())
        if currentHour >= peakStart && currentHour < peakEnd {
            isInWindow = true
        } else if currentHour < peakStart {
            hoursUntilWindow = peakStart - currentHour
        } else {
            hoursUntilWindow = -1
        }

        hasData = true

        // Check training time consistency
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        let sessionDesc = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> {
                $0.profileId == pid && $0.isCompleted && $0.date >= thirtyDaysAgo
            }
        )
        let sessions = (try? modelContext.fetch(sessionDesc)) ?? []
        if sessions.count >= 5 {
            let hours = sessions.map { calendar.component(.hour, from: $0.date) }
            let avgHour = Double(hours.reduce(0, +)) / Double(hours.count)
            let variance = hours.map { pow(Double($0) - avgHour, 2) }.reduce(0, +) / Double(hours.count)

            if variance > 9 { // SD > 3 hours
                consistencyNote = "Your training times vary a lot (SD > 3h). Sedliak et al. found consistent timing yields 22% better strength gains — try to train at a similar time each day."
            } else {
                let avgFormatted = String(format: "%d:%02d", Int(avgHour), Int((avgHour - Double(Int(avgHour))) * 60))
                consistencyNote = "You typically train around \(avgFormatted) — great consistency. Keep it up for optimal circadian adaptation."
            }
        }
    }
}
