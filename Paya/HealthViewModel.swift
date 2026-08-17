import SwiftUI
import SwiftData

@MainActor
@Observable
class HealthViewModel {

    // MARK: - State

    var todaysLog: HealthLog? = nil
    var recentLogs: [HealthLog] = []
    var supplementsTakenToday: Set<String> = []
    var isLoading: Bool = false

    // Apple Health snapshot
    var applHealthSleepHours: Double? = nil
    var applHealthRestingHR: Int? = nil
    var applHealthHRV: Double? = nil
    var applHealthEnergyBurned: Double? = nil
    var applHealthSteps: Int? = nil
    var applHealthAvgNoiseDb: Double? = nil
    var applHealthBloodOxygen: Double? = nil
    var applHealthRespiratoryRate: Double? = nil
    var healthKitAuthorized: Bool = false
    var hasWearableData: Bool = false
    var recoveryScore: Int? = nil

    // AI supplement advice
    var supplementAdvice: String? = nil
    var isFetchingAI: Bool = false

    // MARK: - Load

    func load(context: ModelContext) {
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let pid = ActiveProfile.id

        let descriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let allLogs = (try? context.fetch(descriptor)) ?? []

        if let log = allLogs.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            todaysLog = log
            supplementsTakenToday = Set(log.supplementsTaken)
        } else {
            let newLog = HealthLog(date: Date())
            newLog.profileId = pid
            context.insert(newLog)
            try? context.save()
            todaysLog = newLog
        }

        recentLogs = Array(allLogs.prefix(14))
    }

    // MARK: - Apple Health Load

    func loadHealthKitData() async {
        let manager = HealthKitManager.shared

        if !manager.isAuthorized {
            await manager.requestAuthorization()
        }
        healthKitAuthorized = manager.isAuthorized

        async let sleep = HealthMetricsProvider.shared.fetchSleepRobust()
        async let hr = manager.fetchRestingHR()
        async let hrv = manager.fetchHRV()
        async let energy = manager.fetchTodayActiveEnergy()
        async let steps = HealthMetricsProvider.shared.fetchStepsRobust()
        async let noise = manager.fetchHourlyEnvironmentalNoise(for: .now)
        async let spo2 = manager.fetchBloodOxygen()
        async let resp = manager.fetchRespiratoryRate()

        let (sleepVal, hrVal, hrvVal, energyVal, stepsVal, noiseBuckets, spo2Val, respVal) = await (sleep, hr, hrv, energy, steps, noise, spo2, resp)

        applHealthSleepHours = sleepVal
        applHealthRestingHR = hrVal
        applHealthHRV = hrvVal
        applHealthEnergyBurned = energyVal
        applHealthSteps = stepsVal
        applHealthAvgNoiseDb = noiseBuckets.isEmpty ? nil : noiseBuckets.values.reduce(0, +) / Double(noiseBuckets.count)
        applHealthBloodOxygen = spo2Val
        applHealthRespiratoryRate = respVal

        // Detect wearable presence: if we have HR or HRV or sleep, a wearable contributed data
        hasWearableData = hrVal != nil || hrvVal != nil || (sleepVal != nil && sleepVal! > 0)

        recoveryScore = manager.computeRecoveryScore(
            sleepHours: sleepVal,
            hrvMs: hrvVal,
            restingHR: hrVal
        )
    }

    // MARK: - Update

    func updateFlareDay(_ value: Bool, context: ModelContext, appState: AppState) {
        todaysLog?.isFlareDay = value
        appState.isFlareDay = value
        save(context: context)
    }

    func updatePainLevel(_ level: Int, context: ModelContext, appState: AppState) {
        todaysLog?.jointPainLevel = level
        appState.todayPainLevel = level
        save(context: context)
    }

    func updateSleepHours(_ hours: Double, context: ModelContext, appState: AppState) {
        todaysLog?.sleepHours = hours
        appState.todaySleepHours = hours
        save(context: context)
    }

    func updateEnergyLevel(_ level: Int, context: ModelContext, appState: AppState) {
        todaysLog?.energyLevel = level
        appState.todayEnergyLevel = level
        save(context: context)
    }

    func updateNotes(_ notes: String, context: ModelContext) {
        todaysLog?.notes = notes
        save(context: context)
    }

    func toggleSupplement(_ name: String, context: ModelContext) {
        if supplementsTakenToday.contains(name) {
            supplementsTakenToday.remove(name)
        } else {
            supplementsTakenToday.insert(name)
        }
        todaysLog?.supplementsTaken = Array(supplementsTakenToday)
        save(context: context)
    }

    private func save(context: ModelContext) {
        try? context.save()
    }

    // MARK: - AI Advice

    func fetchSupplementAdvice(apiKey: String, condition: ChronicCondition) async {
        isFetchingAI = true
        defer { isFetchingAI = false }

        let painLevel = todaysLog?.jointPainLevel ?? 0
        let sleepHours = todaysLog?.sleepHours ?? 7
        let energyLevel = todaysLog?.energyLevel ?? 2
        let isFlare = todaysLog?.isFlareDay ?? false

        let system = """
        You are a health advisor for someone managing \(condition.promptClause).
        Focus on evidence-based supplement timing and general lifestyle advice for managing that condition.
        You are NOT a doctor — never make medical claims or diagnose. Be practical and concise.
        Keep responses under 3 sentences.
        """

        let userMessage = """
        Today's status:
        - Joint pain: \(painLevel)/10
        - Sleep last night: \(String(format: "%.1f", sleepHours))h
        - Energy: \(["Low", "OK", "High"][energyLevel - 1])
        - Flare day: \(isFlare ? "Yes" : "No")

        What should I prioritize today?
        """

        supplementAdvice = await AIService.shared.generate(
            system: system,
            userMessage: userMessage,
            apiKey: apiKey
        )
    }
}
