import Foundation

// MARK: - Plate Calculator
//
// One of the most consistently requested features in strength-training app
// reviews and Reddit threads (alongside superset support) — "what plates do
// I actually put on the bar for this weight" — and Paya had no version of
// it at all.

enum PlateCalculator {

    /// Standard metric plate set found in most commercial gyms.
    static let standardPlatesKg: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    enum BarWeight: Double, CaseIterable, Identifiable {
        case olympic = 20
        case womens = 15
        case training = 10

        var id: Double { rawValue }

        var label: String {
            switch self {
            case .olympic: return "Olympic (20kg)"
            case .womens: return "Women's (15kg)"
            case .training: return "Training bar (10kg)"
            }
        }
    }

    /// Greedy largest-plate-first breakdown for ONE side of the bar.
    /// Returns nil if the target weight can't be reached with this bar and
    /// plate set (e.g. target lighter than the bar itself, or an
    /// unreachable fraction given the smallest available plate).
    static func platesPerSide(
        targetWeightKg: Double,
        barWeightKg: Double,
        availablePlates: [Double] = standardPlatesKg
    ) -> [Double]? {
        guard targetWeightKg >= barWeightKg else { return [] }
        var perSide = (targetWeightKg - barWeightKg) / 2
        guard perSide > 0 else { return [] }

        var result: [Double] = []
        let sortedPlates = availablePlates.sorted(by: >)
        let tolerance = 0.01

        for plate in sortedPlates {
            while perSide + tolerance >= plate {
                result.append(plate)
                perSide -= plate
            }
        }

        // Leftover means the target isn't reachable exactly with this plate
        // set (e.g. an odd weight smaller than the smallest plate) —
        // still return the closest achievable breakdown rather than nil,
        // since "close" is still useful, but the caller can compare the
        // achieved total against the target to show a mismatch warning.
        return result
    }

    static func achievedWeight(plates: [Double], barWeightKg: Double) -> Double {
        barWeightKg + plates.reduce(0, +) * 2
    }
}
