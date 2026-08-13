import AppIntents
import SwiftData

// MARK: - App Intents (Siri / Shortcuts / Spotlight)
//
// Every build this session logged "Metadata extraction skipped. No
// AppIntents.framework dependency found" — the project had zero Siri
// Shortcuts / Spotlight integration despite having exactly the kind of
// quick, single-value actions (log water, log weight) that this feature is
// built for. This requires no new Xcode target (unlike a widget or Live
// Activity, which would need the same kind of target-creation surgery that
// caused the watch-app saga earlier) — App Intents live directly in the
// app target.

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Add water intake to today's total in Paya.")

    @Parameter(title: "Amount (ml)", default: 250)
    var amountMl: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amountMl) of water")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(SharedModelContainer.shared)
        let total = WaterStore.addWater(amountMl, context: context)
        return .result(dialog: "Logged \(amountMl)ml — you're at \(total)ml today.")
    }
}

struct LogBodyWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Body Weight"
    static var description = IntentDescription("Log your current body weight in Paya.")

    @Parameter(title: "Weight (kg)")
    var weightKg: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Log body weight of \(\.$weightKg)kg")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(SharedModelContainer.shared)
        let log = BodyWeightLog(weightKg: weightKg)
        log.profileId = ActiveProfile.id
        context.insert(log)
        if let profile = ProfileStore.current(context: context) {
            profile.currentWeightKg = weightKg
        }
        try? context.save()
        _ = await HealthKitManager.shared.saveBodyWeight(weightKg)
        return .result(dialog: "Logged \(weightKg, format: .number.precision(.fractionLength(1)))kg.")
    }
}

struct LogFlareIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Flare"
    static var description = IntentDescription("Mark today as a flare day in Paya — reduces suggested training weights and flags the day for pattern learning. Built for exactly the moment typing into the app is hardest.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(SharedModelContainer.shared)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let pid = ActiveProfile.id

        let descriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.profileId == pid }
        )
        let allLogs = (try? context.fetch(descriptor)) ?? []
        if let log = allLogs.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            log.isFlareDay = true
        } else {
            let newLog = HealthLog(date: Date(), isFlareDay: true)
            newLog.profileId = pid
            context.insert(newLog)
        }
        try? context.save()
        return .result(dialog: "Logged today as a flare day. Take it easy — I've noted it.")
    }
}

struct FlareRiskStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Flare Risk Status"
    static var description = IntentDescription("Hear today's flare risk assessment from Paya without opening the app.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(SharedModelContainer.shared)
        let biometrics = BiometricStore.shared
        if biometrics.history.isEmpty {
            await biometrics.loadHistory(daysBack: 30)
        }
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.profileId == pid }
        )
        let healthLogs = (try? context.fetch(descriptor)) ?? []
        let assessment = FlareDetectionEngine.shared.assess(biometrics: biometrics, healthLogs: healthLogs)
        return .result(dialog: "Flare risk is \(assessment.level.displayName.lowercased()). \(assessment.recommendation)")
    }
}

struct OpenTodaysWorkoutIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Today's Workout"
    static var description = IntentDescription("Jump straight to the Train tab in Paya.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(1, forKey: PayaIntentNavigation.requestedTabKey)
        return .result()
    }
}

// MARK: - Navigation bridge
// App Intents run outside the normal view hierarchy, so this is a plain
// UserDefaults flag ContentView reads on appear/foreground to jump tabs —
// no Environment/Binding access is available from an intent's perform().
enum PayaIntentNavigation {
    nonisolated static let requestedTabKey = "paya_intent_requested_tab"
}

// MARK: - Siri phrase donation

struct PayaAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Log water in \(.applicationName)",
                "Add water in \(.applicationName)"
            ],
            shortTitle: "Log Water",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: LogBodyWeightIntent(),
            phrases: [
                "Log my weight in \(.applicationName)",
                "Log body weight in \(.applicationName)"
            ],
            shortTitle: "Log Weight",
            systemImageName: "scalemass.fill"
        )
        AppShortcut(
            intent: OpenTodaysWorkoutIntent(),
            phrases: [
                "Start today's workout in \(.applicationName)",
                "Open my workout in \(.applicationName)"
            ],
            shortTitle: "Today's Workout",
            systemImageName: "dumbbell.fill"
        )
        AppShortcut(
            intent: LogFlareIntent(),
            phrases: [
                "Log a flare in \(.applicationName)",
                "I'm having a flare in \(.applicationName)"
            ],
            shortTitle: "Log a Flare",
            systemImageName: "exclamationmark.triangle.fill"
        )
        AppShortcut(
            intent: FlareRiskStatusIntent(),
            phrases: [
                "What's my flare risk in \(.applicationName)",
                "Flare risk in \(.applicationName)"
            ],
            shortTitle: "Flare Risk",
            systemImageName: "waveform.path.ecg"
        )
    }
}
