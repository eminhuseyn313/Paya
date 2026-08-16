import SwiftUI
import SwiftData

@MainActor
@Observable
class DashboardViewModel {

    // MARK: - State

    var isLoading: Bool = false

    // Today's data
    var todaysNutrition: NutritionLog? = nil
    var todaysHealth: HealthLog? = nil
    var latestWeight: Double? = nil
    var latestWeightDate: Date? = nil
    var latestWeightSource: WeightSource = .none

    // Session progress
    var thisWeekSessions: Int = 0
    var thisWeekPossibleSessions: Int = 3
    var lastSession: TrainingSession? = nil
    var weekStreak: Int = 0
    var thisWeekVolume: Double = 0
    var allCompletedSessions: [TrainingSession] = []

    var freshMuscles: [String] {
        let calendar = Calendar.current
        let now = Date()
        var lastTrained: [String: Date] = [:]
        for session in allCompletedSessions {
            for log in session.exercises {
                guard log.sets.contains(where: \.isCompleted) else { continue }
                let group = log.muscleGroup
                if let existing = lastTrained[group] {
                    if session.date > existing { lastTrained[group] = session.date }
                } else {
                    lastTrained[group] = session.date
                }
            }
        }
        return lastTrained.filter { group, date in
            let hours = calendar.dateComponents([.hour], from: date, to: now).hour ?? 0
            return hours >= 48
        }.map(\.key).sorted()
    }

    var lastSessionDaysAgo: Int? {
        guard let last = lastSession else { return nil }
        return Calendar.current.dateComponents([.day], from: last.date, to: Date()).day
    }

    // Apple Health
    var appleHealthSleep: Double? = nil
    var appleHealthHR: Int? = nil
    var appleHealthHRV: Double? = nil
    var appleHealthSteps: Int? = nil
    var recoveryScore: Int? = nil
    var readiness: ReadinessEngine.Report? = nil
    var hasCheckedInToday: Bool = false
    var hasWearableData: Bool = false

    // TDEE (BMR + steps/TRIMP activity)
    var tdeeToday: TDEEEngine.Breakdown? = nil

    // Weekly AI insight
    var weeklyInsight: String? = nil
    var isFetchingInsight: Bool = false

    // Flare risk
    var flareAssessment: FlareRiskAssessment? = nil

    enum WeightSource {
        case manual
        case appleHealth
        case none

        var displayLabel: String {
            switch self {
            case .manual: return "Manual"
            case .appleHealth: return "Apple Health"
            case .none: return ""
            }
        }
    }

    // MARK: - Load

    func load(context: ModelContext) {
        isLoading = true
        defer { isLoading = false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weightPid = ActiveProfile.id

        // Nutrition
        let nDescriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == weightPid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let nLogs = (try? context.fetch(nDescriptor)) ?? []
        todaysNutrition = nLogs.first { calendar.isDate($0.date, inSameDayAs: today) }

        // Health
        let hDescriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.profileId == weightPid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let hLogs = (try? context.fetch(hDescriptor)) ?? []
        todaysHealth = hLogs.first { calendar.isDate($0.date, inSameDayAs: today) }

        // Manual weight
        let wDescriptor = FetchDescriptor<BodyWeightLog>(
            predicate: #Predicate<BodyWeightLog> { $0.profileId == weightPid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let wLogs = (try? context.fetch(wDescriptor)) ?? []
        if let latest = wLogs.first {
            latestWeight = latest.weightKg
            latestWeightDate = latest.date
            latestWeightSource = .manual
        }

        // Sessions this week
        let sDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == weightPid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let sessions = (try? context.fetch(sDescriptor)) ?? []
        let completedSessions = sessions.filter { $0.isCompleted }
        allCompletedSessions = completedSessions
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let weekSessions = completedSessions.filter { $0.date >= weekStart }
        thisWeekSessions = weekSessions.count
        thisWeekPossibleSessions = max(1, TrainingDayStore.all(context: context).count)
        lastSession = completedSessions.first

        // Weekly volume
        var vol: Double = 0
        for session in weekSessions {
            for log in session.exercises {
                for set in log.sets where set.isCompleted {
                    vol += set.weightKg * Double(set.reps)
                }
            }
        }
        thisWeekVolume = vol

        // Week streak
        var weeksWithSession = Set<DateComponents>()
        for session in completedSessions {
            weeksWithSession.insert(calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.date))
        }
        var streak = 0
        var checkWeekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        ) ?? Date()
        for weekIndex in 0..<104 {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: checkWeekStart)
            if weeksWithSession.contains(comps) {
                streak += 1
            } else if weekIndex > 0 {
                break
            }
            checkWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: checkWeekStart) ?? checkWeekStart
        }
        weekStreak = streak
    }

    // MARK: - Apple Health load

    func loadAppleHealthData(context: ModelContext, profile: UserProfile) async {
        let manager = HealthKitManager.shared

        if !manager.isAuthorized {
            await manager.requestAuthorization()
        }

        async let sleep = HealthMetricsProvider.shared.fetchSleepRobust()
        async let hr = manager.fetchRestingHR()
        async let hrv = manager.fetchHRV()
        async let appleWeight = manager.fetchLatestBodyWeight()
        async let steps = HealthMetricsProvider.shared.fetchStepsRobust()

        let (sleepVal, hrVal, hrvVal, weightData, stepsVal) = await (sleep, hr, hrv, appleWeight, steps)

        appleHealthSleep = sleepVal
        appleHealthHR = hrVal
        appleHealthHRV = hrvVal
        appleHealthSteps = stepsVal
        hasWearableData = hrVal != nil || hrvVal != nil || (sleepVal != nil && sleepVal! > 0)
        tdeeToday = TDEEEngine.computeToday(profile: profile, steps: stepsVal ?? 0, context: context)

        // Weight resolution: Apple Health wins if newer than manual
        if let apple = weightData {
            let manualDate = latestWeightDate ?? .distantPast
            if apple.date > manualDate {
                latestWeight = apple.weight
                latestWeightDate = apple.date
                latestWeightSource = .appleHealth
            }
        }

        // Compute flare risk
        await loadFlareAssessment(context: context)

        // Single readiness source — ReadinessEngine uses z-scores against
        // the user's own 30-day baseline, which is what the detail view
        // displays. Using one source eliminates the mismatch where the
        // home card briefly showed the old absolute-threshold score while
        // the detail already showed the z-score result.
        if let report = ReadinessEngine.compute(store: BiometricStore.shared, context: context) {
            readiness = report
            recoveryScore = report.score
        } else {
            recoveryScore = manager.computeRecoveryScore(
                sleepHours: sleepVal,
                hrvMs: hrvVal,
                restingHR: hrVal
            )
        }

        let pid = ActiveProfile.id
        let todayStart = Calendar.current.startOfDay(for: .now)
        let checkInDescriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate { $0.date >= todayStart && $0.profileId == pid }
        )
        hasCheckedInToday = !((try? context.fetch(checkInDescriptor)) ?? []).isEmpty
    }

    // MARK: - Flare assessment

    func loadFlareAssessment(context: ModelContext) async {
        let store = BiometricStore.shared
        await store.loadHistory(daysBack: 30)

        let pid = ActiveProfile.id
        let hDescriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let healthLogs = (try? context.fetch(hDescriptor)) ?? []

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
        let envDescriptor = FetchDescriptor<EnvironmentalReading>(
            predicate: #Predicate<EnvironmentalReading> { $0.date >= yesterdayStart && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        let envReadings = (try? context.fetch(envDescriptor)) ?? []
        let todaysPressure = envReadings.last { $0.date >= startOfDay }?.barometricPressureKPa
        let yesterdaysPressure = envReadings.last { $0.date < startOfDay }?.barometricPressureKPa
        let pressureDrop: Double? = {
            guard let today = todaysPressure, let yesterday = yesterdaysPressure else { return nil }
            return yesterday - today
        }()
        let noiseByDay = await HealthKitManager.shared.fetchDailyEnvironmentalNoise(daysBack: 1)
        let todaysNoise = noiseByDay[startOfDay]

        flareAssessment = FlareDetectionEngine.shared.assess(
            biometrics: store,
            healthLogs: healthLogs,
            pressureDropKPa: pressureDrop,
            todaysNoiseDb: todaysNoise
        )
    }

    // MARK: - Log weight

    func logWeight(_ kg: Double, context: ModelContext, appState: AppState) async {
        let log = BodyWeightLog(weightKg: kg)
        // Without this, every profile on a shared device saw the SAME
        // combined weight history — corrupting each other's weight chart
        // and feeding AdaptiveCalorieEngine's trend calculation with
        // another person's weigh-ins.
        log.profileId = ActiveProfile.id
        context.insert(log)

        // Write through to the persisted PersonProfile, not just the
        // appState mirror — otherwise AdaptiveCalorieEngine, the AI
        // lifestyle plan, and ProfileSwitcherView all kept using the
        // pre-weigh-in weight.
        if let profile = ProfileStore.current(context: context) {
            profile.currentWeightKg = kg
        }
        try? context.save()

        appState.profile.currentWeightKg = kg

        let targets = GoalEngine.targets(
            goal: appState.profile.goal,
            bodyWeightKg: kg,
            age: appState.profile.age,
            heightCm: appState.profile.heightCm,
            sexRaw: appState.profile.sexRaw
        )
        appState.profile.proteinTargetG = targets.proteinG
        appState.profile.trainingDayCalories = targets.trainingDayCalories
        appState.profile.restDayCalories = targets.restDayCalories
        if let profile = ProfileStore.current(context: context) {
            profile.proteinTargetG = targets.proteinG
            profile.trainingDayCalories = targets.trainingDayCalories
            profile.restDayCalories = targets.restDayCalories
            try? context.save()
        }

        // Also write to Apple Health
        _ = await HealthKitManager.shared.saveBodyWeight(kg)

        load(context: context)
    }

    // MARK: - Weekly insight

    func fetchWeeklyInsight(context: ModelContext, apiKey: String, profile: UserProfile) async {
        isFetchingInsight = true
        defer { isFetchingInsight = false }

        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let pid = ActiveProfile.id

        // Get last week's data
        let sDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let sessions = (try? context.fetch(sDescriptor)) ?? []
        let weekSessions = sessions.filter { $0.date >= weekAgo }

        let hDescriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let healthLogs = (try? context.fetch(hDescriptor)) ?? []
        let weekHealth = healthLogs.filter { $0.date >= weekAgo }

        let flareDays = weekHealth.filter { $0.isFlareDay }.count
        let avgSleep = weekHealth.map { $0.sleepHours }.reduce(0, +) / Double(max(1, weekHealth.count))
        let avgPain = weekHealth.map { $0.jointPainLevel }.reduce(0, +) / max(1, weekHealth.count)

        let sexWord = profile.sexRaw.lowercased() == "female" ? "woman" : "man"
        let personProfile = ProfileStore.current(context: context)
        let conditionClause = (personProfile?.hasInflammatoryCondition == true)
            ? ", managing \(personProfile?.chronicCondition.promptClause ?? "a chronic condition"),"
            : ""
        let focusClause = (personProfile?.priorityMuscle).flatMap { $0 == .none ? nil : $0.displayName }
            .map { " with \($0.lowercased()) as a training focus" } ?? ""

        let system = """
        You are a personal coach reviewing a client's week. \
        They're a \(profile.age)-year-old \(sexWord)\(conditionClause) \
        training \(personProfile?.preferredTrainingDaysPerWeek ?? 3)x/week for \(profile.goal.displayName.lowercased())\(focusClause). \
        Give one specific observation and one specific suggestion for next week. Direct tone. 3-4 sentences.
        """

        let userMessage = """
        This week:
        - \(weekSessions.count) sessions completed of 3 planned
        - \(flareDays) flare days
        - Avg sleep: \(String(format: "%.1f", avgSleep))h
        - Avg joint pain: \(avgPain)/10

        What's your take?
        """

        weeklyInsight = await AIService.shared.generate(
            system: system,
            userMessage: userMessage,
            apiKey: apiKey
        )
    }

    // MARK: - Computed

    var proteinProgress: Double {
        guard let log = todaysNutrition, log.proteinTarget > 0 else { return 0 }
        return min(1.0, log.totalProtein / log.proteinTarget)
    }

    var calorieProgress: Double {
        guard let log = todaysNutrition, log.calorieTarget > 0 else { return 0 }
        return min(1.0, log.totalCalories / log.calorieTarget)
    }
}
