import SwiftUI

struct StrengthStandardsCard: View {

    @Environment(AppState.self) private var appState
    let sessions: [TrainingSession]

    private var standards: [LiftStandard] {
        let bodyweight = appState.profile.currentWeightKg
        let sex = appState.profile.sexRaw
        guard bodyweight > 0 else { return [] }

        let lifts = keyLifts(from: sessions)
        guard !lifts.isEmpty else { return [] }

        return lifts.compactMap { name, bestE1RM in
            guard let thresholds = standardThresholds(for: name, bodyweight: bodyweight, sex: sex) else { return nil }
            let level = classifyLevel(e1rm: bestE1RM, thresholds: thresholds)
            let ratio = bestE1RM / bodyweight
            return LiftStandard(
                name: name,
                e1rm: bestE1RM,
                bwRatio: ratio,
                level: level,
                nextThreshold: nextTarget(e1rm: bestE1RM, thresholds: thresholds)
            )
        }
        .sorted { $0.level.order > $1.level.order }
    }

    private func keyLifts(from sessions: [TrainingSession]) -> [(String, Double)] {
        var best: [String: Double] = [:]
        let targetNames = Set([
            "Bench Press", "Flat Bench Press",
            "Squat", "Barbell Back Squat", "Back Squat",
            "Deadlift", "Conventional Deadlift", "Barbell Deadlift",
            "Overhead Press", "Barbell Overhead Press", "Standing Overhead Press",
            "Barbell Row", "Bent-Over Row", "Bent Over Barbell Row"
        ].map { $0.lowercased() })

        for session in sessions {
            for log in session.exercises {
                let normalized = log.exerciseName.lowercased()
                guard targetNames.contains(normalized) || isCompoundMatch(normalized) else { continue }
                for set in log.sets where set.isCompleted && set.weightKg > 0 {
                    let e1rm = set.weightKg * (1 + Double(set.reps) / 30.0)
                    let key = canonicalName(normalized)
                    if e1rm > (best[key] ?? 0) {
                        best[key] = e1rm
                    }
                }
            }
        }
        return best.map { ($0.key, $0.value) }
    }

    private func isCompoundMatch(_ name: String) -> Bool {
        name.contains("bench press") || name.contains("squat") ||
        name.contains("deadlift") || name.contains("overhead press") ||
        name.contains("barbell row")
    }

    private func canonicalName(_ name: String) -> String {
        if name.contains("bench") { return "Bench Press" }
        if name.contains("squat") { return "Squat" }
        if name.contains("deadlift") { return "Deadlift" }
        if name.contains("overhead") || name.contains("ohp") { return "OHP" }
        if name.contains("row") { return "Barbell Row" }
        return name.capitalized
    }

    private struct Thresholds {
        let beginner: Double
        let novice: Double
        let intermediate: Double
        let advanced: Double
        let elite: Double
    }

    private func standardThresholds(for lift: String, bodyweight: Double, sex: String) -> Thresholds? {
        let isMale = sex == "male"
        switch lift {
        case "Bench Press":
            return isMale
                ? Thresholds(beginner: 0.5, novice: 0.75, intermediate: 1.0, advanced: 1.5, elite: 2.0)
                : Thresholds(beginner: 0.25, novice: 0.5, intermediate: 0.75, advanced: 1.0, elite: 1.5)
        case "Squat":
            return isMale
                ? Thresholds(beginner: 0.75, novice: 1.0, intermediate: 1.5, advanced: 2.0, elite: 2.5)
                : Thresholds(beginner: 0.5, novice: 0.75, intermediate: 1.0, advanced: 1.5, elite: 2.0)
        case "Deadlift":
            return isMale
                ? Thresholds(beginner: 1.0, novice: 1.25, intermediate: 1.75, advanced: 2.5, elite: 3.0)
                : Thresholds(beginner: 0.5, novice: 1.0, intermediate: 1.25, advanced: 1.75, elite: 2.5)
        case "OHP":
            return isMale
                ? Thresholds(beginner: 0.35, novice: 0.55, intermediate: 0.75, advanced: 1.0, elite: 1.4)
                : Thresholds(beginner: 0.2, novice: 0.35, intermediate: 0.5, advanced: 0.75, elite: 1.0)
        case "Barbell Row":
            return isMale
                ? Thresholds(beginner: 0.5, novice: 0.75, intermediate: 1.0, advanced: 1.3, elite: 1.75)
                : Thresholds(beginner: 0.3, novice: 0.5, intermediate: 0.75, advanced: 1.0, elite: 1.3)
        default: return nil
        }
    }

    private func classifyLevel(e1rm: Double, thresholds: Thresholds) -> StrengthLevel {
        let bw = appState.profile.currentWeightKg
        let ratio = e1rm / bw
        if ratio >= thresholds.elite { return .elite }
        if ratio >= thresholds.advanced { return .advanced }
        if ratio >= thresholds.intermediate { return .intermediate }
        if ratio >= thresholds.novice { return .novice }
        return .beginner
    }

    private func nextTarget(e1rm: Double, thresholds: Thresholds) -> Double? {
        let bw = appState.profile.currentWeightKg
        let ratio = e1rm / bw
        let levels = [thresholds.beginner, thresholds.novice, thresholds.intermediate, thresholds.advanced, thresholds.elite]
        if let next = levels.first(where: { $0 > ratio }) {
            return next * bw
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.bar.xaxis.ascending")
                    .foregroundColor(Color(hex: "2563EB"))
                Text("Strength Standards")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            if standards.isEmpty {
                Text("Log compound lifts (bench, squat, deadlift, OHP, rows) to see your strength level")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ForEach(standards) { standard in
                    StandardRow(standard: standard, useLbs: appState.profile.prefersLbs)
                }

                HStack(spacing: 4) {
                    Text("Based on bodyweight ratios")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Spacer()
                    ForEach(StrengthLevel.allCases, id: \.self) { level in
                        HStack(spacing: 2) {
                            Circle().fill(level.color).frame(width: 4, height: 4)
                            Text(level.short)
                                .font(.system(size: 7, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .payaCard(padding: 14)
    }
}

private struct StandardRow: View {
    let standard: LiftStandard
    let useLbs: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(standard.name)
                    .font(.system(size: 13, weight: .semibold))
                HStack(spacing: 4) {
                    Text(standard.level.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(standard.level.color)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f× BW", standard.bwRatio))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                let display = useLbs ? standard.e1rm * 2.20462 : standard.e1rm
                Text(String(format: "%.0f %@", display, useLbs ? "lbs" : "kg"))
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                if let next = standard.nextThreshold {
                    let nextDisplay = useLbs ? next * 2.20462 : next
                    let gap = nextDisplay - display
                    Text(String(format: "+%.0f to next", gap))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color(hex: "F59E0B"))
                }
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(standard.level.color)
                .frame(width: 4, height: 28)
        }
        .padding(.vertical, 2)
    }
}

private enum StrengthLevel: String, CaseIterable {
    case beginner = "Beginner"
    case novice = "Novice"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case elite = "Elite"

    var color: Color {
        switch self {
        case .beginner: return Color(hex: "94A3B8")
        case .novice: return Color(hex: "059669")
        case .intermediate: return Color(hex: "2563EB")
        case .advanced: return Color(hex: "8B5CF6")
        case .elite: return Color(hex: "F59E0B")
        }
    }

    var short: String {
        switch self {
        case .beginner: return "B"
        case .novice: return "N"
        case .intermediate: return "I"
        case .advanced: return "A"
        case .elite: return "E"
        }
    }

    var order: Int {
        switch self {
        case .beginner: return 0
        case .novice: return 1
        case .intermediate: return 2
        case .advanced: return 3
        case .elite: return 4
        }
    }
}

private struct LiftStandard: Identifiable {
    let name: String
    let e1rm: Double
    let bwRatio: Double
    let level: StrengthLevel
    let nextThreshold: Double?
    var id: String { name }
}
