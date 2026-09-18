import SwiftUI
import SwiftData

// MARK: - Lifestyle Plan
//
// Redesigned: deterministic, structured lifestyle/nutrition/supplement
// guidance that works without any API key. Shows real protein sources
// for the user's diet, evidence-based supplements for their goal, and
// actionable recovery guidance based on their sleep/stress profile.
//
// The AI-generated plan is shown as optional "Coach Notes" on top.
//
// Design benchmark: Cal AI / Whoop recovery — structured sections with
// actionable items, not text dumps.

struct LifestylePlanCard: View {
    var profile: PersonProfile
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Pulse.ai.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkles")
                        .foregroundColor(Pulse.ai)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lifestyle Plan")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Pulse.textPrimary)
                    Text("Nutrition strategy, supplements & recovery for your goals")
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
            }
            .payaCard(padding: 14)
        }
        .buttonStyle(PulsePress())
    }
}

struct LifestylePlanView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var profile: PersonProfile

    @State private var showCoachNotes = false
    @State private var isGenerating = false
    @State private var errorText: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Profile summary hero
                    profileHero

                    // Nutrition strategy
                    nutritionSection

                    // Top protein sources for their diet
                    proteinSourcesSection

                    // Supplements
                    supplementsSection

                    // Recovery & lifestyle
                    recoverySection

                    // AI Coach Notes
                    coachNotesSection

                    // Disclaimer
                    Text("Based on ACSM/NSCA position stands & ISSN nutrition guidance. Not medical advice.")
                        .font(.system(size: 10))
                        .foregroundColor(Pulse.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    Spacer().frame(height: 30)
                }
                .padding(.top, 8)
            }
            .background(Pulse.canvasFallback.ignoresSafeArea())
            .navigationTitle("Lifestyle Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Profile Hero

    private var profileHero: some View {
        VStack(spacing: 12) {
            // Goal badge
            HStack(spacing: 6) {
                Image(systemName: profile.goal.icon)
                    .font(.system(size: 12))
                Text(profile.goal.displayName)
                    .font(.system(size: 12, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.8)
            }
            .foregroundColor(profile.goal.color)

            // Key stats row
            HStack(spacing: 20) {
                statPill(value: "\(Int(profile.currentWeightKg))", unit: "kg", label: "Weight")
                statPill(value: "\(profile.preferredTrainingDaysPerWeek)", unit: "x/wk", label: "Training")
                statPill(value: profile.dietPreference.displayName, unit: "", label: "Diet")
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: PayaRadius.card)
                .fill(Pulse.surfaceFallback)
                .overlay(
                    RoundedRectangle(cornerRadius: PayaRadius.card)
                        .stroke(profile.goal.color.opacity(0.12), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 20)
    }

    private func statPill(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Pulse.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Pulse.textTertiary)
                }
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
        }
    }

    // MARK: - Nutrition Strategy

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(icon: "fork.knife", title: "Nutrition Strategy", color: Pulse.nutrition)

            // Calorie targets
            HStack(spacing: 12) {
                calorieCard(
                    label: "Training Day",
                    calories: Int(profile.trainingDayCalories),
                    icon: "dumbbell.fill",
                    color: Pulse.energy
                )
                calorieCard(
                    label: "Rest Day",
                    calories: Int(profile.restDayCalories),
                    icon: "bed.double.fill",
                    color: Pulse.recovery
                )
            }

            // Protein target
            HStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Pulse.energy)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Protein: \(Int(profile.proteinTargetG))g/day")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Pulse.textPrimary)
                    Text("\(String(format: "%.1f", profile.proteinTargetG / max(1, profile.currentWeightKg)))g per kg body weight — Morton et al. 2018")
                        .font(.system(size: 10))
                        .foregroundColor(Pulse.textTertiary)
                }
                Spacer()
            }

            // Timing advice
            timingAdvice
        }
        .payaCard(padding: 14)
        .padding(.horizontal, 20)
    }

    private func calorieCard(label: String, calories: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text("\(calories)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Pulse.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.06))
        )
    }

    @ViewBuilder
    private var timingAdvice: some View {
        let tips: [(icon: String, text: String)] = {
            switch profile.goal {
            case .fatLoss:
                return [
                    ("clock.fill", "Front-load protein at breakfast to reduce hunger"),
                    ("figure.walk", "Target 10,000 steps/day for NEAT-driven deficit")
                ]
            case .hypertrophy:
                return [
                    ("clock.fill", "Eat within 2h pre/post-training for MPS window"),
                    ("moon.fill", "Casein-rich food before bed for overnight synthesis")
                ]
            case .strength:
                return [
                    ("bolt.fill", "Carbs 60-90 min pre-training for glycogen stores"),
                    ("clock.fill", "30-40g protein post-training within 60 min")
                ]
            case .endurance:
                return [
                    ("bolt.fill", "Carb-load (7-10g/kg) before long sessions"),
                    ("drop.fill", "Electrolytes during sessions > 60 min")
                ]
            case .stayFit:
                return [
                    ("clock.fill", "Consistent meal timing supports circadian rhythm"),
                    ("leaf.fill", "Emphasize whole foods over supplements")
                ]
            }
        }()

        VStack(spacing: 6) {
            ForEach(tips, id: \.text) { tip in
                HStack(spacing: 8) {
                    Image(systemName: tip.icon)
                        .font(.system(size: 10))
                        .foregroundColor(Pulse.nutrition.opacity(0.6))
                        .frame(width: 16)
                    Text(tip.text)
                        .font(.system(size: 11))
                        .foregroundColor(Pulse.textSecondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Protein Sources

    private var proteinSourcesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "flame.fill", title: "Your Protein Sources", color: Pulse.energy)

            Text("Best options for \(profile.dietPreference.displayName.lowercased()) diet")
                .font(.system(size: 11))
                .foregroundColor(Pulse.textTertiary)

            let proteins = FoodDatabase.highProteinFoods(for: profile.dietPreference)
            ForEach(proteins.prefix(5)) { food in
                HStack(spacing: 10) {
                    Text(food.emoji)
                        .font(.system(size: 18))
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(food.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Pulse.textPrimary)
                        Text(food.servingSize)
                            .font(.system(size: 10))
                            .foregroundColor(Pulse.textTertiary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(Int(food.proteinG))g")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Pulse.energy)
                        Text("\(food.calories) kcal")
                            .font(.system(size: 10))
                            .foregroundColor(Pulse.textTertiary)
                    }
                }
                .padding(.vertical, 3)
                if food.id != proteins.prefix(5).last?.id {
                    Divider().background(Color.white.opacity(0.04))
                }
            }
        }
        .payaCard(padding: 14)
        .padding(.horizontal, 20)
    }

    // MARK: - Supplements

    private var supplementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "pills.fill", title: "Evidence-Based Supplements", color: Pulse.warning)

            ForEach(recommendedSupplements, id: \.name) { supp in
                HStack(spacing: 10) {
                    Text(supp.emoji)
                        .font(.system(size: 18))
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(supp.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Pulse.textPrimary)
                        Text(supp.dosage)
                            .font(.system(size: 11))
                            .foregroundColor(Pulse.textSecondary)
                        Text(supp.evidence)
                            .font(.system(size: 9))
                            .foregroundColor(Pulse.textTertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, 3)
            }
        }
        .payaCard(padding: 14)
        .padding(.horizontal, 20)
    }

    private struct SupplementRec: Hashable {
        let name: String
        let emoji: String
        let dosage: String
        let evidence: String
    }

    private var recommendedSupplements: [SupplementRec] {
        var supps: [SupplementRec] = []

        // Creatine — universal recommendation (ISSN position stand, Kreider et al. 2017)
        supps.append(SupplementRec(
            name: "Creatine Monohydrate",
            emoji: "💊",
            dosage: "3–5g daily, any time",
            evidence: "ISSN: strongest evidence for strength & lean mass (Kreider 2017)"
        ))

        // Vitamin D — near-universal deficiency
        supps.append(SupplementRec(
            name: "Vitamin D3",
            emoji: "☀️",
            dosage: "1000–2000 IU daily",
            evidence: "Widespread deficiency; supports immune & bone health (Holick 2007)"
        ))

        // Goal-specific
        switch profile.goal {
        case .fatLoss:
            supps.append(SupplementRec(
                name: "Caffeine",
                emoji: "☕",
                dosage: "3–6 mg/kg pre-training",
                evidence: "Improves performance & fat oxidation (ISSN position stand)"
            ))
        case .hypertrophy, .strength:
            supps.append(SupplementRec(
                name: "Whey Protein",
                emoji: "🥤",
                dosage: "20–40g post-training",
                evidence: "Convenient way to hit protein target (Morton 2018)"
            ))
        case .endurance:
            supps.append(SupplementRec(
                name: "Electrolyte Mix",
                emoji: "💧",
                dosage: "During sessions > 60 min",
                evidence: "Maintains performance in prolonged exercise (ACSM)"
            ))
        case .stayFit:
            break
        }

        // Omega-3 for inflammatory conditions
        if profile.hasInflammatoryCondition {
            supps.append(SupplementRec(
                name: "Omega-3 (EPA/DHA)",
                emoji: "🐟",
                dosage: "2–3g EPA+DHA daily",
                evidence: "Anti-inflammatory, joint health (Calder 2017)"
            ))
        }

        // Vegan-specific
        if profile.dietPreference == .vegan {
            supps.append(SupplementRec(
                name: "Vitamin B12",
                emoji: "🔴",
                dosage: "250–500 mcg daily",
                evidence: "Essential — not available in plant foods (ISSN)"
            ))
        }

        return supps
    }

    // MARK: - Recovery

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "moon.stars.fill", title: "Recovery & Lifestyle", color: Pulse.recovery)

            // Sleep
            recoveryRow(
                emoji: "😴",
                title: "Sleep Target: \(String(format: "%.0f", profile.sleepTargetHours))h/night",
                detail: sleepAdvice
            )

            Divider().background(Color.white.opacity(0.04))

            // Stress
            recoveryRow(
                emoji: "🧘",
                title: "Stress Level: \(profile.stressLevel)/5",
                detail: stressAdvice
            )

            Divider().background(Color.white.opacity(0.04))

            // Training frequency
            recoveryRow(
                emoji: "📅",
                title: "\(profile.preferredTrainingDaysPerWeek) training days/week",
                detail: recoveryFrequencyAdvice
            )
        }
        .payaCard(padding: 14)
        .padding(.horizontal, 20)
    }

    private func recoveryRow(emoji: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji)
                .font(.system(size: 18))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Pulse.textPrimary)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(Pulse.textSecondary)
            }
            Spacer()
        }
    }

    private var sleepAdvice: String {
        if profile.sleepTargetHours < 7 {
            return "Below the 7–9h recommendation (Walker 2017). Prioritize extending sleep — it directly impacts recovery and muscle protein synthesis."
        } else if profile.sleepTargetHours >= 9 {
            return "Excellent target. Consistent timing matters more than duration — keep wake time within ±30 min daily."
        } else {
            return "Solid target. Cool room (65–68°F), no screens 30 min before bed, consistent schedule."
        }
    }

    private var stressAdvice: String {
        switch profile.stressLevel {
        case 1...2:
            return "Low stress — great for recovery. Maintain with regular movement breaks and social connection."
        case 3:
            return "Moderate stress. Consider 10 min daily meditation or breathing exercises — research shows HRV improvement within 2 weeks."
        case 4...5:
            return "High stress impacts cortisol and recovery. Reduce training volume on high-stress weeks. Walking and breathing exercises are your best tools."
        default:
            return "Monitor how you feel — adjust training intensity based on daily energy and soreness."
        }
    }

    private var recoveryFrequencyAdvice: String {
        switch profile.preferredTrainingDaysPerWeek {
        case 1...2:
            return "Focus on full-body sessions to maximize stimulus per workout. Active recovery on off days — walking, mobility work."
        case 3...4:
            return "Good balance of stimulus and recovery. Ensure at least 48h between training the same muscle group."
        case 5...6:
            return "High frequency — sleep and nutrition become critical. Deload every 4–6 weeks to prevent overreaching (Halson 2014)."
        default:
            return "Adjust training to match your recovery capacity — quality over quantity."
        }
    }

    // MARK: - Coach Notes

    private var coachNotesSection: some View {
        VStack(spacing: 10) {
            if let plan = profile.cachedLifestylePlan, !plan.isEmpty {
                DisclosureGroup(isExpanded: $showCoachNotes) {
                    Text(plan)
                        .font(.system(size: 12))
                        .foregroundColor(Pulse.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(Pulse.ai)
                        Text("AI Coach Notes")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Pulse.textPrimary)
                        if let date = profile.lifestylePlanGeneratedAt {
                            Spacer()
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 10))
                                .foregroundColor(Pulse.textTertiary)
                        }
                    }
                }
                .tint(Pulse.textTertiary)
                .payaCard(padding: 14)
                .padding(.horizontal, 20)
            }

            Button {
                Task { await generate() }
            } label: {
                HStack(spacing: 8) {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(profile.cachedLifestylePlan == nil
                         ? "Get personalized AI coaching"
                         : "Refresh AI coaching")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Pulse.ai)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Pulse.ai.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Pulse.ai.opacity(0.2), lineWidth: 0.5)
                        )
                )
            }
            .disabled(isGenerating)
            .padding(.horizontal, 20)

            if let errorText {
                Text(errorText)
                    .font(.caption2)
                    .foregroundColor(Pulse.critical)
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundColor(Pulse.textPrimary)
        }
    }

    private func generate() async {
        isGenerating = true
        errorText = nil
        let result = await LifestylePlanEngine.generate(profile: profile, context: modelContext, apiKey: appState.anthropicAPIKey)
        if result != nil {
            try? modelContext.save()
            showCoachNotes = true
        } else {
            errorText = AIService.shared.lastError ?? "Couldn't generate coaching — check connection."
        }
        isGenerating = false
    }
}
