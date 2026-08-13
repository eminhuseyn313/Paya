import SwiftUI

struct ExerciseAlternativesCard: View {

    var sessions: [TrainingSession]

    @State private var suggestions: [AlternativeSuggestion] = []
    @State private var expanded = false

    var body: some View {
        Group {
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "arrow.triangle.swap")
                            .foregroundColor(Color(hex: "0891B2"))
                        Text("Exercise Alternatives")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(suggestions.count) suggestions")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }

                    Text("Exercises where you've plateaued — try swapping to break through.")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    let visible = expanded ? suggestions : Array(suggestions.prefix(3))
                    ForEach(visible) { suggestion in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "F59E0B").opacity(0.12))
                                        .frame(width: 26, height: 26)
                                    Image(systemName: "minus")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color(hex: "F59E0B"))
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(suggestion.exerciseName)
                                        .font(.system(size: 12, weight: .semibold))
                                        .lineLimit(1)
                                    Text("Plateaued for \(suggestion.plateauSessions) sessions")
                                        .font(.system(size: 9))
                                        .foregroundColor(Color(hex: "F59E0B"))
                                }

                                Spacer()
                            }

                            HStack(spacing: 6) {
                                Image(systemName: "arrow.right.arrow.left")
                                    .font(.system(size: 8))
                                    .foregroundColor(Color(hex: "0891B2"))
                                Text("Try: ")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text(suggestion.alternatives.joined(separator: " · "))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color(hex: "0891B2"))
                                    .lineLimit(1)
                            }
                            .padding(.leading, 34)
                        }
                        .padding(.vertical, 4)
                    }

                    if suggestions.count > 3 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                        } label: {
                            Text(expanded ? "Show less" : "Show all \(suggestions.count)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: "0891B2"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func compute() {
        let completed = sessions.filter(\.isCompleted).sorted { $0.date < $1.date }
        var exerciseHistory: [String: [(weight: Double, muscle: String, date: Date)]] = [:]

        for session in completed {
            for log in session.exercises {
                let maxWeight = log.sets.filter(\.isCompleted).map(\.weightKg).max() ?? 0
                guard maxWeight > 0 else { continue }
                exerciseHistory[log.exerciseName, default: []].append((maxWeight, log.muscleGroup, session.date))
            }
        }

        suggestions = exerciseHistory.compactMap { name, history in
            guard history.count >= 4 else { return nil }
            let recent = Array(history.suffix(4))
            let weights = recent.map(\.weight)
            let maxW = weights.max() ?? 0
            let minW = weights.min() ?? 0

            let isPlateaued = maxW > 0 && ((maxW - minW) / maxW) < 0.03

            guard isPlateaued else { return nil }

            let muscle = recent.last?.muscle ?? ""
            let alts = alternativesFor(exercise: name, muscle: muscle)
            guard !alts.isEmpty else { return nil }

            return AlternativeSuggestion(
                exerciseName: name,
                muscleGroup: muscle,
                plateauSessions: recent.count,
                alternatives: alts
            )
        }
        .sorted { $0.plateauSessions > $1.plateauSessions }
    }

    private func alternativesFor(exercise: String, muscle: String) -> [String] {
        let name = exercise.lowercased()

        if name.contains("bench press") && name.contains("flat") {
            return ["Incline DB Press", "Floor Press", "Paused Bench"]
        }
        if name.contains("bench press") || name.contains("bench") {
            return ["DB Bench Press", "Cable Fly", "Push-Up Variations"]
        }
        if name.contains("squat") && !name.contains("bulgarian") {
            return ["Front Squat", "Pause Squat", "Leg Press"]
        }
        if name.contains("deadlift") && name.contains("romanian") {
            return ["Stiff-Leg Deadlift", "Good Morning", "Hip Thrust"]
        }
        if name.contains("deadlift") {
            return ["Deficit Deadlift", "Pause Deadlift", "Trap Bar Deadlift"]
        }
        if name.contains("overhead press") || name.contains("ohp") || name.contains("military") {
            return ["DB Shoulder Press", "Push Press", "Arnold Press"]
        }
        if name.contains("row") && name.contains("barbell") {
            return ["Pendlay Row", "Seal Row", "Cable Row"]
        }
        if name.contains("row") {
            return ["DB Row", "Chest-Supported Row", "T-Bar Row"]
        }
        if name.contains("lat pulldown") || name.contains("pull-down") {
            return ["Pull-Up", "Neutral Grip Pulldown", "Straight Arm Pulldown"]
        }
        if name.contains("pull-up") || name.contains("pullup") || name.contains("chin") {
            return ["Lat Pulldown", "Neutral Grip Pull-Up", "Band-Assisted Pull-Up"]
        }
        if name.contains("curl") && name.contains("barbell") {
            return ["EZ Bar Curl", "DB Hammer Curl", "Incline DB Curl"]
        }
        if name.contains("curl") {
            return ["Hammer Curl", "Preacher Curl", "Cable Curl"]
        }
        if name.contains("tricep") || name.contains("extension") || name.contains("pushdown") {
            return ["Overhead Extension", "Dips", "Close-Grip Bench"]
        }
        if name.contains("lateral raise") || name.contains("side raise") {
            return ["Cable Lateral Raise", "Leaning Lateral Raise", "Machine Lateral"]
        }
        if name.contains("leg press") {
            return ["Hack Squat", "Bulgarian Split Squat", "Goblet Squat"]
        }
        if name.contains("leg curl") || name.contains("hamstring") {
            return ["Nordic Curl", "Romanian Deadlift", "Sliding Leg Curl"]
        }
        if name.contains("leg extension") {
            return ["Sissy Squat", "Front Foot Elevated Split Squat", "Wall Sit"]
        }
        if name.contains("hip thrust") {
            return ["Glute Bridge", "Romanian Deadlift", "Cable Pull-Through"]
        }
        if name.contains("calf") {
            return ["Seated Calf Raise", "Single-Leg Calf Raise", "Donkey Calf Raise"]
        }

        let m = muscle.lowercased()
        if m.contains("chest") { return ["DB Fly", "Cable Crossover", "Dips"] }
        if m.contains("back") { return ["Face Pull", "DB Row", "Inverted Row"] }
        if m.contains("shoulder") { return ["Face Pull", "Upright Row", "Rear Delt Fly"] }
        if m.contains("quad") { return ["Step-Up", "Wall Sit", "Lunges"] }
        if m.contains("glute") { return ["Hip Thrust", "Cable Kickback", "Frog Pump"] }
        if m.contains("ham") { return ["Romanian Deadlift", "Glute Ham Raise", "Nordic Curl"] }
        if m.contains("bicep") { return ["Hammer Curl", "Concentration Curl", "Cable Curl"] }
        if m.contains("tricep") { return ["Diamond Push-Up", "Dips", "Overhead Extension"] }

        return []
    }
}

private struct AlternativeSuggestion: Identifiable {
    let exerciseName: String
    let muscleGroup: String
    let plateauSessions: Int
    let alternatives: [String]
    var id: String { exerciseName }
}
