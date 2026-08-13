import SwiftUI
import SwiftData

// MARK: - Post-Workout Nutrition Window Card
// Surfaces on the Dashboard after a training session is completed,
// showing a countdown to the post-workout nutrition window and how much
// protein/calories the user has left for the day. Bridges training and
// nutrition — no other app shows this connection live.
//
// Grounded in: Schoenfeld & Aragon (2018) meta-analysis found that
// total daily protein intake matters more than timing, but consuming
// protein within ~2h post-training does slightly enhance muscle protein
// synthesis. The card emphasizes daily totals first, timing second.

struct PostWorkoutWindowCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var lastSessionEnd: Date?
    @State private var proteinRemaining: Double = 0
    @State private var caloriesRemaining: Double = 0
    @State private var proteinTarget: Double = 0
    @State private var calorieTarget: Double = 0
    @State private var proteinLogged: Double = 0
    @State private var caloriesLogged: Double = 0
    @State private var minutesSinceSession: Int = 0
    @State private var isVisible = false

    var body: some View {
        Group {
            if isVisible {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "fork.knife.circle.fill")
                            .foregroundColor(Color(hex: "059669"))
                        Text("Post-workout fuel")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if minutesSinceSession < 120 {
                            HStack(spacing: 3) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 9))
                                Text("\(120 - minutesSinceSession)min window left")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(minutesSinceSession < 60 ? Color(hex: "059669") : Color(hex: "F59E0B"))
                        } else {
                            Text("Window closed")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Remaining macros
                    HStack(spacing: 8) {
                        macroGauge(
                            label: "Protein left",
                            remaining: proteinRemaining,
                            target: proteinTarget,
                            unit: "g",
                            color: Color(hex: "2563EB")
                        )
                        macroGauge(
                            label: "Calories left",
                            remaining: caloriesRemaining,
                            target: calorieTarget,
                            unit: "cal",
                            color: Color(hex: "F59E0B")
                        )
                    }

                    // Suggestion
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "F59E0B"))
                            .padding(.top, 1)
                        Text(suggestion)
                            .font(.system(size: 10))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text("Schoenfeld & Aragon (2018): total daily protein > timing, but protein within 2h post-training slightly enhances MPS.")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func macroGauge(label: String, remaining: Double, target: Double, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", max(0, remaining)))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            let progress = target > 0 ? min(1, (target - remaining) / target) : 0
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)

            Text(String(format: "%.0f/%.0f %@", max(0, target - remaining), target, unit))
                .font(.system(size: 8))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(color.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var suggestion: String {
        if proteinRemaining > 40 {
            return "You still need \(Int(proteinRemaining))g protein today. A shake (40g whey) or chicken breast (35g) would cover most of it."
        } else if proteinRemaining > 20 {
            return "Only \(Int(proteinRemaining))g protein to go — a Greek yogurt (20g) or a protein bar would close the gap."
        } else if proteinRemaining > 0 {
            return "Almost there — just \(Int(proteinRemaining))g protein left. You're on track for a solid recovery day."
        } else {
            return "Protein target hit. Focus on whole foods for remaining calories and you're set for optimal recovery."
        }
    }

    private func compute() {
        let calendar = Calendar.current
        let pid = ActiveProfile.id
        let today = calendar.startOfDay(for: Date())

        // Find most recent completed session
        let sessionDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> {
                $0.profileId == pid && $0.isCompleted && $0.date >= today
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let todaySession = (try? modelContext.fetch(sessionDescriptor))?.first else {
            isVisible = false
            return
        }

        let minutesSince = Int(Date().timeIntervalSince(todaySession.date) / 60)
        guard minutesSince < 360 else { // Show for up to 6 hours
            isVisible = false
            return
        }
        minutesSinceSession = minutesSince
        lastSessionEnd = todaySession.date

        // Get today's nutrition
        let nutritionDescriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> {
                $0.profileId == pid && $0.date >= today
            }
        )
        let todayNutrition = (try? modelContext.fetch(nutritionDescriptor))?.first

        let profile = appState.profile
        proteinTarget = profile.proteinTargetG > 0 ? profile.proteinTargetG : 170
        calorieTarget = profile.trainingDayCalories > 0 ? profile.trainingDayCalories : 2200

        proteinLogged = todayNutrition?.totalProtein ?? 0
        caloriesLogged = todayNutrition?.totalCalories ?? 0
        proteinRemaining = max(0, proteinTarget - proteinLogged)
        caloriesRemaining = max(0, calorieTarget - caloriesLogged)

        isVisible = true
    }
}
