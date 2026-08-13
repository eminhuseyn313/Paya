import SwiftUI
import SwiftData
import Charts

// MARK: - Training Time-of-Day Performance Analysis
// Analyzes whether the user performs better at certain times of day
// by correlating session timestamps with volume output, RPE, and
// session quality.
//
// Grounded in:
// - Sedliak et al. (2009): training consistently at the same time
//   produces 22% better strength gains vs random times.
// - Grgic et al. (2019) meta-analysis: afternoon training shows
//   small but significant advantages for maximal strength.
// - Chtourou & Souissi (2012): peak anaerobic output at 16:00-19:00
//   correlates with body temperature maximum.
//
// The card groups sessions into Morning (before 12:00), Afternoon
// (12:00–17:00), and Evening (after 17:00) and compares:
// - Average volume per session
// - Average RPE
// - Session count (consistency pattern)

struct TrainingTimeAnalysisCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var timeBrackets: [TimeBracket] = []
    @State private var bestBracket: String = ""
    @State private var insight: String = ""
    @State private var hasData = false
    @State private var totalSessions = 0

    struct TimeBracket: Identifiable {
        let name: String
        let icon: String
        let color: Color
        let sessionCount: Int
        let avgVolume: Double
        let avgRPE: Double?
        let timeRange: String
        var id: String { name }
    }

    var body: some View {
        Group {
            if hasData {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .foregroundColor(Color(hex: "F59E0B"))
                        Text("Best training time")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(totalSessions) sessions analyzed")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                    }

                    // Bar chart comparison
                    Chart(timeBrackets) { bracket in
                        BarMark(
                            x: .value("Time", bracket.name),
                            y: .value("Volume", appState.profile.prefersLbs ? bracket.avgVolume * 2.20462 : bracket.avgVolume)
                        )
                        .foregroundStyle(bracket.name == bestBracket
                            ? Color(hex: "059669")
                            : Color(.tertiarySystemBackground)
                        )
                        .cornerRadius(6)
                        .annotation(position: .top) {
                            VStack(spacing: 1) {
                                Text(String(format: "%.0f", appState.profile.prefersLbs ? bracket.avgVolume * 2.20462 : bracket.avgVolume))
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                Text(appState.profile.prefersLbs ? "lbs" : "kg")
                                    .font(.system(size: 7))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(height: 100)
                    .chartXAxis {
                        AxisMarks { AxisValueLabel().font(.system(size: 10)) }
                    }
                    .chartYAxis(.hidden)

                    // Detail rows
                    VStack(spacing: 6) {
                        ForEach(timeBrackets) { bracket in
                            bracketRow(bracket)
                        }
                    }

                    // Insight
                    if !insight.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "F59E0B"))
                                .padding(.top, 1)
                            Text(insight)
                                .font(.system(size: 10))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Text("Sedliak et al. (2009): consistent training time → 22% better gains. Grgic et al. (2019): afternoon shows small maximal strength advantage.")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { analyze() }
    }

    private func bracketRow(_ bracket: TimeBracket) -> some View {
        HStack(spacing: 8) {
            Image(systemName: bracket.icon)
                .font(.system(size: 11))
                .foregroundColor(bracket.color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(bracket.name)
                        .font(.system(size: 11, weight: .bold))
                    if bracket.name == bestBracket {
                        Text("BEST")
                            .font(.system(size: 7, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(hex: "059669"))
                            .clipShape(Capsule())
                    }
                }
                Text(bracket.timeRange)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("\(bracket.sessionCount) sessions")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                if let rpe = bracket.avgRPE {
                    Text(String(format: "RPE %.1f", rpe))
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(6)
        .background(bracket.name == bestBracket
            ? Color(hex: "059669").opacity(0.06)
            : Color(.tertiarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Analyze

    private func analyze() {
        let pid = ActiveProfile.id
        let calendar = Calendar.current

        // Fetch all completed sessions
        let sessionDesc = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> {
                $0.profileId == pid && $0.isCompleted
            },
            sortBy: [SortDescriptor(\.date)]
        )
        let sessions = (try? modelContext.fetch(sessionDesc)) ?? []
        guard sessions.count >= 5 else { return }

        totalSessions = sessions.count

        // Group by time bracket
        struct BracketAccumulator {
            var volumes: [Double] = []
            var rpes: [Int] = []
            var count: Int { volumes.count }
        }

        var morning = BracketAccumulator()
        var afternoon = BracketAccumulator()
        var evening = BracketAccumulator()

        for session in sessions {
            let hour = calendar.component(.hour, from: session.date)
            let volume = session.exercises.reduce(0.0) { t, ex in
                t + ex.sets.filter(\.isCompleted).reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
            }
            guard volume > 0 else { continue }

            if hour < 12 {
                morning.volumes.append(volume)
                if let rpe = session.subjectiveRPE { morning.rpes.append(rpe) }
            } else if hour < 17 {
                afternoon.volumes.append(volume)
                if let rpe = session.subjectiveRPE { afternoon.rpes.append(rpe) }
            } else {
                evening.volumes.append(volume)
                if let rpe = session.subjectiveRPE { evening.rpes.append(rpe) }
            }
        }

        func avgVolume(_ acc: BracketAccumulator) -> Double {
            acc.volumes.isEmpty ? 0 : acc.volumes.reduce(0, +) / Double(acc.count)
        }
        func avgRPE(_ acc: BracketAccumulator) -> Double? {
            acc.rpes.isEmpty ? nil : Double(acc.rpes.reduce(0, +)) / Double(acc.rpes.count)
        }

        let brackets: [(String, String, Color, String, BracketAccumulator)] = [
            ("Morning", "sunrise.fill", Color(hex: "F59E0B"), "Before 12pm", morning),
            ("Afternoon", "sun.max.fill", Color(hex: "059669"), "12pm – 5pm", afternoon),
            ("Evening", "moon.fill", Color(hex: "8B5CF6"), "After 5pm", evening),
        ]

        // Filter out brackets with no sessions
        let activeBrackets = brackets.filter { $0.4.count > 0 }
        guard activeBrackets.count >= 2 else { return }

        hasData = true

        timeBrackets = activeBrackets.map { b in
            TimeBracket(
                name: b.0,
                icon: b.1,
                color: b.2,
                sessionCount: b.4.count,
                avgVolume: avgVolume(b.4),
                avgRPE: avgRPE(b.4),
                timeRange: b.3
            )
        }

        // Find best bracket (highest avg volume)
        if let best = timeBrackets.max(by: { $0.avgVolume < $1.avgVolume }) {
            bestBracket = best.name

            // Calculate advantage
            let otherAvg = timeBrackets.filter { $0.name != bestBracket }
                .map(\.avgVolume)
                .reduce(0, +) / max(1, Double(timeBrackets.count - 1))

            if otherAvg > 0 {
                let advantage = ((best.avgVolume - otherAvg) / otherAvg) * 100

                if advantage > 10 {
                    insight = "You lift \(String(format: "%.0f%%", advantage)) more volume in the \(bestBracket.lowercased()). Lock in this time slot — Sedliak et al. found consistent timing alone adds 22% to strength gains."
                } else if advantage > 3 {
                    insight = "Slight \(bestBracket.lowercased()) advantage (\(String(format: "+%.0f%%", advantage)) volume). The difference is small — consistency matters more than optimal timing."
                } else {
                    insight = "Your performance is roughly equal across time brackets. This is actually ideal — you're not dependent on a specific training time."
                }
            }
        }
    }
}
