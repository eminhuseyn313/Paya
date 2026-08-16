import SwiftUI

// MARK: - Session Score Card
// Like Whoop's Strain Score — a single 0-100 composite score for each
// session. Combines: volume load, exercise count, duration, RPE, and HR
// data into one glanceable quality metric. Shown on the Dashboard under
// the last session card.

struct SessionScoreCard: View {

    @Environment(AppState.self) private var appState
    var session: TrainingSession

    private var score: SessionScore { SessionScoreEngine.compute(session: session) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .stroke(Pulse.surfaceElevatedFallback, lineWidth: 5)
                        .frame(width: 48, height: 48)
                    Circle()
                        .trim(from: 0, to: CGFloat(score.total) / 100)
                        .stroke(score.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(-90))
                    Text("\(score.total)")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(score.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Session Score")
                        .font(.subheadline.weight(.semibold))
                    Text(score.grade)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(score.color)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(session.sessionType)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(score.color)
                        .clipShape(Capsule())
                    Text(dateLabel)
                        .font(.system(size: 9))
                        .foregroundColor(Pulse.textTertiary)
                }
            }

            HStack(spacing: 6) {
                scorePill(label: "Volume", value: score.volumeScore, max: 30)
                scorePill(label: "Intensity", value: score.intensityScore, max: 25)
                scorePill(label: "Duration", value: score.durationScore, max: 20)
                scorePill(label: "Effort", value: score.effortScore, max: 15)
                scorePill(label: "Cardio", value: score.cardioScore, max: 10)
            }

            Text("Composite score from volume (30%), intensity (25%), duration (20%), effort (15%), and cardio (10%). Higher = harder session.")
                .font(.system(size: 9))
                .foregroundColor(Pulse.textTertiary)
        }
        .payaCard(padding: 14)
    }

    private var dateLabel: String {
        let days = Calendar.current.dateComponents([.day], from: session.date, to: Date()).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        default: return "\(days)d ago"
        }
    }

    private func scorePill(label: String, value: Int, max: Int) -> some View {
        VStack(spacing: 3) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Pulse.surfaceElevatedFallback)
                    .frame(width: 16, height: 28)
                RoundedRectangle(cornerRadius: 2)
                    .fill(score.color.opacity(0.7))
                    .frame(width: 16, height: 28 * CGFloat(value) / CGFloat(max))
            }
            Text("\(value)")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundColor(score.color)
            Text(label)
                .font(.system(size: 6, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Score Engine

enum SessionScoreEngine {

    static func compute(session: TrainingSession) -> SessionScore {

        let completedSets = session.exercises.flatMap(\.sets).filter(\.isCompleted)
        guard !completedSets.isEmpty else {
            return SessionScore(total: 0, volumeScore: 0, intensityScore: 0, durationScore: 0, effortScore: 0, cardioScore: 0)
        }

        // Volume component (0-30): total tonnage
        let totalVolume = completedSets.reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
        let volumeScore = min(30, Int(totalVolume / 500))

        // Intensity component (0-25): average weight relative to effort
        let maxWeight = completedSets.map(\.weightKg).max() ?? 0
        let avgWeight = completedSets.map(\.weightKg).reduce(0, +) / Double(completedSets.count)
        let exerciseCount = session.exercises.filter { $0.sets.contains(where: \.isCompleted) }.count
        let intensityRaw = (avgWeight / max(1, maxWeight)) * Double(exerciseCount)
        let intensityScore = min(25, Int(intensityRaw * 4))

        // Duration component (0-20): session length
        let durationScore = min(20, session.durationMinutes / 4)

        // Effort component (0-15): subjective RPE
        let effortScore: Int
        if let rpe = session.subjectiveRPE {
            effortScore = min(15, Int(Double(rpe) * 1.5))
        } else {
            let setRPEs = completedSets.filter { $0.rpe > 0 }.map(\.rpe)
            if !setRPEs.isEmpty {
                let avgRPE = Double(setRPEs.reduce(0, +)) / Double(setRPEs.count)
                effortScore = min(15, Int(avgRPE * 1.5))
            } else {
                effortScore = 8  // neutral default
            }
        }

        // Cardio component (0-10): HR data
        let cardioScore: Int
        if let trimp = session.sessionTrimpScore, trimp > 0 {
            cardioScore = min(10, Int(trimp / 15))
        } else if let avgHR = session.sessionAvgHR, avgHR > 0 {
            cardioScore = min(10, max(0, (avgHR - 80) / 10))
        } else {
            cardioScore = 3  // small base
        }

        let total = volumeScore + intensityScore + durationScore + effortScore + cardioScore

        return SessionScore(
            total: total,
            volumeScore: volumeScore,
            intensityScore: intensityScore,
            durationScore: durationScore,
            effortScore: effortScore,
            cardioScore: cardioScore
        )
    }
}

struct SessionScore {
    let total: Int
    let volumeScore: Int
    let intensityScore: Int
    let durationScore: Int
    let effortScore: Int
    let cardioScore: Int

    var grade: String {
        switch total {
        case 80...: return "Elite Session"
        case 60..<80: return "Strong Session"
        case 40..<60: return "Solid Session"
        case 20..<40: return "Light Session"
        default: return "Recovery Session"
        }
    }

    var color: Color {
        switch total {
        case 80...: return Pulse.ai
        case 60..<80: return Pulse.hydration
        case 40..<60: return Pulse.positive
        case 20..<40: return Pulse.nutrition
        default: return .secondary
        }
    }
}
