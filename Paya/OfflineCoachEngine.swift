import SwiftUI
import SwiftData

// MARK: - Offline-First AI Coach
//
// A deterministic rule engine that generates personalized daily
// coaching suggestions without any API call or network connection.
// Runs purely on local data — zero latency, zero cost, works in
// airplane mode.
//
// This is NOT an LLM. It's a structured decision tree that checks
// today's context (readiness, training plan, nutrition gaps,
// recovery status, behavior patterns) and emits the single most
// relevant suggestion. Think of it as the coach's daily "one thing
// to focus on" whisper.
//
// Why rule-based over LLM: latency (instant vs 2-5s), cost ($0 vs
// $0.01/call), reliability (deterministic vs stochastic), privacy
// (nothing leaves device, period).

struct OfflineCoachCard: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var suggestion: CoachSuggestion?

    var body: some View {
        Group {
        if let s = suggestion {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: s.colorHex).opacity(0.15))
                            .frame(width: 28, height: 28)
                        Image(systemName: s.icon)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: s.colorHex))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(s.category.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(hex: s.colorHex))
                        Text(s.title)
                            .font(.caption.weight(.semibold))
                    }
                    Spacer()
                    Image(systemName: "brain.filled.head.profile")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Text(s.message)
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1.5)

                if let source = s.source {
                    HStack(spacing: 3) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 8))
                        Text(source)
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)
                }
            }
            .payaCard(padding: 14)
        }
        }
        .onAppear { evaluate() }
    }

    // MARK: - Computation
    // Priority-ordered rule evaluation — first matching rule wins.

    @MainActor
    func evaluate() {
        let calendar = Calendar.current
        let pid = ActiveProfile.id
        let today = calendar.startOfDay(for: .now)

        // 1. Check readiness
        let readinessReport = ReadinessEngine.compute(store: BiometricStore.shared, context: modelContext)
        let readiness = readinessReport?.score

        // 2. Check if training day
        let isTrainingDay = appState.isTrainingDay

        // 3. Recent sessions
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let sDesc = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid && $0.isCompleted && $0.date >= weekAgo }
        )
        let weekSessions = (try? modelContext.fetch(sDesc)) ?? []

        // 4. Nutrition today
        let nDesc = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == pid && $0.date >= today }
        )
        let todayNutrition = (try? modelContext.fetch(nDesc))?.first

        // 5. Check-in today
        let ciDesc = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate<DailyCheckIn> { $0.profileId == pid && $0.date >= today }
        )
        let todayCheckIn = (try? modelContext.fetch(ciDesc))?.first

        // 6. Water today
        let wDesc = FetchDescriptor<WaterEventLog>(
            predicate: #Predicate<WaterEventLog> { $0.profileId == pid && $0.date >= today }
        )
        let waterEvents = (try? modelContext.fetch(wDesc)) ?? []
        let totalWaterMl = waterEvents.reduce(0) { $0 + $1.ml }

        // RULE ENGINE — first match wins

        // Rule: No check-in yet this morning
        if todayCheckIn == nil {
            let hour = calendar.component(.hour, from: .now)
            if hour >= 6 && hour <= 11 {
                suggestion = CoachSuggestion(
                    title: "Start with a check-in",
                    message: "A 10-second morning check-in shapes your readiness score and helps Paya learn your patterns. Tap to log how you feel.",
                    icon: "sun.max.fill",
                    colorHex: "F59E0B",
                    category: "Morning",
                    source: nil
                )
                return
            }
        }

        // Rule: Very low readiness — suggest rest or light session
        if let readiness = readiness, readiness < 40 {
            if isTrainingDay {
                suggestion = CoachSuggestion(
                    title: "Low readiness — consider a lighter session",
                    message: "Your recovery score is at \(readiness)%. On days like this, reduce volume by 20-30% or switch to mobility work. Pushing through low readiness increases injury risk.",
                    icon: "exclamationmark.triangle.fill",
                    colorHex: "DC2626",
                    category: "Recovery",
                    source: "Based on your HRV and sleep data"
                )
                return
            }
        }

        // Rule: Training day but haven't trained yet
        if isTrainingDay && !weekSessions.contains(where: { calendar.isDateInToday($0.date) }) {
            let hour = calendar.component(.hour, from: .now)
            if hour >= 8 {
                let readinessNote = readiness.map { $0 >= 70 ? "Readiness is good — great time to hit it." : "Readiness is moderate — listen to your body." } ?? ""
                suggestion = CoachSuggestion(
                    title: "Training day — you're up",
                    message: "Today's a scheduled training day. \(readinessNote) Head to the Train tab when ready.",
                    icon: "dumbbell.fill",
                    colorHex: "059669",
                    category: "Training",
                    source: nil
                )
                return
            }
        }

        // Rule: Zero sessions this week (overdue)
        if weekSessions.isEmpty {
            let daysSinceLast: Int
            let allDesc = FetchDescriptor<TrainingSession>(
                predicate: #Predicate<TrainingSession> { $0.profileId == pid && $0.isCompleted },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let lastSession = (try? modelContext.fetch(allDesc))?.first
            daysSinceLast = lastSession.map { calendar.dateComponents([.day], from: $0.date, to: .now).day ?? 0 } ?? 999

            if daysSinceLast >= 5 {
                suggestion = CoachSuggestion(
                    title: "It's been \(daysSinceLast) days",
                    message: "No sessions logged this week. Even a 20-minute session maintains momentum. The hardest part is showing up.",
                    icon: "flame.fill",
                    colorHex: "F59E0B",
                    category: "Consistency",
                    source: "Habit momentum research (Lally 2010)"
                )
                return
            }
        }

        // Rule: Protein gap
        if let nutrition = todayNutrition {
            let proteinGap = Double(nutrition.proteinTarget) - nutrition.totalProtein
            if proteinGap > 30 {
                let hour = calendar.component(.hour, from: .now)
                if hour >= 14 { // afternoon check
                    suggestion = CoachSuggestion(
                        title: "\(Int(proteinGap))g protein to go",
                        message: "You're \(Int(proteinGap))g short of your protein target. Quick options: Greek yogurt (20g), chicken breast (31g/100g), or a protein shake (25-30g).",
                        icon: "target",
                        colorHex: "2563EB",
                        category: "Nutrition",
                        source: nil
                    )
                    return
                }
            }
        }

        // Rule: Dehydration
        if totalWaterMl < 1000 {
            let hour = calendar.component(.hour, from: .now)
            if hour >= 12 {
                suggestion = CoachSuggestion(
                    title: "Hydration check",
                    message: "Only \(totalWaterMl)ml logged so far. Aim for 2L+ daily. Dehydration reduces training performance by up to 25% (Cheuvront 2014).",
                    icon: "drop.fill",
                    colorHex: "0891B2",
                    category: "Hydration",
                    source: "Cheuvront & Kenefick (2014), Comprehensive Physiology"
                )
                return
            }
        }

        // Rule: High readiness on rest day — suggest active recovery
        if let readiness = readiness, readiness >= 80 && !isTrainingDay {
            suggestion = CoachSuggestion(
                title: "High readiness — great recovery day",
                message: "Your recovery is at \(readiness)% on a rest day. Consider light cardio (20 min walk) or mobility work to keep blood flowing without adding training stress.",
                icon: "figure.walk",
                colorHex: "059669",
                category: "Recovery",
                source: nil
            )
            return
        }

        // Rule: Post-training day — recovery focus
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let trainedYesterday = weekSessions.contains {
            calendar.startOfDay(for: $0.date) == yesterday
        }
        if trainedYesterday && !isTrainingDay {
            suggestion = CoachSuggestion(
                title: "Recovery day — refuel and rest",
                message: "You trained yesterday. Today, focus on sleep (7-9h target), protein (spread across meals), and light movement. Your muscles grow during recovery, not during training.",
                icon: "bed.double.fill",
                colorHex: "8B5CF6",
                category: "Recovery",
                source: nil
            )
            return
        }

        // Default: general wellness tip
        suggestion = nil
    }
}

// MARK: - Data Types

private struct CoachSuggestion {
    let title: String
    let message: String
    let icon: String
    let colorHex: String
    let category: String
    let source: String?
}

