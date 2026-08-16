import SwiftUI
import SwiftData
import Charts

// MARK: - Mood → Performance Correlation Card
// Tracks pre-session mood/stress/motivation and correlates with actual
// session volume output. Shows users which mental states predict their
// best (and worst) training sessions.
//
// Grounded in:
// - Hackford et al. (2019): pre-exercise psychological state accounts
//   for 15-20% of performance variance in resistance training.
// - Lane & Terry (2000): mood profiles before competition predict
//   performance outcomes; vigor and low confusion are key.
// - Raglin (2001): individual mood response to training is consistent
//   and can be used for monitoring overtraining.
//
// The card adds a lightweight pre-session check (3 taps: stress,
// motivation, soreness) and stores it on the TrainingSession model
// via UserDefaults (to avoid adding new SwiftData fields). After
// accumulating 5+ sessions with mood data, it shows correlations.

// MARK: - Mood Data Store

enum MoodDataStore {

    struct PreSessionMood: Codable {
        let sessionDate: Date
        let stress: Int       // 1=low, 2=moderate, 3=high
        let motivation: Int   // 1=low, 2=moderate, 3=high
        let soreness: Int     // 1=none, 2=some, 3=significant
    }

    private static let key = "paya_pre_session_moods"

    static func save(_ mood: PreSessionMood) {
        var moods = loadAll()
        moods.append(mood)
        // Keep last 90 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        moods = moods.filter { $0.sessionDate >= cutoff }
        if let data = try? JSONEncoder().encode(moods) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func loadAll() -> [PreSessionMood] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let moods = try? JSONDecoder().decode([PreSessionMood].self, from: data) else {
            return []
        }
        return moods
    }

    static func hasTodayEntry() -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return loadAll().contains { Calendar.current.isDate($0.sessionDate, inSameDayAs: today) }
    }
}

// MARK: - Pre-Session Mood Check

struct PreSessionMoodCheck: View {
    var onComplete: () -> Void

    @State private var stress = 2
    @State private var motivation = 2
    @State private var soreness = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile.fill")
                    .foregroundColor(Pulse.ai)
                Text("Quick check-in")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("3 taps")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Pulse.textTertiary)
            }

            moodRow(label: "Stress", value: $stress, options: [
                (1, "Low", "face.smiling"),
                (2, "Moderate", "face.dashed"),
                (3, "High", "exclamationmark.triangle"),
            ], color: Pulse.critical)

            moodRow(label: "Motivation", value: $motivation, options: [
                (1, "Low", "arrow.down"),
                (2, "Moderate", "arrow.right"),
                (3, "Fired up", "flame.fill"),
            ], color: Pulse.nutrition)

            moodRow(label: "Soreness", value: $soreness, options: [
                (1, "None", "checkmark.circle"),
                (2, "Some", "minus.circle"),
                (3, "Significant", "xmark.circle"),
            ], color: Pulse.hydration)

            Button {
                MoodDataStore.save(MoodDataStore.PreSessionMood(
                    sessionDate: Date(),
                    stress: stress,
                    motivation: motivation,
                    soreness: soreness
                ))
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onComplete()
            } label: {
                Text("Start session")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Pulse.ai)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .payaCard(padding: 14)
    }

    private func moodRow(label: String, value: Binding<Int>, options: [(Int, String, String)], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Pulse.textTertiary)
            HStack(spacing: 6) {
                ForEach(options, id: \.0) { option in
                    Button {
                        value.wrappedValue = option.0
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: option.2)
                                .font(.system(size: 10))
                            Text(option.1)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(value.wrappedValue == option.0 ? .white : color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(value.wrappedValue == option.0 ? color : color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(PulsePress())
                }
            }
        }
    }
}

// MARK: - Mood Performance Correlation Card

struct MoodPerformanceCard: View {

    @Environment(\.modelContext) private var modelContext

    @State private var correlations: [MoodCorrelation] = []
    @State private var bestState = ""
    @State private var worstState = ""
    @State private var hasEnoughData = false

    struct MoodCorrelation: Identifiable {
        let id = UUID()
        let dimension: String
        let icon: String
        let color: Color
        let lowLabel: String
        let highLabel: String
        let lowAvgVolume: Double
        let highAvgVolume: Double
        let percentDiff: Double
    }

    var body: some View {
        Group {
            if hasEnoughData {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "brain.head.profile.fill")
                            .foregroundColor(Pulse.ai)
                        Text("Mood → performance")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(MoodDataStore.loadAll().count) sessions")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Pulse.textTertiary)
                    }

                    ForEach(correlations) { corr in
                        correlationRow(corr)
                    }

                    // Insight
                    if !bestState.isEmpty {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Pulse.nutrition)
                                .padding(.top, 1)
                            Text(bestState)
                                .font(.system(size: 10))
                                .foregroundColor(Pulse.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Text("Hackford et al. (2019): pre-exercise mood explains 15-20% of performance variance. Correlations from your own data — not population averages.")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { analyze() }
    }

    private func correlationRow(_ corr: MoodCorrelation) -> some View {
        HStack(spacing: 8) {
            Image(systemName: corr.icon)
                .font(.system(size: 11))
                .foregroundColor(corr.color)
                .frame(width: 16)

            Text(corr.dimension)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 70, alignment: .leading)

            // Bar comparison
            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Text(corr.lowLabel)
                        .font(.system(size: 8))
                        .foregroundColor(Pulse.textTertiary)
                        .frame(width: 30, alignment: .trailing)
                    GeometryReader { geo in
                        let maxVol = max(corr.lowAvgVolume, corr.highAvgVolume)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(corr.color.opacity(0.3))
                            .frame(width: maxVol > 0 ? geo.size.width * (corr.lowAvgVolume / maxVol) : 0)
                    }
                    .frame(height: 8)
                }
                HStack(spacing: 4) {
                    Text(corr.highLabel)
                        .font(.system(size: 8))
                        .foregroundColor(Pulse.textTertiary)
                        .frame(width: 30, alignment: .trailing)
                    GeometryReader { geo in
                        let maxVol = max(corr.lowAvgVolume, corr.highAvgVolume)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(corr.color)
                            .frame(width: maxVol > 0 ? geo.size.width * (corr.highAvgVolume / maxVol) : 0)
                    }
                    .frame(height: 8)
                }
            }

            Spacer()

            Text(String(format: "%+.0f%%", corr.percentDiff))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(corr.percentDiff > 0 ? Pulse.positive : Pulse.critical)
        }
    }

    // MARK: - Analyze

    private func analyze() {
        let moods = MoodDataStore.loadAll()
        guard moods.count >= 5 else { return }

        let pid = ActiveProfile.id
        let calendar = Calendar.current

        // Fetch matching sessions
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: Date())!
        let sessionDesc = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> {
                $0.profileId == pid && $0.isCompleted && $0.date >= ninetyDaysAgo
            }
        )
        let sessions = (try? modelContext.fetch(sessionDesc)) ?? []

        // Pair moods with session volumes
        struct PairedData {
            let mood: MoodDataStore.PreSessionMood
            let volume: Double
        }

        var paired: [PairedData] = []
        for mood in moods {
            if let session = sessions.first(where: { calendar.isDate($0.date, inSameDayAs: mood.sessionDate) }) {
                let volume = session.exercises.reduce(0.0) { t, ex in
                    t + ex.sets.filter(\.isCompleted).reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
                }
                if volume > 0 {
                    paired.append(PairedData(mood: mood, volume: volume))
                }
            }
        }

        guard paired.count >= 5 else { return }
        hasEnoughData = true

        // Compute correlations for each dimension
        var results: [MoodCorrelation] = []

        // Stress: low (1) vs high (2-3)
        let lowStress = paired.filter { $0.mood.stress == 1 }
        let highStress = paired.filter { $0.mood.stress >= 2 }
        if !lowStress.isEmpty && !highStress.isEmpty {
            let lowAvg = lowStress.map(\.volume).reduce(0, +) / Double(lowStress.count)
            let highAvg = highStress.map(\.volume).reduce(0, +) / Double(highStress.count)
            let diff = lowAvg > 0 ? ((lowAvg - highAvg) / highAvg) * 100 : 0
            results.append(MoodCorrelation(
                dimension: "Stress",
                icon: "brain.fill",
                color: Pulse.critical,
                lowLabel: "Low",
                highLabel: "High",
                lowAvgVolume: lowAvg,
                highAvgVolume: highAvg,
                percentDiff: diff
            ))
        }

        // Motivation: low (1) vs high (3)
        let lowMotivation = paired.filter { $0.mood.motivation <= 1 }
        let highMotivation = paired.filter { $0.mood.motivation >= 3 }
        if !lowMotivation.isEmpty && !highMotivation.isEmpty {
            let lowAvg = lowMotivation.map(\.volume).reduce(0, +) / Double(lowMotivation.count)
            let highAvg = highMotivation.map(\.volume).reduce(0, +) / Double(highMotivation.count)
            let diff = lowAvg > 0 ? ((highAvg - lowAvg) / lowAvg) * 100 : 0
            results.append(MoodCorrelation(
                dimension: "Motivation",
                icon: "flame.fill",
                color: Pulse.nutrition,
                lowLabel: "Low",
                highLabel: "High",
                lowAvgVolume: lowAvg,
                highAvgVolume: highAvg,
                percentDiff: diff
            ))
        }

        // Soreness: none (1) vs significant (2-3)
        let noSoreness = paired.filter { $0.mood.soreness == 1 }
        let hasSoreness = paired.filter { $0.mood.soreness >= 2 }
        if !noSoreness.isEmpty && !hasSoreness.isEmpty {
            let freshAvg = noSoreness.map(\.volume).reduce(0, +) / Double(noSoreness.count)
            let soreAvg = hasSoreness.map(\.volume).reduce(0, +) / Double(hasSoreness.count)
            let diff = soreAvg > 0 ? ((freshAvg - soreAvg) / soreAvg) * 100 : 0
            results.append(MoodCorrelation(
                dimension: "Soreness",
                icon: "figure.walk",
                color: Pulse.hydration,
                lowLabel: "Fresh",
                highLabel: "Sore",
                lowAvgVolume: freshAvg,
                highAvgVolume: soreAvg,
                percentDiff: diff
            ))
        }

        correlations = results

        // Generate insight
        if let biggest = results.max(by: { abs($0.percentDiff) < abs($1.percentDiff) }) {
            if abs(biggest.percentDiff) > 5 {
                bestState = "\(biggest.dimension) has the biggest impact on your sessions (\(String(format: "%+.0f%%", biggest.percentDiff)) volume difference). Track this pattern to optimize your training days."
            }
        }
    }
}
