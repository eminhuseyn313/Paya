import SwiftUI

struct PostWorkoutNutritionCard: View {

    @Environment(AppState.self) private var appState
    var session: TrainingSession

    private var intensity: SessionIntensity {
        let vol = session.exercises.reduce(0.0) { t, ex in
            t + ex.sets.filter(\.isCompleted).reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
        }
        let duration = session.durationMinutes
        let trimp = session.sessionTrimpScore ?? 0

        if trimp > 150 || vol > 15000 || duration > 75 { return .high }
        if trimp > 80 || vol > 8000 || duration > 45 { return .moderate }
        return .light
    }

    private var bw: Double {
        appState.profile.currentWeightKg > 0 ? appState.profile.currentWeightKg : 75
    }

    private var proteinTarget: Int {
        switch intensity {
        case .high: return Int(bw * 0.5)
        case .moderate: return Int(bw * 0.4)
        case .light: return Int(bw * 0.3)
        }
    }

    private var carbTarget: Int {
        switch intensity {
        case .high: return Int(bw * 0.8)
        case .moderate: return Int(bw * 0.5)
        case .light: return Int(bw * 0.3)
        }
    }

    private var windowMinutes: Int {
        switch intensity {
        case .high: return 30
        case .moderate: return 60
        case .light: return 90
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: "059669").opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "059669"))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Post-Workout Nutrition")
                        .font(.subheadline.weight(.semibold))
                    Text("Eat within \(windowMinutes) min for optimal recovery")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(intensity.label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(intensity.color)
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                macroBlock(value: "\(proteinTarget)g", label: "Protein", color: Color(hex: "2563EB"), icon: "p.circle.fill")
                macroBlock(value: "\(carbTarget)g", label: "Carbs", color: Color(hex: "F59E0B"), icon: "c.circle.fill")
                macroBlock(value: "Low", label: "Fat", color: Color(hex: "DC2626"), icon: "f.circle.fill")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Suggested meals")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                ForEach(mealSuggestions, id: \.self) { meal in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: "059669"))
                            .frame(width: 4, height: 4)
                        Text(meal)
                            .font(.system(size: 11))
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.top, 2)

            Text("Prioritize fast-digesting protein + carbs. Delay fat to avoid slowing absorption.")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .payaCard(padding: 14)
    }

    private func macroBlock(value: String, label: String, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var mealSuggestions: [String] {
        switch intensity {
        case .high:
            return [
                "Whey shake + banana + honey",
                "Rice + chicken breast + fruit juice",
                "Greek yogurt + granola + berries"
            ]
        case .moderate:
            return [
                "Protein shake + rice cake",
                "Eggs + toast + fruit",
                "Cottage cheese + crackers"
            ]
        case .light:
            return [
                "Protein bar + apple",
                "Smoothie with protein powder",
                "Boiled eggs + fruit"
            ]
        }
    }
}

private enum SessionIntensity {
    case light, moderate, high

    var label: String {
        switch self {
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .high: return "Intense"
        }
    }

    var color: Color {
        switch self {
        case .light: return Color(hex: "059669")
        case .moderate: return Color(hex: "F59E0B")
        case .high: return Color(hex: "DC2626")
        }
    }
}
