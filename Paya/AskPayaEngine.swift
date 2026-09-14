import Foundation
import SwiftData

// MARK: - Ask Paya
//
// Phase 4 of the correlation roadmap: a conversational surface over the
// user's own data. Every other engine in this app answers a fixed question
// ("what's my flare risk," "what's my readiness") — this lets the user ask
// their OWN question ("why do I feel worse on Mondays?") and get an answer
// grounded in their real history, not a generic wellness-app response.
//
// Routes through the existing AIService (Apple Intelligence on-device first,
// Claude fallback with consent) rather than adding a third AI integration —
// the app already has an established, consent-gated path for exactly this
// kind of request.
//
// The context assembled below is deliberately compact (a handful of
// already-computed summaries, not raw log dumps) — an LLM reasons better
// over a short, curated brief than a wall of undifferentiated rows, and it
// keeps what leaves the device to the minimum needed to answer well.

enum AskPayaEngine {

    struct ChatMessage: Identifiable, Equatable {
        let id = UUID()
        let isUser: Bool
        let text: String
    }

    static func ask(
        question: String,
        history: [ChatMessage],
        context: ModelContext,
        appState: AppState
    ) async -> String? {
        let brief = await buildContext(context: context, appState: appState)

        let system = """
        You are Paya's in-app health assistant. You answer questions about \
        the user's OWN tracked data — training, recovery, nutrition, and (if \
        relevant) their chronic condition — using only the brief below. Be \
        concise (2-4 sentences unless the question needs more), reference the \
        actual numbers you were given rather than speaking in generalities, \
        and say plainly when the data doesn't cover what they're asking \
        instead of guessing. You are not a doctor — never diagnose, and for \
        anything that sounds like a medical emergency or a question only a \
        clinician should answer, say so directly and stop there. This is \
        pattern-spotting from the user's own history, not medical advice.

        TODAY'S BRIEF:
        \(brief)
        """

        // Fold recent turns into the user message — AIService.generate is a
        // single-shot call, not a stateful conversation, so prior turns are
        // passed as transcript rather than relying on server-side history.
        var transcript = ""
        for msg in history.suffix(6) {
            transcript += "\(msg.isUser ? "User" : "Paya"): \(msg.text)\n"
        }
        let userMessage = transcript.isEmpty ? question : "\(transcript)User: \(question)"

        let result = await AIService.shared.generate(
            system: system,
            userMessage: userMessage,
            apiKey: appState.anthropicAPIKey,
            requiresReasoning: true
        )
        return result ?? AIService.shared.lastError
    }

    // MARK: - Context

    private static func buildContext(context: ModelContext, appState: AppState) async -> String {
        var lines: [String] = []
        let profile = appState.profile

        lines.append("Profile: \(profile.name.isEmpty ? "the user" : profile.name), goal \(TrainingGoal(rawValue: profile.goalRaw)?.displayName ?? profile.goalRaw).")

        let store = BiometricStore.shared
        if store.history.isEmpty {
            await store.loadHistory(daysBack: 30)
        }
        if let readiness = ReadinessEngine.compute(store: store, context: context) {
            let driverText = readiness.drivers.prefix(3)
                .map { "\($0.label) \(Int($0.score))" }
                .joined(separator: ", ")
            lines.append("Readiness today: \(readiness.score)/100 (\(readiness.band.rawValue)). Drivers: \(driverText.isEmpty ? "not enough data yet" : driverText).")
        }

        let pid = ActiveProfile.id
        let healthDescriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let healthLogs = (try? context.fetch(healthDescriptor)) ?? []
        let chronicWindowStart = Calendar.current.date(byAdding: .day, value: -28, to: .now) ?? .now
        let chronicSessionDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid && $0.date >= chronicWindowStart }
        )
        let chronicSessions = (try? context.fetch(chronicSessionDescriptor)) ?? []

        if appState.flareEngineEnabled {
            let assessment = FlareDetectionEngine.shared.assess(biometrics: store, healthLogs: healthLogs, recentSessions: chronicSessions)
            lines.append("Flare risk today: \(assessment.level.displayName) (\(assessment.score)/100).")
            if let forecast = FlareForecastEngine.forecast(biometrics: store, todayAssessment: assessment) {
                lines.append("24-48h flare forecast: \(forecast.trajectory.rawValue). \(forecast.summary)")
            }
            let recentFlareDays = healthLogs.prefix(30).filter(\.isFlareDay).count
            lines.append("Flare days in the last 30 tracked: \(recentFlareDays).")
        }

        let last14 = Array(healthLogs.prefix(14))
        if !last14.isEmpty {
            let avgSleep = last14.map(\.sleepHours).filter { $0 > 0 }
            let avgPain = last14.map { Double($0.jointPainLevel) }
            if !avgSleep.isEmpty {
                lines.append(String(format: "Avg sleep (last %d days): %.1fh.", avgSleep.count, avgSleep.reduce(0, +) / Double(avgSleep.count)))
            }
            if !avgPain.isEmpty {
                lines.append(String(format: "Avg joint pain (last %d days): %.1f/10.", avgPain.count, avgPain.reduce(0, +) / Double(avgPain.count)))
            }
        }

        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let sessionDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid && $0.date >= weekAgo && $0.isCompleted }
        )
        let recentSessions = (try? context.fetch(sessionDescriptor)) ?? []
        lines.append("Training sessions this week: \(recentSessions.count).")

        let experiments = ExperimentStore.active(context: context)
        for exp in experiments {
            if let cmp = ExperimentEngine.compare(metric: exp.metric, startDate: exp.startDate, healthLogs: healthLogs), cmp.isReady {
                lines.append("Active experiment \"\(exp.title)\" (since \(exp.startDate.formatted(.dateTime.month().day()))): \(cmp.summary)")
            }
        }

        return lines.joined(separator: "\n")
    }
}
