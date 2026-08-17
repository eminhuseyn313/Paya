import SwiftUI
import SwiftData

// MARK: - Daily Action Card
// The single most-requested feature across fitness app forums:
// "Don't just show me data — tell me what to DO."
//
// Synthesizes sleep, readiness, nutrition, training schedule, and
// recent training data into 3-5 concrete, prioritized actions for
// today. This is the morning card — shows what matters before the
// user does anything.
//
// Each action is grounded in the same data the existing cards show
// individually, but composed into one prioritized view:
// - Sleep < 6h → reduce volume suggestion (Knowles et al. 2018)
// - Protein deficit yesterday → front-load protein today
// - Readiness low → lighter session or active recovery
// - Training day → session reminder with muscle groups
// - Rest day → recovery focus (mobility, walks, sleep)
// - High fatigue index → consider deload
// - Consecutive training days → watch for overreaching

struct DailyAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let color: Color
    let priority: Int  // 1 = most urgent
    let domain: String // "training", "nutrition", "recovery", "health"
}

struct DailyActionCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var actions: [DailyAction] = []
    @State private var expanded = false

    var body: some View {
        Group {
            if !actions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "checklist")
                            .foregroundColor(Pulse.hydration)
                        Text("Today's game plan")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(actions.count) actions")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Pulse.hydration)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Pulse.hydration.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    let visible = expanded ? actions : Array(actions.prefix(3))
                    ForEach(visible) { action in
                        actionRow(action)
                    }

                    if actions.count > 3 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                        } label: {
                            HStack(spacing: 4) {
                                Text(expanded ? "Show less" : "\(actions.count - 3) more")
                                    .font(.system(size: 10, weight: .semibold))
                                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundColor(Pulse.hydration)
                            .frame(maxWidth: .infinity)
                        }
                    }

                    Text("Personalized from your sleep, nutrition, training, and recovery data. On-device, no cloud.")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { buildActions() }
    }

    private func actionRow(_ action: DailyAction) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(action.color.opacity(0.12))
                    .frame(width: 30, height: 30)
                Image(systemName: action.icon)
                    .font(.system(size: 13))
                    .foregroundColor(action.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Pulse.textPrimary)
                Text(action.detail)
                    .font(.system(size: 10))
                    .foregroundColor(Pulse.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            // Domain pill
            Text(action.domain)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(action.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(action.color.opacity(0.08))
                .clipShape(Capsule())
        }
    }

    // MARK: - Action Generation

    private func buildActions() {
        let calendar = Calendar.current
        let pid = ActiveProfile.id
        let today = calendar.startOfDay(for: Date())
        let profile = appState.profile
        var result: [DailyAction] = []

        // 1. Sleep check (from HealthLog or Apple Health)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let healthDesc = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> {
                $0.profileId == pid && $0.date >= yesterday && $0.date < today
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let lastHealth = (try? modelContext.fetch(healthDesc))?.first

        if let sleep = lastHealth?.sleepHours {
            if sleep < 6 {
                result.append(DailyAction(
                    icon: "moon.fill",
                    title: "Low sleep — adjust intensity",
                    detail: String(format: "You logged %.1fh sleep. Drop training volume ~20%% or switch to light cardio. Knowles et al. (2018): <6h sleep reduces strength output 10-15%%.", sleep),
                    color: Pulse.critical,
                    priority: 1,
                    domain: "recovery"
                ))
            } else if sleep >= 8 {
                result.append(DailyAction(
                    icon: "moon.stars.fill",
                    title: "Great sleep — push harder today",
                    detail: String(format: "%.1fh of sleep is above optimal. Your recovery is primed for a high-intensity session.", sleep),
                    color: Pulse.positive,
                    priority: 5,
                    domain: "recovery"
                ))
            }
        }

        // 2. Yesterday's protein
        let nutritionDesc = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> {
                $0.profileId == pid && $0.date >= yesterday && $0.date < today
            }
        )
        if let yesterdayNutrition = (try? modelContext.fetch(nutritionDesc))?.first {
            let deficit = profile.proteinTargetG - yesterdayNutrition.totalProtein
            if deficit > 30 {
                result.append(DailyAction(
                    icon: "fork.knife",
                    title: "Front-load protein today",
                    detail: String(format: "You missed %.0fg protein yesterday. Start with a high-protein breakfast (eggs + Greek yogurt = ~40g) to stay on track today.", deficit),
                    color: Pulse.hydration,
                    priority: 2,
                    domain: "nutrition"
                ))
            }
        }

        // 3. Training day vs rest day
        let isTrainingDay = appState.isTrainingDay
        if isTrainingDay {
            result.append(DailyAction(
                icon: "dumbbell.fill",
                title: "Training day",
                detail: "Your session is planned for today. Warm up properly — 5 min light cardio + dynamic stretches for the target muscles.",
                color: Pulse.ai,
                priority: 3,
                domain: "training"
            ))
        } else {
            result.append(DailyAction(
                icon: "figure.walk",
                title: "Active recovery day",
                detail: "Rest day — but don't be sedentary. A 20-30 min walk and 10 min mobility work speeds recovery more than sitting.",
                color: Pulse.positive,
                priority: 4,
                domain: "recovery"
            ))
        }

        // 4. Consecutive training days check
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let sessionDesc = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> {
                $0.profileId == pid && $0.isCompleted && $0.date >= sevenDaysAgo
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let recentSessions = (try? modelContext.fetch(sessionDesc)) ?? []

        // Count consecutive training days ending yesterday
        var consecutiveDays = 0
        for dayOffset in 1...5 {
            guard let checkDay = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { break }
            let dayStart = calendar.startOfDay(for: checkDay)
            if recentSessions.contains(where: { calendar.isDate($0.date, inSameDayAs: dayStart) }) {
                consecutiveDays += 1
            } else {
                break
            }
        }

        if consecutiveDays >= 3 && isTrainingDay {
            result.append(DailyAction(
                icon: "exclamationmark.triangle.fill",
                title: "Watch for overreaching",
                detail: "\(consecutiveDays) consecutive training days. If RPE feels >8 today, cut 1-2 sets per exercise to avoid overtraining. Consider a rest day tomorrow.",
                color: Pulse.nutrition,
                priority: 2,
                domain: "training"
            ))
        }

        // 5. High fatigue — compute simple version
        let weekSessions = recentSessions.count
        let weekVolume = recentSessions.reduce(0.0) { total, session in
            total + session.exercises.reduce(0.0) { t, ex in
                t + ex.sets.filter(\.isCompleted).reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
            }
        }
        let fatigueEstimate = min(100, Int(Double(weekSessions) * 6 + weekVolume / 1000))

        if fatigueEstimate >= 65 {
            result.append(DailyAction(
                icon: "battery.25percent",
                title: "Consider a deload",
                detail: "Your fatigue index is \(fatigueEstimate)/100. A deload week (50-60% of normal volume) would help recovery without losing progress.",
                color: Pulse.critical,
                priority: 1,
                domain: "training"
            ))
        }

        // 6. Body weight trend (if losing too fast)
        let weightDesc = FetchDescriptor<BodyWeightLog>(
            predicate: #Predicate<BodyWeightLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let weightLogs = (try? modelContext.fetch(weightDesc)) ?? []
        if weightLogs.count >= 7 {
            let latest = weightLogs[0].weightKg
            let weekAgo = weightLogs.first(where: {
                $0.date <= calendar.date(byAdding: .day, value: -5, to: today) ?? today
            })?.weightKg
            if let prev = weekAgo {
                let weeklyLoss = prev - latest
                if weeklyLoss > 1.0 {
                    result.append(DailyAction(
                        icon: "scalemass.fill",
                        title: "Weight dropping fast",
                        detail: String(format: "%.1f kg lost this week — aim for 0.5-1%% bodyweight/week to preserve muscle. Consider adding 200 cal today.", weeklyLoss),
                        color: Pulse.nutrition,
                        priority: 3,
                        domain: "nutrition"
                    ))
                }
            }
        }

        // 7. Energy check from yesterday
        if let energy = lastHealth?.energyLevel, energy == 1 {
            result.append(DailyAction(
                icon: "bolt.slash.fill",
                title: "Low energy yesterday",
                detail: "You reported low energy. Check hydration (aim 2-3L), eat within 1h of waking, and consider 200mg caffeine 30 min pre-workout if training today.",
                color: Pulse.nutrition,
                priority: 3,
                domain: "health"
            ))
        }

        // Sort by priority and store
        actions = result.sorted { $0.priority < $1.priority }
    }
}
