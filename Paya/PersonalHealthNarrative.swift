import SwiftUI
import SwiftData

// MARK: - Personal Health Narrative
//
// Monthly AI-generated synthesis of training, nutrition, sleep, and
// recovery interactions. Transforms raw data into a ~500-word prose
// narrative that reads like a coach's monthly review letter.
//
// Why this matters: Whoop/Oura show dashboards of numbers. Nobody
// reads 30 dashboards to understand their month. This synthesizes
// trends, anomalies, and connections into one coherent story.
//
// Privacy: uses the same AIService routing (Apple Intelligence
// on-device first, Claude API fallback) — data never leaves the
// device unless the user has explicitly configured a cloud API key.

struct PersonalHealthNarrativeCard: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var narrative: String? = nil
    @State private var isGenerating = false
    @State private var lastGenerated: Date? = nil
    @State private var isExpanded = false

    private let cacheKey = "personal_health_narrative_cache"
    private let dateKey = "personal_health_narrative_date"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "text.book.closed.fill")
                    .foregroundColor(Pulse.hydration)
                    .font(.system(size: 12))
                Text("Your health story")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if lastGenerated != nil {
                    Text("Monthly")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Pulse.hydration)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Pulse.hydration.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if isGenerating {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Synthesizing your month…")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else if let narrative = narrative {
                VStack(alignment: .leading, spacing: 6) {
                    let displayText = isExpanded ? narrative : String(narrative.prefix(200)) + "…"
                    Text(displayText)
                        .font(.system(size: 11))
                        .foregroundColor(Pulse.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)

                    Button {
                        withAnimation { isExpanded.toggle() }
                    } label: {
                        Text(isExpanded ? "Show less" : "Read full narrative")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Pulse.hydration)
                    }

                    if let date = lastGenerated {
                        let formatter = RelativeDateTimeFormatter()
                        Text("Generated \(formatter.localizedString(for: date, relativeTo: .now))")
                            .font(.system(size: 9))
                            .foregroundColor(Pulse.textTertiary)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "text.book.closed")
                        .font(.title3)
                        .foregroundColor(Pulse.textTertiary)
                    Text("Generate your monthly health narrative")
                        .font(.caption.weight(.semibold))
                    Text("AI synthesizes 30 days of training, nutrition, sleep, and recovery into one coherent story.")
                        .font(.system(size: 10))
                        .foregroundColor(Pulse.textTertiary)
                        .multilineTextAlignment(.center)

                    Button {
                        Task { await generate() }
                    } label: {
                        Text("Generate narrative")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Pulse.hydration)
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            HStack(spacing: 4) {
                Image(systemName: AIService.shared.providerIcon)
                    .font(.system(size: 8))
                Text("Powered by \(AIService.shared.providerName) · Your data stays \(AIService.shared.isAppleIntelligenceAvailable ? "on-device" : "encrypted in transit")")
                    .font(.system(size: 9))
            }
            .foregroundColor(Pulse.textTertiary)
        }
        .payaCard(padding: 14)
        .onAppear { loadCache() }
    }

    // MARK: - Generate

    @MainActor
    private func generate() async {
        isGenerating = true
        defer { isGenerating = false }

        let summary = await gatherMonthlySummary()

        let system = """
        You are a personal health coach writing a monthly review letter to your client. \
        Write in second person ("you"), direct but warm tone. ~400-500 words. \
        Structure: 1) Overall month summary (1-2 sentences), 2) Training highlights and patterns, \
        3) Nutrition observations, 4) Sleep and recovery trends, 5) One specific, actionable \
        recommendation for next month. Reference actual numbers from the data. \
        Do not make up data points not in the input. If data is missing, acknowledge it \
        briefly and move on.
        """

        let result = await AIService.shared.generate(
            system: system,
            userMessage: summary,
            apiKey: appState.anthropicAPIKey,
            requiresReasoning: true
        )

        if let result = result {
            narrative = result
            lastGenerated = Date()
            UserDefaults.standard.set(result, forKey: cacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: dateKey)
        }
    }

    private func loadCache() {
        if let cached = UserDefaults.standard.string(forKey: cacheKey) {
            narrative = cached
            let ts = UserDefaults.standard.double(forKey: dateKey)
            if ts > 0 { lastGenerated = Date(timeIntervalSince1970: ts) }
        }
    }

    @MainActor
    private func gatherMonthlySummary() async -> String {
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: .now)!

        // Training
        let sDesc = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid && $0.isCompleted && $0.date >= thirtyDaysAgo },
            sortBy: [SortDescriptor(\.date)]
        )
        let sessions = (try? modelContext.fetch(sDesc)) ?? []
        let totalVolume = sessions.reduce(0.0) { total, s in
            total + s.exercises.reduce(0.0) { t, ex in
                t + ex.sets.filter(\.isCompleted).reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }
            }
        }
        let prs = ProgressAnalytics.recentPRs(sessions: sessions, daysBack: 30)
        let avgDuration = sessions.isEmpty ? 0 : sessions.map(\.durationMinutes).reduce(0, +) / sessions.count
        let avgRPE = sessions.compactMap(\.subjectiveRPE).isEmpty ? nil :
            sessions.compactMap(\.subjectiveRPE).reduce(0, +) / sessions.compactMap(\.subjectiveRPE).count

        // Nutrition
        let nDesc = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == pid && $0.date >= thirtyDaysAgo }
        )
        let nutritionLogs = (try? modelContext.fetch(nDesc)) ?? []
        let avgProtein = nutritionLogs.isEmpty ? 0 : nutritionLogs.map(\.totalProtein).reduce(0, +) / Double(nutritionLogs.count)
        let avgCalories = nutritionLogs.isEmpty ? 0 : nutritionLogs.map(\.totalCalories).reduce(0, +) / Double(nutritionLogs.count)
        let proteinHitDays = nutritionLogs.filter { $0.totalProtein >= Double($0.proteinTarget) * 0.9 }.count

        // Sleep & recovery
        let bio = BiometricStore.shared
        if bio.history.isEmpty { await bio.loadHistory(daysBack: 30) }
        let recent = bio.history.filter { $0.date >= thirtyDaysAgo }
        let avgSleep = recent.compactMap(\.sleepHours).isEmpty ? nil :
            recent.compactMap(\.sleepHours).reduce(0, +) / Double(recent.compactMap(\.sleepHours).count)
        let avgHRV = recent.compactMap(\.hrv).isEmpty ? nil :
            recent.compactMap(\.hrv).reduce(0, +) / Double(recent.compactMap(\.hrv).count)
        let avgRHR = recent.compactMap(\.restingHR).isEmpty ? nil :
            recent.compactMap(\.restingHR).reduce(0, +) / Double(recent.compactMap(\.restingHR).count)

        // Check-ins
        let ciDesc = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate<DailyCheckIn> { $0.profileId == pid && $0.date >= thirtyDaysAgo }
        )
        let checkIns = (try? modelContext.fetch(ciDesc)) ?? []
        let avgEnergy = checkIns.isEmpty ? nil : Double(checkIns.map(\.energy).reduce(0, +)) / Double(checkIns.count)

        // Behavior tags
        let blDesc = FetchDescriptor<BehaviorLog>(
            predicate: #Predicate<BehaviorLog> { $0.profileId == pid && $0.date >= thirtyDaysAgo }
        )
        let behaviorLogs = (try? modelContext.fetch(blDesc)) ?? []
        let allTags = behaviorLogs.flatMap(\.tagIds)
        let tagCounts = Dictionary(allTags.map { ($0, 1) }, uniquingKeysWith: +)
        let topBehaviors = tagCounts.sorted { $0.value > $1.value }.prefix(5)

        // Weight
        let wDesc = FetchDescriptor<BodyWeightLog>(
            predicate: #Predicate<BodyWeightLog> { $0.profileId == pid && $0.date >= thirtyDaysAgo },
            sortBy: [SortDescriptor(\.date)]
        )
        let weights = (try? modelContext.fetch(wDesc)) ?? []
        let weightChange: Double? = {
            guard weights.count >= 2, let last = weights.last, let first = weights.first else { return nil }
            return last.weightKg - first.weightKg
        }()

        var summary = """
        MONTHLY DATA SUMMARY (last 30 days):

        TRAINING:
        - \(sessions.count) sessions completed
        - Total volume: \(Int(totalVolume)) kg
        - Average session: \(avgDuration) min
        - Personal records set: \(prs.count)
        """
        if let rpe = avgRPE { summary += "\n- Average RPE: \(rpe)/10" }

        summary += """

        NUTRITION (\(nutritionLogs.count) days logged):
        - Average protein: \(Int(avgProtein))g/day
        - Average calories: \(Int(avgCalories))/day
        - Protein target hit: \(proteinHitDays)/\(nutritionLogs.count) days
        """

        summary += "\n\nSLEEP & RECOVERY:"
        if let sleep = avgSleep { summary += "\n- Average sleep: \(String(format: "%.1f", sleep))h" }
        if let hrv = avgHRV { summary += "\n- Average HRV: \(Int(hrv))ms" }
        if let rhr = avgRHR { summary += "\n- Average RHR: \(Int(rhr))bpm" }

        if let energy = avgEnergy {
            summary += "\n- Average self-reported energy: \(String(format: "%.1f", energy))/3"
        }

        if !topBehaviors.isEmpty {
            summary += "\n\nBEHAVIOR TAGS (most frequent):"
            for (tag, count) in topBehaviors {
                let label = BehaviorTags.tag(for: tag)?.label ?? tag
                summary += "\n- \(label): \(count) days"
            }
        }

        if let wc = weightChange {
            summary += "\n\nBODY WEIGHT: \(String(format: "%+.1f", wc)) kg over the period"
        }

        summary += "\n\nProfile: \(appState.profile.name), \(appState.profile.age) years old, goal: \(appState.profile.goal.displayName)"

        return summary
    }
}
