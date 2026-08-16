import SwiftUI
import SwiftData

// MARK: - Supplements (Nutrition tab)
// Self-contained: reads/writes today's HealthLog directly, lists the
// profile's active supplements, tracks streak.

struct NutritionSupplementsCard: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var supplements: [UserSupplement] = []
    @State private var takenToday: Set<String> = []
    @State private var streakDays: Int = 0
    @State private var showManager = false

    private var completion: Double {
        guard !supplements.isEmpty else { return 0 }
        return Double(takenToday.count) / Double(supplements.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Pulse.ai.opacity(0.15), lineWidth: 5)
                        .frame(width: 40, height: 40)
                    Circle()
                        .trim(from: 0, to: completion)
                        .stroke(Pulse.ai,
                                style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .animation(PayaAnimation.dataChange, value: completion)
                    Image(systemName: "pills.fill")
                        .font(.caption)
                        .foregroundColor(Pulse.ai)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Supplements")
                        .font(.subheadline.weight(.semibold))
                    Text("\(takenToday.count)/\(supplements.count) today")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                }

                Spacer()

                if streakDays > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundColor(Pulse.warning)
                        Text("\(streakDays)d")
                            .font(.caption.weight(.bold))
                            .foregroundColor(Pulse.warning)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Pulse.warning.opacity(0.1))
                    .clipShape(Capsule())
                }

                Button {
                    showManager = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                        .frame(width: 30, height: 30)
                        .background(Pulse.surfaceElevatedFallback)
                        .clipShape(Circle())
                }
            }

            if supplements.isEmpty {
                Text("No supplements configured — tap the sliders to add.")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
            } else {
                VStack(spacing: 6) {
                    ForEach(supplements, id: \.id) { supplement in
                        let taken = takenToday.contains(supplement.name)
                        Button {
                            toggle(supplement.name)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                                    .font(.subheadline)
                                    .foregroundColor(taken ? Pulse.positive : .secondary.opacity(0.5))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(supplement.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(Pulse.textPrimary)
                                        .strikethrough(taken)
                                    if !supplement.dose.isEmpty || !supplement.timing.isEmpty {
                                        Text([supplement.dose, supplement.timing]
                                            .filter { !$0.isEmpty }
                                            .joined(separator: " · "))
                                            .font(.caption2)
                                            .foregroundColor(Pulse.textTertiary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                taken
                                    ? Pulse.positive.opacity(0.08)
                                    : Pulse.surfaceElevatedFallback
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(PulsePress())
                    }
                }
            }
        }
        .payaCard(padding: 14)
        .sheet(isPresented: $showManager) {
            SupplementsManagerView(onSave: { reload() })
        }
        .onAppear { reload() }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in reload() }
    }

    // MARK: - Data

    private func todaysLog(createIfMissing: Bool) -> HealthLog? {
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        let descriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate { $0.profileId == pid && $0.date >= startOfDay },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let existing = (try? modelContext.fetch(descriptor))?.first {
            return existing
        }
        guard createIfMissing else { return nil }
        let log = HealthLog()
        log.profileId = pid
        modelContext.insert(log)
        try? modelContext.save()
        return log
    }

    private func reload() {
        UserSupplementStore.seedIfNeeded(goal: appState.profile.goal, context: modelContext)
        supplements = UserSupplementStore.active(context: modelContext)
        takenToday = Set(todaysLog(createIfMissing: false)?.supplementsTaken ?? [])
        computeStreak()
    }

    private func toggle(_ name: String) {
        guard let log = todaysLog(createIfMissing: true) else { return }
        if takenToday.contains(name) {
            takenToday.remove(name)
            removeSupplementMeal(name: name)
        } else {
            takenToday.insert(name)
            addSupplementMeal(name: name)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        log.supplementsTaken = Array(takenToday)
        try? modelContext.save()
        computeStreak()
        appState.dataRefreshTrigger = UUID()
    }

    private func addSupplementMeal(name: String) {
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let nutDescriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == pid && $0.date >= today },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let nutLog = (try? modelContext.fetch(nutDescriptor))?.first else { return }
        let info = SupplementNutrition.lookup(name)
        guard info.calories > 0 || info.protein > 0 || info.hasAnyMicro else { return }
        let meal = MealLog(
            name: "Supplement",
            food: name,
            protein: info.protein,
            calories: info.calories,
            ironMg: info.ironMg,
            calciumMg: info.calciumMg,
            magnesiumMg: info.magnesiumMg,
            zincMg: info.zincMg,
            vitaminDMcg: info.vitaminDMcg,
            potassiumMg: info.potassiumMg,
            vitaminCMg: info.vitaminCMg
        )
        modelContext.insert(meal)
        meal.nutritionLog = nutLog
        nutLog.meals.append(meal)
        nutLog.recalculateTotals()
        try? modelContext.save()
    }

    private func removeSupplementMeal(name: String) {
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let nutDescriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == pid && $0.date >= today },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let nutLog = (try? modelContext.fetch(nutDescriptor))?.first else { return }
        if let meal = nutLog.meals.first(where: { $0.name == "Supplement" && $0.food == name }) {
            nutLog.meals.removeAll { $0.id == meal.id }
            modelContext.delete(meal)
            nutLog.recalculateTotals()
            try? modelContext.save()
        }
    }

    private func computeStreak() {
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .day, value: -35, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate { $0.profileId == pid && $0.date >= monthAgo },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let logs = (try? modelContext.fetch(descriptor)) ?? []

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        // Today counts if any taken; otherwise start from yesterday
        let logsByDay = Dictionary(grouping: logs) { calendar.startOfDay(for: $0.date) }
        if (logsByDay[cursor]?.first?.supplementsTaken.isEmpty ?? true) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        while let dayLogs = logsByDay[cursor],
              let log = dayLogs.first,
              !log.supplementsTaken.isEmpty {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        streakDays = streak
    }
}

// MARK: - Supplement Nutrition Lookup

enum SupplementNutrition {
    struct Info {
        let calories: Double
        let protein: Double
        let ironMg: Double
        let calciumMg: Double
        let magnesiumMg: Double
        let zincMg: Double
        let vitaminDMcg: Double
        let potassiumMg: Double
        let vitaminCMg: Double

        var hasAnyMicro: Bool {
            ironMg > 0 || calciumMg > 0 || magnesiumMg > 0 || zincMg > 0
            || vitaminDMcg > 0 || potassiumMg > 0 || vitaminCMg > 0
        }
    }

    static func lookup(_ name: String) -> Info {
        let key = name.lowercased()
        if key.contains("whey protein") || key.contains("protein powder") {
            return Info(calories: 120, protein: 25, ironMg: 0, calciumMg: 100, magnesiumMg: 0, zincMg: 0, vitaminDMcg: 0, potassiumMg: 150, vitaminCMg: 0)
        }
        if key.contains("creatine") {
            return Info(calories: 0, protein: 0, ironMg: 0, calciumMg: 0, magnesiumMg: 0, zincMg: 0, vitaminDMcg: 0, potassiumMg: 0, vitaminCMg: 0)
        }
        if key.contains("vitamin d") || key.contains("d3") {
            return Info(calories: 0, protein: 0, ironMg: 0, calciumMg: 0, magnesiumMg: 0, zincMg: 0, vitaminDMcg: 125, potassiumMg: 0, vitaminCMg: 0)
        }
        if key.contains("magnesium") {
            return Info(calories: 0, protein: 0, ironMg: 0, calciumMg: 0, magnesiumMg: 300, zincMg: 0, vitaminDMcg: 0, potassiumMg: 0, vitaminCMg: 0)
        }
        if key.contains("omega") || key.contains("fish oil") {
            return Info(calories: 25, protein: 0, ironMg: 0, calciumMg: 0, magnesiumMg: 0, zincMg: 0, vitaminDMcg: 0, potassiumMg: 0, vitaminCMg: 0)
        }
        if key.contains("multivitamin") {
            return Info(calories: 5, protein: 0, ironMg: 8, calciumMg: 200, magnesiumMg: 100, zincMg: 11, vitaminDMcg: 25, potassiumMg: 80, vitaminCMg: 90)
        }
        if key.contains("zinc") {
            return Info(calories: 0, protein: 0, ironMg: 0, calciumMg: 0, magnesiumMg: 0, zincMg: 15, vitaminDMcg: 0, potassiumMg: 0, vitaminCMg: 0)
        }
        if key.contains("iron") {
            return Info(calories: 0, protein: 0, ironMg: 18, calciumMg: 0, magnesiumMg: 0, zincMg: 0, vitaminDMcg: 0, potassiumMg: 0, vitaminCMg: 0)
        }
        if key.contains("vitamin c") {
            return Info(calories: 0, protein: 0, ironMg: 0, calciumMg: 0, magnesiumMg: 0, zincMg: 0, vitaminDMcg: 0, potassiumMg: 0, vitaminCMg: 500)
        }
        if key.contains("calcium") {
            return Info(calories: 0, protein: 0, ironMg: 0, calciumMg: 500, magnesiumMg: 0, zincMg: 0, vitaminDMcg: 0, potassiumMg: 0, vitaminCMg: 0)
        }
        if key.contains("electrolyte") {
            return Info(calories: 10, protein: 0, ironMg: 0, calciumMg: 0, magnesiumMg: 60, zincMg: 0, vitaminDMcg: 0, potassiumMg: 300, vitaminCMg: 0)
        }
        if key.contains("caffeine") {
            return Info(calories: 0, protein: 0, ironMg: 0, calciumMg: 0, magnesiumMg: 0, zincMg: 0, vitaminDMcg: 0, potassiumMg: 0, vitaminCMg: 0)
        }
        if key.contains("beta-alanine") || key.contains("beta alanine") {
            return Info(calories: 0, protein: 0, ironMg: 0, calciumMg: 0, magnesiumMg: 0, zincMg: 0, vitaminDMcg: 0, potassiumMg: 0, vitaminCMg: 0)
        }
        if key.contains("beetroot") || key.contains("nitrate") {
            return Info(calories: 15, protein: 0, ironMg: 0.5, calciumMg: 0, magnesiumMg: 15, zincMg: 0, vitaminDMcg: 0, potassiumMg: 200, vitaminCMg: 3)
        }
        if key.contains("fiber") || key.contains("psyllium") {
            return Info(calories: 10, protein: 0, ironMg: 0, calciumMg: 0, magnesiumMg: 0, zincMg: 0, vitaminDMcg: 0, potassiumMg: 0, vitaminCMg: 0)
        }
        return Info(calories: 0, protein: 0, ironMg: 0, calciumMg: 0, magnesiumMg: 0, zincMg: 0, vitaminDMcg: 0, potassiumMg: 0, vitaminCMg: 0)
    }
}
//  Paya
//
//  Created by Emin Huseynzade on 17.07.26.
//

