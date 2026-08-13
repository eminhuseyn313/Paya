import SwiftUI
import SwiftData

// MARK: - Training Volume Trend Alert
//
// Monitors weekly training volume (sets × reps × weight) and fires
// a dashboard card when:
// - Volume drops >25% vs 4-week rolling avg → detraining risk
// - Volume spikes >40% vs 4-week rolling avg → overreaching risk
//
// Research basis:
// - Schoenfeld et al. (2017), "Dose-response relationship between
//   weekly resistance training volume and increases in muscle mass"
//   — minimum effective volume ~10 sets/muscle/week.
// - Kreher & Schwartz (2012), "Overtraining Syndrome: A Practical
//   Guide" — acute:chronic workload ratio >1.5 increases injury risk.

// MARK: - Engine

enum VolumeAlertEngine {

    enum Alert {
        case drop(currentVol: Double, avgVol: Double, pctDrop: Double)
        case spike(currentVol: Double, avgVol: Double, pctSpike: Double)
    }

    @MainActor
    static func evaluate(context: ModelContext) -> Alert? {
        let calendar = Calendar.current
        let pid = ActiveProfile.id
        let now = Date()

        // Gather last 5 weeks of sessions (current + 4 prior for avg)
        guard let fiveWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -5, to: now) else { return nil }

        let desc = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> {
                $0.profileId == pid && $0.isCompleted && $0.date >= fiveWeeksAgo
            },
            sortBy: [SortDescriptor(\.date)]
        )
        guard let sessions = try? context.fetch(desc), sessions.count >= 3 else { return nil }

        // Bucket sessions by ISO week
        var weeklyVolume: [Int: Double] = [:]
        for session in sessions {
            let weekNum = calendar.component(.weekOfYear, from: session.date)
            let year = calendar.component(.yearForWeekOfYear, from: session.date)
            let key = year * 100 + weekNum
            let vol = sessionVolume(session)
            weeklyVolume[key, default: 0] += vol
        }

        let sortedWeeks = weeklyVolume.sorted { $0.key < $1.key }
        guard sortedWeeks.count >= 2 else { return nil }

        guard let currentWeekEntry = sortedWeeks.last else { return nil }
        let currentWeek = currentWeekEntry.value
        // Average of prior weeks (up to 4)
        let priorWeeks = sortedWeeks.dropLast().suffix(4)
        let avgVolume = priorWeeks.reduce(0.0) { $0 + $1.value } / Double(priorWeeks.count)

        guard avgVolume > 0 else { return nil }

        let ratio = currentWeek / avgVolume

        // Only alert on current week if we're past Wednesday (enough data)
        let weekday = calendar.component(.weekday, from: now)
        guard weekday >= 4 else { return nil }  // Wed=4 in gregorian

        if ratio < 0.75 {
            return .drop(currentVol: currentWeek, avgVol: avgVolume, pctDrop: (1 - ratio) * 100)
        } else if ratio > 1.4 {
            return .spike(currentVol: currentWeek, avgVol: avgVolume, pctSpike: (ratio - 1) * 100)
        }

        return nil
    }

    private static func sessionVolume(_ session: TrainingSession) -> Double {
        // Volume = total tonnage (sets × reps × weight) for weighted exercises
        // + set count for bodyweight exercises
        var total: Double = 0
        for exercise in session.exercises {
            for set in exercise.sets where set.isCompleted {
                if set.weightKg > 0 {
                    total += Double(set.reps) * set.weightKg
                } else {
                    total += Double(set.reps) // bodyweight: count reps as volume
                }
            }
        }
        return total
    }
}

// MARK: - Card

struct VolumeAlertCard: View {

    @Environment(\.modelContext) private var modelContext
    @State private var alert: VolumeAlertEngine.Alert?

    var body: some View {
        Group {
            if let alert = alert {
                alertView(alert)
            }
        }
        .onAppear {
            alert = VolumeAlertEngine.evaluate(context: modelContext)
        }
    }

    @ViewBuilder
    private func alertView(_ alert: VolumeAlertEngine.Alert) -> some View {
        switch alert {
        case .drop(let current, let avg, let pct):
            volumeCard(
                icon: "arrow.down.right.circle.fill",
                colorHex: "F59E0B",
                title: "Volume is dropping",
                message: String(format: "This week's volume is %.0f%% below your 4-week average (%.0f kg vs %.0f kg). A temporary dip is fine — deloads help — but sustained drops can slow progress.", pct, current, avg),
                source: "Schoenfeld et al. (2017) — minimum effective dose"
            )
        case .spike(let current, let avg, let pct):
            volumeCard(
                icon: "arrow.up.right.circle.fill",
                colorHex: "DC2626",
                title: "Volume spike detected",
                message: String(format: "This week's volume is %.0f%% above your 4-week average (%.0f kg vs %.0f kg). Rapid jumps increase injury risk. Consider distributing the increase across 2-3 weeks.", pct, current, avg),
                source: "Kreher & Schwartz (2012) — acute:chronic workload ratio"
            )
        }
    }

    private func volumeCard(icon: String, colorHex: String, title: String, message: String, source: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(hex: colorHex).opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: colorHex))
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("VOLUME")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color(hex: colorHex))
            }

            Text(message)
                .font(.system(size: 11))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(1.5)

            HStack(spacing: 3) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 8))
                Text(source)
                    .font(.system(size: 9))
            }
            .foregroundColor(.secondary)
        }
        .payaCard(padding: 14)
    }
}
