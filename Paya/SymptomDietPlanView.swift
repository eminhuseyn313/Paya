import SwiftUI
import SwiftData

// MARK: - Symptom Diet Plan
//
// Redesigned from AI-text-dump to a structured, visually rich diet plan
// that works DETERMINISTICALLY without any API key. Uses real food items
// with USDA macro data, structured meal plans, and anti-inflammatory
// food recommendations based on the user's profile.
//
// The AI-generated plan becomes an optional enhancement layer shown as
// "Coach Notes" — the core experience is always functional.
//
// Design benchmark: Cal AI's meal plan cards — structured food items
// with emoji, macros per item, expandable meals, daily totals.

struct SymptomDietCard: View {
    var profile: PersonProfile
    var onOpen: () -> Void

    private var hasSymptomData: Bool {
        profile.hasInflammatoryCondition || profile.cachedSymptomDietPlan != nil
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Pulse.recovery.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "leaf.fill")
                        .foregroundColor(Pulse.recovery)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Diet Plan")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Pulse.textPrimary)
                    Text("Meals, macros & anti-inflammatory foods for your goals")
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

// MARK: - Full View

struct SymptomDietPlanView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var profile: PersonProfile

    @State private var selectedDayType: DailyMealPlan.DayType = .training
    @State private var expandedMealID: UUID? = nil
    @State private var showCoachNotes = false
    @State private var isGenerating = false
    @State private var errorText: String? = nil

    private var trainingPlan: DailyMealPlan {
        MealPlanGenerator.trainingDayPlan(profile: profile)
    }
    private var restPlan: DailyMealPlan {
        MealPlanGenerator.restDayPlan(profile: profile)
    }
    private var activePlan: DailyMealPlan {
        selectedDayType == .training ? trainingPlan : restPlan
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Hero — daily macro targets
                    macroHeroCard

                    // Day type toggle
                    dayTypeToggle

                    // Meal cards
                    ForEach(activePlan.meals) { meal in
                        mealCard(meal)
                    }

                    // Anti-inflammatory foods
                    if profile.hasInflammatoryCondition {
                        antiInflammatorySection
                    }

                    // Foods to limit
                    foodsToLimitSection

                    // AI Coach Notes (optional enhancement)
                    coachNotesSection

                    // Disclaimer
                    Text("Nutrition guidance based on USDA data & Mediterranean diet research (Sköldstam 2003, Petersson 2018). Not medical advice.")
                        .font(.system(size: 10))
                        .foregroundColor(Pulse.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    Spacer().frame(height: 30)
                }
                .padding(.top, 8)
            }
            .background(Pulse.canvasFallback.ignoresSafeArea())
            .navigationTitle("Diet Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Macro Hero

    private var macroHeroCard: some View {
        VStack(spacing: 14) {
            // Diet badge
            HStack(spacing: 6) {
                Text(profile.dietPreference.displayName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Pulse.recovery)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Text("·")
                    .foregroundColor(Pulse.textTertiary)

                Text(profile.goal.displayName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: profile.goal.colorHex))
                    .textCase(.uppercase)
                    .tracking(0.8)
            }

            // Big calorie number
            VStack(spacing: 2) {
                Text("\(Int(selectedDayType == .training ? profile.trainingDayCalories : profile.restDayCalories))")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundColor(Pulse.textPrimary)
                Text("kcal target")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Pulse.textTertiary)
            }

            // Macro rings
            HStack(spacing: 24) {
                macroRing(
                    label: "Protein",
                    grams: Int(profile.proteinTargetG),
                    color: Pulse.energy,
                    icon: "flame.fill"
                )
                macroRing(
                    label: "Carbs",
                    grams: estimatedCarbs,
                    color: Pulse.hydration,
                    icon: "bolt.fill"
                )
                macroRing(
                    label: "Fat",
                    grams: estimatedFat,
                    color: Pulse.nutrition,
                    icon: "drop.fill"
                )
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: PayaRadius.card)
                .fill(Pulse.surfaceFallback)
                .overlay(
                    RoundedRectangle(cornerRadius: PayaRadius.card)
                        .stroke(Pulse.recovery.opacity(0.12), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 20)
    }

    private func macroRing(label: String, grams: Int, color: Color, icon: String) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 4)
                    .frame(width: 50, height: 50)
                Circle()
                    .trim(from: 0, to: macroFraction(grams: grams, label: label))
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }
            Text("\(grams)g")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Pulse.textPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
        }
    }

    private func macroFraction(grams: Int, label: String) -> Double {
        let totalCal = selectedDayType == .training ? profile.trainingDayCalories : profile.restDayCalories
        let calFromMacro: Double
        switch label {
        case "Protein": calFromMacro = Double(grams) * 4
        case "Carbs": calFromMacro = Double(grams) * 4
        case "Fat": calFromMacro = Double(grams) * 9
        default: calFromMacro = 0
        }
        return min(1.0, calFromMacro / max(1, totalCal))
    }

    private var estimatedCarbs: Int {
        let cal = selectedDayType == .training ? profile.trainingDayCalories : profile.restDayCalories
        let proteinCal = profile.proteinTargetG * 4
        let fatCal = Double(estimatedFat) * 9
        return max(50, Int((cal - proteinCal - fatCal) / 4))
    }

    private var estimatedFat: Int {
        let cal = selectedDayType == .training ? profile.trainingDayCalories : profile.restDayCalories
        // ~25% of calories from fat (ISSN general recommendation)
        return Int((cal * 0.25) / 9)
    }

    // MARK: - Day Type Toggle

    private var dayTypeToggle: some View {
        HStack(spacing: 0) {
            ForEach([DailyMealPlan.DayType.training, .rest], id: \.rawValue) { type in
                Button {
                    withAnimation(Pulse.Motion.micro) {
                        selectedDayType = type
                        expandedMealID = nil
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: type == .training ? "dumbbell.fill" : "bed.double.fill")
                            .font(.system(size: 12))
                        Text(type.rawValue)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(selectedDayType == type ? .white : Pulse.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedDayType == type ? Pulse.recovery.opacity(0.2) : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Pulse.surfaceFallback)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Meal Card

    private func mealCard(_ meal: DietMeal) -> some View {
        let isExpanded = expandedMealID == meal.id

        return VStack(spacing: 0) {
            // Header — always visible
            Button {
                withAnimation(Pulse.Motion.standard) {
                    expandedMealID = isExpanded ? nil : meal.id
                }
            } label: {
                HStack(spacing: 12) {
                    Text(meal.mealType.icon)
                        .font(.system(size: 22))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Pulse.textPrimary)
                        Text("\(meal.mealType.timeHint) · \(meal.totalCalories) kcal")
                            .font(.system(size: 11))
                            .foregroundColor(Pulse.textTertiary)
                    }

                    Spacer()

                    // Compact macro chips
                    HStack(spacing: 6) {
                        macroChip(value: Int(meal.totalProtein), label: "P", color: Pulse.energy)
                        macroChip(value: Int(meal.totalCarbs), label: "C", color: Pulse.hydration)
                        macroChip(value: Int(meal.totalFat), label: "F", color: Pulse.nutrition)
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Pulse.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)

            // Expanded food list
            if isExpanded {
                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.vertical, 8)

                VStack(spacing: 8) {
                    ForEach(meal.foods, id: \.food.id) { item in
                        foodRow(food: item.food, servings: item.servings)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .payaCard(padding: 14)
        .padding(.horizontal, 20)
    }

    private func macroChip(value: Int, label: String, color: Color) -> some View {
        Text("\(value)\(label)")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func foodRow(food: FoodItem, servings: Double) -> some View {
        HStack(spacing: 10) {
            Text(food.emoji)
                .font(.system(size: 20))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(food.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Pulse.textPrimary)
                HStack(spacing: 4) {
                    Text(servings == 1 ? food.servingSize : "\(String(format: "%.0f", servings))× \(food.servingSize)")
                        .font(.system(size: 10))
                        .foregroundColor(Pulse.textTertiary)
                    if food.tags.contains(.antiInflammatory) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Pulse.recovery.opacity(0.6))
                    }
                    if food.tags.contains(.omega3Rich) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Pulse.hydration.opacity(0.6))
                    }
                }
            }

            Spacer()

            HStack(spacing: 1) {
                Text("\(Int(Double(food.calories) * servings))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Pulse.textSecondary)
                Text(" kcal")
                    .font(.system(size: 9))
                    .foregroundColor(Pulse.textTertiary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Anti-Inflammatory Section

    private var antiInflammatorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .foregroundColor(Pulse.recovery)
                Text("Anti-Inflammatory Foods")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Pulse.textPrimary)
            }

            Text("Prioritize these to reduce systemic inflammation — Mediterranean diet evidence (Sköldstam 2003, Calder 2017)")
                .font(.system(size: 11))
                .foregroundColor(Pulse.textTertiary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(FoodDatabase.antiInflammatoryFoods.prefix(6)) { food in
                    HStack(spacing: 6) {
                        Text(food.emoji)
                            .font(.system(size: 16))
                        Text(food.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Pulse.textPrimary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Pulse.recovery.opacity(0.06))
                    )
                }
            }
        }
        .payaCard(padding: 14)
        .padding(.horizontal, 20)
    }

    // MARK: - Foods to Limit

    private var foodsToLimitSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Pulse.warning)
                Text("Limit These")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Pulse.textPrimary)
            }

            VStack(spacing: 6) {
                ForEach(FoodDatabase.foodsToLimit) { food in
                    HStack(spacing: 10) {
                        Text(food.emoji)
                            .font(.system(size: 18))
                        Text(food.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Pulse.textPrimary)
                        Spacer()
                        Text(limitReason(for: food))
                            .font(.system(size: 10))
                            .foregroundColor(Pulse.critical.opacity(0.7))
                    }
                }
            }
        }
        .payaCard(padding: 14)
        .padding(.horizontal, 20)
    }

    private func limitReason(for food: FoodItem) -> String {
        if food.tags.contains(.highSodium) { return "Increases inflammation" }
        if food.tags.contains(.processedSugar) { return "Spikes blood sugar" }
        return "Promotes inflammation"
    }

    // MARK: - Coach Notes (AI Enhancement)

    private var coachNotesSection: some View {
        VStack(spacing: 10) {
            if let plan = profile.cachedSymptomDietPlan, !plan.isEmpty {
                // AI plan exists — show as collapsible coach notes
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

                        if let date = profile.symptomDietPlanGeneratedAt {
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

            // Generate / Regenerate button
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
                    Text(profile.cachedSymptomDietPlan == nil
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

    // MARK: - Generate

    private func generate() async {
        isGenerating = true
        errorText = nil
        let result = await SymptomDietEngine.generate(profile: profile, context: modelContext, apiKey: appState.anthropicAPIKey)
        if result != nil {
            try? modelContext.save()
            showCoachNotes = true
        } else {
            errorText = AIService.shared.lastError ?? "Couldn't generate coaching — check connection."
        }
        isGenerating = false
    }
}
