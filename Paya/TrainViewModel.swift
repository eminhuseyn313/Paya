import SwiftUI
import SwiftData

@MainActor
@Observable
class TrainViewModel {

    // MARK: - Selected Day

    var selectedDay: DaySnapshot = .fallback
    var availableDays: [DaySnapshot] = []

    var selectedSessionType: SessionType {
        SessionType(rawValue: selectedDay.code) ?? .a
    }

    var selectedDayColor: Color {
        selectedDay.color
    }

    // MARK: - Session Live State

    var isSessionActive: Bool = false
    var isSessionPaused: Bool = false
    var isSimpleMode: Bool = false
    var sessionStartTime: Date? = nil
    var pausedElapsed: TimeInterval = 0
    private var pauseStartTime: Date? = nil
    var exerciseStates: [String: ExerciseState] = [:]
    var showCompletionSheet: Bool = false
    var completedSession: TrainingSession? = nil
    var isFlareDay: Bool
    var previousSessionData: [String: PreviousExerciseData] = [:]
    var previousSessionVolume: Double = 0
    var appStateRef: AppState?
    var recoveryContext: RecoveryContext = .empty
    var currentAdjustment: RecoveryAdjuster.Adjustment? = nil
    private(set) var effectiveExercises: [ExerciseDefinition] = []
    private(set) var fullExerciseCountBeforeQuickMode: Int? = nil

    /// True when the exercise immediately after this one shares the same
    /// superset group — meaning the rest timer should NOT auto-start after
    /// completing a set, since the expectation is to move straight into the
    /// next exercise and only rest once the whole group's round is done.
    func skipsRestTimer(afterExerciseId exerciseId: String) -> Bool {
        guard let index = effectiveExercises.firstIndex(where: { $0.id == exerciseId }),
              let group = effectiveExercises[index].supersetGroup,
              index + 1 < effectiveExercises.count else { return false }
        return effectiveExercises[index + 1].supersetGroup == group
    }

    // MARK: - Data Types

    struct ExerciseState: Identifiable {
        let id: String
        let definition: ExerciseDefinition
        var sets: [SetState]
        var isExpanded: Bool = false
        var note: String = ""
        var cableAttachment: CableAttachment? = nil
        var cablePosition: CablePosition? = nil

        var completedSetsCount: Int {
            sets.filter { $0.isCompleted }.count
        }

        var allSetsCompleted: Bool {
            !sets.isEmpty && sets.allSatisfy { $0.isCompleted }
        }
    }

    enum SetType: String {
        case working
        case warmup
        case dropSet
        case amrap
    }

    struct SetState: Identifiable {
        let id = UUID()
        var setNumber: Int
        var weightKg: Double
        var reps: Int
        var isCompleted: Bool = false
        var isWarmup: Bool = false
        var setType: SetType = .working
        var rpe: Int = 0
        var peakHR: Int? = nil
        var avgHR: Int? = nil
        var endHR: Int? = nil
    }

    struct PreviousExerciseData {
        var weightKg: Double
        var rawWeightKg: Double
        var reps: Int
        var volume: Double
        var allSetsHitTarget: Bool
        var incrementKg: Double = 0
        var sessionDate: Date = .now
        var note: String = ""
        var cableAttachment: CableAttachment? = nil
        var cablePosition: CablePosition? = nil
    }

    // MARK: - Computed

    var totalCompletedSets: Int {
        exerciseStates.values.reduce(0) { $0 + $1.completedSetsCount }
    }

    var totalSessionVolume: Double {
        exerciseStates.values.reduce(0.0) { total, state in
            let volume = state.sets
                .filter { $0.isCompleted && !$0.isWarmup }
                .reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }
            return total + volume
        }
    }

    var orderedExercises: [ExerciseDefinition] {
        effectiveExercises
    }

    var activeElapsed: TimeInterval {
        guard let start = sessionStartTime else { return 0 }
        let raw = Date().timeIntervalSince(start)
        let currentPause = pauseStartTime.map { Date().timeIntervalSince($0) } ?? 0
        return max(0, raw - pausedElapsed - currentPause)
    }

    var sessionDurationMinutes: Int {
        Int(activeElapsed / 60)
    }

    var estimatedTimeRemaining: String? {
        let completed = totalCompletedSets
        guard completed >= 2, activeElapsed > 30 else { return nil }
        let totalSets = effectiveExercises.reduce(0) { $0 + $1.sets }
        let remaining = totalSets - completed
        guard remaining > 0 else { return nil }
        let avgPerSet = activeElapsed / Double(completed)
        let secondsLeft = Int(avgPerSet * Double(remaining))
        let m = secondsLeft / 60
        if m < 1 { return "<1 min left" }
        return "\(m) min left"
    }

    var sessionDurationFormatted: String {
        let total = Int(activeElapsed)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Init

    init(appState: AppState) {
        self.isFlareDay = appState.isFlareDay
    }

    // MARK: - Configure

    func configure(context: ModelContext) {
        TrainingDayStore.seedIfNeeded(context: context)
        availableDays = TrainingDayStore.allSnapshots(context: context)
        if let today = TrainingDayStore.today(context: context) {
            selectedDay = today
        } else if let first = availableDays.first {
            selectedDay = first
        }
        buildExerciseStates(context: context)
        loadPreviousSession(context: context)
    }

    func reloadDays(context: ModelContext) {
        availableDays = TrainingDayStore.allSnapshots(context: context)
        if !availableDays.contains(where: { $0.code == selectedDay.code }) {
            selectedDay = availableDays.first ?? .fallback
        } else if let refreshed = availableDays.first(where: { $0.code == selectedDay.code }) {
            selectedDay = refreshed
        }
        buildExerciseStates(context: context)
        loadPreviousSession(context: context)
    }

    // MARK: - Build Exercise States

    func buildExerciseStates(context: ModelContext? = nil) {
        // Never rebuild from scratch while a session is in progress. This
        // used to fire from `reloadDays`/`loadRecoveryContext`/
        // `loadPreviousSession` any time `appState.dataRefreshTrigger`
        // changed — which happens on EVERY tab switch — silently wiping
        // every logged set back to a fresh, uncompleted state and resetting
        // weights to the suggested default. From the user's side that
        // looked exactly like "I switched tabs and my whole session
        // disappeared." The fix belongs here, not at each call site: this
        // is the one place that actually does the destructive rebuild, so
        // guarding it protects every current and future caller.
        guard !isSessionActive else { return }
        if let ctx = context {
            effectiveExercises = CustomSessionStore.effectiveExercises(
                forCode: selectedDay.code,
                context: ctx
            )
            fullExerciseCountBeforeQuickMode = nil
        }

        exerciseStates = [:]
        for exercise in effectiveExercises {
            let suggested = suggestedWeight(for: exercise)
            let sets = (1...exercise.sets).map { i in
                SetState(
                    setNumber: i,
                    weightKg: suggested,
                    reps: exercise.repRange.max
                )
            }
            exerciseStates[exercise.id] = ExerciseState(
                id: exercise.id,
                definition: exercise,
                sets: sets,
                cableAttachment: CableAttachment.infer(from: exercise.name),
                cablePosition: CablePosition.infer(from: exercise.name)
            )
        }
    }

    // MARK: - Quick Session (protect consistency on a bad day)
    //
    // Offered when RecoveryAdjuster flags the day as caution/deload — i.e.
    // low readiness or a hard day yesterday — the same signal that already
    // trims load elsewhere. Rather than the binary "full session or skip
    // entirely" choice, this trims to just the day's compound lifts at
    // fewer sets: even a brief, reduced session maintains strength far
    // better than a missed one (Iversen VM et al. on minimum-dose
    // resistance training; a hard-zero day loses the frequency/consistency
    // benefit the rest of the app already prioritizes over volume for
    // exactly this reason). Consistency over completeness, for one day.

    func applyQuickSessionMode() {
        guard !isSessionActive else { return }
        let compounds = effectiveExercises.filter { $0.type == .compound }
        let kept = compounds.isEmpty ? Array(effectiveExercises.prefix(2)) : Array(compounds.prefix(2))
        guard !kept.isEmpty else { return }

        fullExerciseCountBeforeQuickMode = effectiveExercises.count
        effectiveExercises = kept
        exerciseStates = exerciseStates.filter { id, _ in kept.contains { $0.id == id } }
        for exercise in kept {
            guard var state = exerciseStates[exercise.id] else { continue }
            state.sets = Array(state.sets.prefix(2))
            exerciseStates[exercise.id] = state
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Add Exercise (today only)

    /// Appends a library exercise to the LIVE session only — the same
    /// "today, not the saved program" philosophy as swapExerciseForToday.
    /// Previously there was no way to add anything once a session started:
    /// the session composer (which edits the persisted program) is
    /// deliberately disabled while a session is active, and the exercise
    /// library is read-only, so "add one more exercise mid-workout" had no
    /// path at all.
    func addExerciseForToday(_ libraryExercise: Exercise) {
        let poolMatch = ExercisePool.all.first { $0.name == libraryExercise.name }
        let startWeight = poolMatch?.startWeightKg ?? 20
        let measurement = ExerciseMeasurement.infer(name: libraryExercise.name, startWeightKg: startWeight)
        let resolvedStartWeight = measurement == .bodyweightReps ? 0 : startWeight
        let muscleGroup = poolMatch?.muscleGroup ?? (libraryExercise.primaryMuscles.first?.capitalized ?? "General")

        let newId = "today_\(UUID().uuidString)"
        let definition = ExerciseDefinition(
            id: newId,
            name: libraryExercise.name,
            type: .isolation,
            sets: 3,
            repRange: .tenToTwelve,
            startWeightKg: resolvedStartWeight,
            progressionNote: "Added for today",
            isJointSensitive: poolMatch?.jointSensitive ?? false,
            specialProgressionRule: "Added mid-session — not part of the saved program",
            alternativeExercise: nil,
            muscleGroup: muscleGroup,
            gifURL: nil,
            alternativeGifURL: nil
        )

        effectiveExercises.append(definition)
        let sets = (1...definition.sets).map { i in
            SetState(setNumber: i, weightKg: resolvedStartWeight, reps: definition.repRange.min)
        }
        exerciseStates[newId] = ExerciseState(
            id: newId,
            definition: definition,
            sets: sets,
            isExpanded: true,
            cableAttachment: CableAttachment.infer(from: definition.name),
            cablePosition: CablePosition.infer(from: definition.name)
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        persistSession()
    }

    // MARK: - Swap Exercise (today only)

    /// Session-scoped substitution — equipment taken, a joint flaring up
    /// today, or just wanting variety. Deliberately doesn't touch the
    /// persisted CustomSessionExercise: the plan reverts to normal next
    /// time this day comes around, since a same-day swap is a today
    /// decision, not a program edit (if the user wants a permanent change
    /// they already have program editing for that). Uses the pool's own
    /// starting weight for the new exercise rather than carrying over the
    /// old exercise's suggested weight, which wouldn't be meaningful across
    /// a different lift.
    func swapExerciseForToday(exerciseId: String, to newName: String) {
        guard let idx = effectiveExercises.firstIndex(where: { $0.id == exerciseId }) else { return }
        let old = effectiveExercises[idx]
        guard newName != old.name else { return }

        let poolMatch = ExercisePool.all.first { $0.name == newName }
        let newStartWeight = poolMatch?.startWeightKg ?? old.startWeightKg
        let newAlternatives = old.alternatives.filter { $0 != newName } + [old.name]

        let updated = ExerciseDefinition(
            id: old.id,
            name: newName,
            type: old.type,
            sets: old.sets,
            repRange: old.repRange,
            startWeightKg: newStartWeight,
            progressionNote: old.progressionNote,
            isJointSensitive: poolMatch?.jointSensitive ?? old.isJointSensitive,
            specialProgressionRule: "Swapped in for today · \(old.name) resumes next session",
            alternativeExercise: old.alternativeExercise,
            muscleGroup: poolMatch?.muscleGroup ?? old.muscleGroup,
            gifURL: nil,
            alternativeGifURL: nil,
            supersetGroup: old.supersetGroup,
            alternatives: newAlternatives
        )
        effectiveExercises[idx] = updated

        let sets = (1...updated.sets).map { i in
            SetState(setNumber: i, weightKg: newStartWeight, reps: updated.repRange.min)
        }
        exerciseStates[exerciseId] = ExerciseState(
            id: exerciseId,
            definition: updated,
            sets: sets,
            cableAttachment: CableAttachment.infer(from: updated.name),
            cablePosition: CablePosition.infer(from: updated.name)
        )
        previousSessionData[exerciseId] = nil
    }

    // MARK: - Suggested Weight

    func suggestedWeight(for exercise: ExerciseDefinition) -> Double {
        var baseWeight: Double
        if let prev = previousSessionData[exercise.id] {
            baseWeight = prev.weightKg
        } else {
            baseWeight = exercise.startWeightKg
        }
        let adjustment = RecoveryAdjuster.compute(
            baseWeight: baseWeight,
            context: recoveryContext
        )
        return adjustment.adjustedWeight
    }

    // MARK: - Recovery Context

    func loadRecoveryContext(context: ModelContext, appState: AppState) async {
            let manager = HealthKitManager.shared

            async let sleep = HealthMetricsProvider.shared.fetchSleepRobust()
            async let hr = manager.fetchRestingHR()
            async let hrv = manager.fetchHRV()

            let (sleepVal, hrVal, hrvVal) = await (sleep, hr, hrv)

            // Flare assessment only for profiles with an inflammatory condition
            var flareLevel: FlareRiskLevel? = nil
            let biometrics = BiometricStore.shared
            if appState.flareEngineEnabled {
                await biometrics.loadHistory(daysBack: 30)

                let flarePid = ActiveProfile.id
                let healthDescriptor = FetchDescriptor<HealthLog>(
                    predicate: #Predicate<HealthLog> { $0.profileId == flarePid },
                    sortBy: [SortDescriptor(\.date, order: .reverse)]
                )
                let healthLogs = (try? context.fetch(healthDescriptor)) ?? []
                let assessment = FlareDetectionEngine.shared.assess(
                    biometrics: biometrics,
                    healthLogs: healthLogs
                )
                flareLevel = assessment.level
            } else {
                await biometrics.loadHistory(daysBack: 30)
            }

            // Baseline-relative readiness where enough history exists (same
            // engine as the dashboard); falls back to the absolute-threshold
            // score so day-one users still get an adjustment signal.
            let recovery = ReadinessEngine.compute(store: biometrics, context: context)?.score
                ?? manager.computeRecoveryScore(sleepHours: sleepVal, hrvMs: hrvVal, restingHR: hrVal)

            let calendar = Calendar.current
            let pid = ActiveProfile.id
            let chronicWindowStart = calendar.date(byAdding: .day, value: -28, to: Date()) ?? Date()
            let sessionDescriptor = FetchDescriptor<TrainingSession>(
                predicate: #Predicate<TrainingSession> { $0.profileId == pid && $0.date >= chronicWindowStart },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let sessions = (try? context.fetch(sessionDescriptor)) ?? []
            let yesterdayTrimp = sessions.first {
                guard let yesterday = calendar.date(
                    byAdding: .day, value: -1, to: Date()
                ) else { return false }
                return calendar.isDate($0.date, inSameDayAs: yesterday)
            }?.sessionTrimpScore

            // Chronic daily-average TRIMP over a trailing 28 days — the
            // standard chronic window in the acute:chronic workload ratio
            // model (Gabbett et al.), used so "heavy session yesterday"
            // means heavy relative to THIS person's own recent training,
            // not an arbitrary fixed TRIMP number that means something
            // different for a beginner vs. an advanced lifter.
            let chronicAvgTrimp = sessions.isEmpty ? nil :
                sessions.reduce(0.0) { $0 + ($1.sessionTrimpScore ?? 0) } / 28.0

        self.recoveryContext = RecoveryContext(
                    recoveryScore: recovery,
                    sleepHours: sleepVal,
                    flareLevel: flareLevel,
                    isFlareDay: appState.flareEngineEnabled && appState.isFlareDay,
                    yesterdayTrimp: yesterdayTrimp,
                    chronicAvgDailyTrimp: chronicAvgTrimp,
                    restingHR: hrVal.map { Int($0) },
                    isDeloadWeek: DeloadEngine.isDeloadActive
                )
            let sampleAdjustment = RecoveryAdjuster.compute(
                baseWeight: 20.0,
                context: recoveryContext
            )
            self.currentAdjustment = sampleAdjustment.isAdjusted ? sampleAdjustment : nil

            buildExerciseStates(context: context)
        }
    // MARK: - Previous Session

    func loadPreviousSession(context: ModelContext) {
        let code = selectedDay.code
        let pid = ActiveProfile.id

        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate { $0.sessionType == code && $0.isCompleted == true && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        guard let sessions = try? context.fetch(descriptor),
              let lastSession = sessions.first else { return }

        previousSessionData = [:]
        previousSessionVolume = 0

        for exerciseLog in lastSession.exercises {
            let completedSets = exerciseLog.sets.filter { $0.isCompleted }
            guard !completedSets.isEmpty else { continue }

            let avgWeight = completedSets.map { $0.weightKg }.reduce(0, +) / Double(completedSets.count)
            let avgReps = completedSets.map { $0.reps }.reduce(0, +) / completedSets.count
            let totalVolume = completedSets.reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }

            let definition = effectiveExercises.first { $0.id == exerciseLog.exerciseId }
            var nextWeight = avgWeight
            var allHit = false
            if let def = definition {
                let allSetsCompleted = completedSets.count >= def.sets
                let allHitTop = completedSets.allSatisfy { $0.reps >= def.repRange.max }
                allHit = allSetsCompleted && allHitTop
                if allHit {
                    // Assisted exercises progress by REDUCING weight
                    if AssistedExerciseDetector.isAssisted(name: exerciseLog.exerciseName) {
                        let decrement = AssistedExerciseDetector.progressionIncrement(for: def.repRange)
                        nextWeight = max(0, avgWeight + decrement)
                    } else {
                        nextWeight = avgWeight + def.repRange.increment
                    }
                }
            }

            previousSessionData[exerciseLog.exerciseId] = PreviousExerciseData(
                weightKg: nextWeight,
                rawWeightKg: avgWeight,
                reps: avgReps,
                volume: totalVolume,
                allSetsHitTarget: allHit,
                incrementKg: allHit ? (nextWeight - avgWeight) : 0,
                sessionDate: lastSession.date,
                note: exerciseLog.note,
                cableAttachment: exerciseLog.cableAttachment.flatMap { CableAttachment(rawValue: $0) },
                cablePosition: exerciseLog.cablePosition.flatMap { CablePosition(rawValue: $0) }
            )
            previousSessionVolume += totalVolume
        }

        buildExerciseStates()
    }

    // MARK: - Day Switching

    func switchDay(to day: DaySnapshot, context: ModelContext) {
        selectedDay = day
        buildExerciseStates(context: context)
        loadPreviousSession(context: context)
    }

    // MARK: - Set Interactions

    func toggleSet(exerciseId: String, setIndex: Int) {
        guard var state = exerciseStates[exerciseId] else { return }
        let wasCompleted = state.sets[setIndex].isCompleted
        state.sets[setIndex].isCompleted.toggle()

        if !wasCompleted && state.sets[setIndex].isCompleted {
            let hr = HRSampleBuffer.shared.snapshotAndReset()
            state.sets[setIndex].peakHR = hr.peak
            state.sets[setIndex].avgHR = hr.avg
            state.sets[setIndex].endHR = hr.current
        }

        exerciseStates[exerciseId] = state

        // Auto-advance: when all sets complete, collapse this card and expand next
        if !wasCompleted && state.allSetsCompleted {
            autoAdvance(fromExerciseId: exerciseId)
        }

        pushProgressToAppState()
        persistSession()
    }

    var allExercisesComplete: Bool {
        effectiveExercises.allSatisfy { exerciseStates[$0.id]?.allSetsCompleted == true }
    }

    private func autoAdvance(fromExerciseId: String) {
        guard let currentIndex = effectiveExercises.firstIndex(where: { $0.id == fromExerciseId }) else { return }

        if var current = exerciseStates[fromExerciseId] {
            current.isExpanded = false
            exerciseStates[fromExerciseId] = current
        }

        if allExercisesComplete {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        for i in (currentIndex + 1)..<effectiveExercises.count {
            let nextId = effectiveExercises[i].id
            if var nextState = exerciseStates[nextId], !nextState.allSetsCompleted {
                nextState.isExpanded = true
                exerciseStates[nextId] = nextState
                break
            }
        }
    }

    func completeAllSets(exerciseId: String) {
        guard var state = exerciseStates[exerciseId] else { return }
        let allDone = state.allSetsCompleted
        for i in state.sets.indices {
            state.sets[i].isCompleted = !allDone
        }
        exerciseStates[exerciseId] = state
        pushProgressToAppState()
    }

    func toggleWarmup(exerciseId: String, setIndex: Int) {
        guard var state = exerciseStates[exerciseId] else { return }
        state.sets[setIndex].isWarmup.toggle()
        exerciseStates[exerciseId] = state
    }

    func updateNote(exerciseId: String, note: String) {
        guard var state = exerciseStates[exerciseId] else { return }
        state.note = note
        exerciseStates[exerciseId] = state
    }

    func updateCableAttachment(exerciseId: String, attachment: CableAttachment?) {
        guard var state = exerciseStates[exerciseId] else { return }
        state.cableAttachment = attachment
        exerciseStates[exerciseId] = state
    }

    func updateCablePosition(exerciseId: String, position: CablePosition?) {
        guard var state = exerciseStates[exerciseId] else { return }
        state.cablePosition = position
        exerciseStates[exerciseId] = state
    }

    func updateWeight(exerciseId: String, setIndex: Int, weight: Double) {
        guard var state = exerciseStates[exerciseId] else { return }
        state.sets[setIndex].weightKg = weight
        exerciseStates[exerciseId] = state
        schedulePersist()
    }

    func updateReps(exerciseId: String, setIndex: Int, reps: Int) {
        guard var state = exerciseStates[exerciseId] else { return }
        state.sets[setIndex].reps = reps
        exerciseStates[exerciseId] = state
        schedulePersist()
    }

    func updateRPE(exerciseId: String, setIndex: Int, rpe: Int) {
        guard var state = exerciseStates[exerciseId] else { return }
        state.sets[setIndex].rpe = rpe
        exerciseStates[exerciseId] = state
        schedulePersist()
    }

    /// Debounced persist — waits 1s after the last edit to avoid writing
    /// on every keystroke. Set toggles bypass this and persist immediately.
    private var persistDebounceTask: Task<Void, Never>?

    private func schedulePersist() {
        persistDebounceTask?.cancel()
        persistDebounceTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            persistSession()
        }
    }

    func copyWeightToRemainingSets(from setIndex: Int, exerciseId: String) {
        guard var state = exerciseStates[exerciseId] else { return }
        let weight = state.sets[setIndex].weightKg
        for i in (setIndex + 1)..<state.sets.count {
            state.sets[i].weightKg = weight
        }
        exerciseStates[exerciseId] = state
    }

    func applyWeightToAllSets(exerciseId: String, weight: Double) {
        guard var state = exerciseStates[exerciseId] else { return }
        for i in 0..<state.sets.count {
            state.sets[i].weightKg = weight
        }
        exerciseStates[exerciseId] = state
    }

    func updateFlareDay(_ value: Bool) {
        isFlareDay = value
        buildExerciseStates()
    }

    // MARK: - Add / Remove Sets

    func addSet(to exerciseId: String) {
        guard var state = exerciseStates[exerciseId] else { return }
        let nextNumber = (state.sets.last?.setNumber ?? 0) + 1
        let lastSet = state.sets.last
        state.sets.append(SetState(
            setNumber: nextNumber,
            weightKg: lastSet?.weightKg ?? state.definition.startWeightKg,
            reps: lastSet?.reps ?? state.definition.repRange.min
        ))
        exerciseStates[exerciseId] = state
    }

    func removeSet(from exerciseId: String, setIndex: Int) {
        guard var state = exerciseStates[exerciseId] else { return }
        guard state.sets.count > 1 else { return }
        state.sets.remove(at: setIndex)
        for i in setIndex..<state.sets.count {
            state.sets[i].setNumber = i + 1
        }
        exerciseStates[exerciseId] = state
    }

    func addDropSet(to exerciseId: String) {
        guard var state = exerciseStates[exerciseId] else { return }
        let lastSet = state.sets.last
        let dropWeight = (lastSet?.weightKg ?? 20) * 0.8
        let nextNumber = (state.sets.last?.setNumber ?? 0) + 1
        var newSet = SetState(
            setNumber: nextNumber,
            weightKg: dropWeight,
            reps: lastSet?.reps ?? 10
        )
        newSet.setType = .dropSet
        state.sets.append(newSet)
        exerciseStates[exerciseId] = state
    }

    func addAMRAPSet(to exerciseId: String) {
        guard var state = exerciseStates[exerciseId] else { return }
        let lastSet = state.sets.last
        let nextNumber = (state.sets.last?.setNumber ?? 0) + 1
        var newSet = SetState(
            setNumber: nextNumber,
            weightKg: lastSet?.weightKg ?? 20,
            reps: 0
        )
        newSet.setType = .amrap
        state.sets.append(newSet)
        exerciseStates[exerciseId] = state
    }

    // MARK: - Quick Repeat (one-tap complete with same weight/reps as previous set)

    /// Copies weight and reps from the set above (or previous session if set 0),
    /// marks the set complete, and auto-starts rest timer. This is the fastest
    /// possible logging path: one tap per set when doing straight sets.
    func repeatAndComplete(exerciseId: String, setIndex: Int, exercise: ExerciseDefinition, sessionColor: Color, profile: UserProfile) {
        guard var state = exerciseStates[exerciseId] else { return }
        guard !state.sets[setIndex].isCompleted else { return }

        // Copy from the set above, or from previous session data
        if setIndex > 0 {
            let prevSet = state.sets[setIndex - 1]
            state.sets[setIndex].weightKg = prevSet.weightKg
            state.sets[setIndex].reps = prevSet.reps
        } else if let prev = previousSessionData[exerciseId] {
            state.sets[setIndex].weightKg = prev.weightKg
            state.sets[setIndex].reps = prev.reps
        }

        // Mark complete with HR snapshot
        state.sets[setIndex].isCompleted = true
        let hr = HRSampleBuffer.shared.snapshotAndReset()
        state.sets[setIndex].peakHR = hr.peak
        state.sets[setIndex].avgHR = hr.avg
        state.sets[setIndex].endHR = hr.current

        exerciseStates[exerciseId] = state

        // Auto-advance if all done
        if state.allSetsCompleted {
            autoAdvance(fromExerciseId: exerciseId)
        }

        // Start rest timer with smart duration
        if !skipsRestTimer(afterExerciseId: exerciseId) {
            let lastSet = state.sets[state.sets.count - 1]
            let smartRest = RestTimerManager.smartRest(
                for: exercise,
                history: RestTimerManager.shared.restHistory[exercise.id],
                currentHR: LiveHRManager.shared.currentBPM,
                peakHR: RestTimerManager.shared.peakBPM,
                lastSetRPE: lastSet.rpe,
                lastSetWeightKg: lastSet.weightKg
            )
            RestTimerManager.shared.start(
                seconds: smartRest,
                exerciseName: exercise.name,
                sessionColor: sessionColor,
                profile: profile,
                exerciseId: exercise.id
            )
        }

        pushProgressToAppState()
    }

    /// Pre-fills ALL uncompleted sets for ALL exercises with previous session
    /// data. Called once at session start to eliminate the need to manually
    /// fill each set. Users still adjust individual sets as needed.
    func prefillAllFromPrevious() {
        for exercise in effectiveExercises {
            guard var state = exerciseStates[exercise.id],
                  let prev = previousSessionData[exercise.id] else { continue }
            for i in state.sets.indices where !state.sets[i].isCompleted {
                state.sets[i].weightKg = prev.weightKg
                state.sets[i].reps = prev.reps
            }
            exerciseStates[exercise.id] = state
        }
    }

    func cycleSetType(exerciseId: String, setIndex: Int) {
        guard var state = exerciseStates[exerciseId] else { return }
        let current = state.sets[setIndex].setType
        let next: SetType
        switch current {
        case .working: next = .warmup
        case .warmup: next = .dropSet
        case .dropSet: next = .amrap
        case .amrap: next = .working
        }
        state.sets[setIndex].setType = next
        state.sets[setIndex].isWarmup = (next == .warmup)
        exerciseStates[exerciseId] = state
    }

    // MARK: - Card Expansion

    func toggleExpanded(exerciseId: String) {
        guard var state = exerciseStates[exerciseId] else { return }
        state.isExpanded.toggle()
        exerciseStates[exerciseId] = state
    }

    // MARK: - Reorder Exercises (live session)

    func moveExercise(from sourceIndex: Int, by offset: Int) {
        let destIndex = sourceIndex + offset
        guard effectiveExercises.indices.contains(sourceIndex),
              effectiveExercises.indices.contains(destIndex) else { return }
        effectiveExercises.swapAt(sourceIndex, destIndex)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Session Start / End

    func startSession(appState: AppState) {
        isSessionActive = true
        isSessionPaused = false
        pausedElapsed = 0
        pauseStartTime = nil
        sessionStartTime = Date()
        appStateRef = appState
        appState.startSession()

        // Pre-fill all sets with previous session data so the user
        // only needs to tap checkmarks for straight sets — the single
        // biggest logging-speed improvement users ask for.
        prefillAllFromPrevious()

        pushProgressToAppState()
        BLEHeartRateManager.shared.attemptAutoReconnect()
        HRSampleBuffer.shared.startSampling()
        FocusModeManager.shared.enableShieldForSession()

        if let firstId = effectiveExercises.first?.id {
            exerciseStates[firstId]?.isExpanded = true
        }

        persistSession()
    }

    func pauseSession() {
        guard isSessionActive, !isSessionPaused else { return }
        isSessionPaused = true
        pauseStartTime = Date()
        appStateRef?.isSessionPaused = true
        HRSampleBuffer.shared.stopSampling()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        persistSession()
    }

    func resumeSession() {
        guard isSessionActive, isSessionPaused, let pauseStart = pauseStartTime else { return }
        pausedElapsed += Date().timeIntervalSince(pauseStart)
        pauseStartTime = nil
        isSessionPaused = false
        appStateRef?.isSessionPaused = false
        HRSampleBuffer.shared.startSampling()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        persistSession()
    }

    func discardSession(appState: AppState) {
        ActiveSessionStore.clear()
        isSessionActive = false
        isSessionPaused = false
        isSimpleMode = false
        sessionStartTime = nil
        pausedElapsed = 0
        pauseStartTime = nil
        appState.endSession()
        appStateRef = nil
        HRSampleBuffer.shared.stopSampling()
        HRSampleBuffer.shared.clearSessionSamples()
        RestTimerManager.shared.stop()
        buildExerciseStates()
        WatchSessionManager.shared.pushSessionSnapshot(nil)
        LiveActivityManager.shared.end()
        FocusModeManager.shared.disableShield()
    }

    private func pushProgressToAppState() {
        guard let appState = appStateRef else { return }
        let total = effectiveExercises.reduce(0) { $0 + $1.sets }
        appState.updateSessionProgress(
            label: selectedDay.name,
            color: selectedDay.color,
            completed: totalCompletedSets,
            total: total
        )
        pushWatchSnapshot()
    }

    // MARK: - Watch session control

    /// First exercise (in order) with an incomplete set, and that set's index.
    private func currentIncompleteSet() -> (exerciseId: String, setIndex: Int)? {
        for exercise in effectiveExercises {
            guard let state = exerciseStates[exercise.id] else { continue }
            if let idx = state.sets.firstIndex(where: { !$0.isCompleted }) {
                return (exercise.id, idx)
            }
        }
        return nil
    }

    /// Internal, not private — ExerciseCardView calls this again right
    /// after starting/skipping the rest timer, since that happens a moment
    /// after toggleSet (and thus after the snapshot this triggers from
    /// pushProgressToAppState), so the first push can't see the rest state yet.
    func pushWatchSnapshot() {
        guard isSessionActive,
              let current = currentIncompleteSet(),
              let exercise = effectiveExercises.first(where: { $0.id == current.exerciseId }),
              let state = exerciseStates[current.exerciseId] else {
            WatchSessionManager.shared.pushSessionSnapshot(nil)
            LiveActivityManager.shared.end()
            return
        }
        let set = state.sets[current.setIndex]
        let completedExercises = effectiveExercises.filter { exerciseStates[$0.id]?.allSetsCompleted == true }.count
        let restTimer = RestTimerManager.shared
        let setLabel = "Set \(current.setIndex + 1) of \(state.sets.count)"
        let exerciseProgress = "\(completedExercises) of \(effectiveExercises.count) exercises"
        let restEndDate = restTimer.isActive ? Date().addingTimeInterval(TimeInterval(restTimer.secondsRemaining)) : nil
        let restTotalSeconds = restTimer.isActive ? restTimer.totalSeconds : nil

        WatchSessionManager.shared.pushSessionSnapshot(WatchSessionSnapshot(
            exerciseName: exercise.name,
            setLabel: setLabel,
            suggestedWeightKg: set.weightKg,
            suggestedReps: set.reps,
            sessionLabel: selectedDay.name,
            colorHex: selectedDay.colorHex,
            measurementRaw: exercise.measurement.rawValue,
            exerciseProgress: exerciseProgress,
            restEndDate: restEndDate,
            restTotalSeconds: restTotalSeconds
        ))

        let activityState = PayaSessionActivityAttributes.ContentState(
            exerciseName: exercise.name,
            setLabel: setLabel,
            exerciseProgress: exerciseProgress,
            restEndDate: restEndDate,
            restTotalSeconds: restTotalSeconds
        )
        if LiveActivityManager.shared.isRunning {
            LiveActivityManager.shared.update(activityState)
        } else {
            LiveActivityManager.shared.start(sessionLabel: selectedDay.name, colorHex: selectedDay.colorHex, initialState: activityState)
        }
    }

    /// Logs a completed set from a message sent by the watch app, against
    /// whichever exercise/set is currently next up.
    func logSetFromWatch(weightKg: Double, reps: Int) {
        guard isSessionActive, let current = currentIncompleteSet() else { return }
        updateWeight(exerciseId: current.exerciseId, setIndex: current.setIndex, weight: weightKg)
        updateReps(exerciseId: current.exerciseId, setIndex: current.setIndex, reps: reps)
        toggleSet(exerciseId: current.exerciseId, setIndex: current.setIndex)
    }

    // MARK: - Complete Session

    func completeSession(context: ModelContext) {
        let samples = HRSampleBuffer.shared.sessionSamples
        let interval = HRSampleBuffer.shared.sessionSamplingIntervalSeconds
        let report = SessionStrainCalculator.computeStrain(
                    hrSamples: samples,
                    intervalSeconds: interval,
                    maxHR: LiveHRManager.shared.maxHR,
                    restingHR: recoveryContext.restingHR ?? 60
                )

        let session = TrainingSession(
            sessionType: selectedDay.code,
            date: Date(),
            durationMinutes: sessionDurationMinutes,
            isCompleted: true,
            notes: "",
            isFlareDay: isFlareDay,
            hrSamples: samples.isEmpty ? nil : samples,
            hrSampleIntervalSeconds: interval,
            sessionPeakHR: report.peakHR,
            sessionAvgHR: report.avgHR,
            sessionTrimpScore: report.trimpScore > 0 ? report.trimpScore : nil,
            hrRecovery60: SessionStrainCalculator.hrRecovery60(samples: samples, intervalSeconds: interval)
        )
        context.insert(session)

        var orderIndex = 0
        for exercise in effectiveExercises {
            guard let state = exerciseStates[exercise.id] else { continue }
            let hasAnyCompleted = state.sets.contains { $0.isCompleted }
            guard hasAnyCompleted else { continue }

            let exerciseLog = ExerciseLog(
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                orderIndex: orderIndex,
                muscleGroup: exercise.muscleGroup
            )
            exerciseLog.note = state.note
            exerciseLog.cableAttachment = state.cableAttachment?.rawValue
            exerciseLog.cablePosition = state.cablePosition?.rawValue
            context.insert(exerciseLog)
            exerciseLog.session = session

            for setState in state.sets {
                let setLog = SetLog(
                    setNumber: setState.setNumber,
                    weightKg: setState.weightKg,
                    reps: setState.reps,
                    isCompleted: setState.isCompleted,
                    rpe: setState.rpe,
                    peakHR: setState.peakHR,
                    avgHR: setState.avgHR,
                    endHR: setState.endHR
                )
                context.insert(setLog)
                setLog.exercise = exerciseLog
            }

            orderIndex += 1
        }

        try? context.save()
        ActiveSessionStore.clear()

        completedSession = session
        showCompletionSheet = true
        isSessionActive = false
        if let profile = appStateRef?.profile {
            NotificationManager.shared.schedulePostWorkoutNutritionReminder(context: context, profile: profile)
        }
        appStateRef?.endSession()
        appStateRef = nil
        HRSampleBuffer.shared.stopSampling()
        HRSampleBuffer.shared.clearSessionSamples()
        WatchSessionManager.shared.pushSessionSnapshot(nil)
        LiveActivityManager.shared.end()
        FocusModeManager.shared.disableShield()
    }

    // MARK: - Session Persistence

    /// Creates a snapshot of the current session state for persistence.
    func createSessionSnapshot() -> ActiveSessionSnapshot? {
        guard isSessionActive, let start = sessionStartTime else { return nil }

        let exerciseSnapshots: [ActiveSessionSnapshot.ExerciseSnapshot] = effectiveExercises.compactMap { exercise in
            guard let state = exerciseStates[exercise.id] else { return nil }
            let setSnapshots = state.sets.map { s in
                ActiveSessionSnapshot.SetSnapshot(
                    setNumber: s.setNumber,
                    weightKg: s.weightKg,
                    reps: s.reps,
                    isCompleted: s.isCompleted,
                    isWarmup: s.isWarmup,
                    setTypeRaw: s.setType.rawValue,
                    rpe: s.rpe,
                    peakHR: s.peakHR,
                    avgHR: s.avgHR,
                    endHR: s.endHR
                )
            }
            return ActiveSessionSnapshot.ExerciseSnapshot(
                id: exercise.id,
                name: exercise.name,
                muscleGroup: exercise.muscleGroup,
                note: state.note,
                cableAttachment: state.cableAttachment?.rawValue,
                cablePosition: state.cablePosition?.rawValue,
                isExpanded: state.isExpanded,
                sets: setSnapshots
            )
        }

        return ActiveSessionSnapshot(
            sessionTypeCode: selectedDay.code,
            sessionLabel: selectedDay.name,
            startTime: start,
            pausedElapsed: pausedElapsed,
            isPaused: isSessionPaused,
            isSimpleMode: isSimpleMode,
            isFlareDay: isFlareDay,
            exercises: exerciseSnapshots
        )
    }

    /// Persists current session state to disk. Call on every meaningful
    /// change (set toggle, weight edit, rep edit, background).
    func persistSession() {
        guard let snapshot = createSessionSnapshot() else { return }
        ActiveSessionStore.save(snapshot)
    }

    /// Restores an active session from a persisted snapshot.
    /// Returns true if a session was restored.
    @discardableResult
    func restoreSession(appState: AppState, context: ModelContext) -> Bool {
        guard let snapshot = ActiveSessionStore.load() else { return false }

        // Verify the snapshot isn't stale (> 6 hours old)
        guard Date().timeIntervalSince(snapshot.startTime) < 6 * 3600 else {
            ActiveSessionStore.clear()
            return false
        }

        // Select the matching day
        if let matchingDay = availableDays.first(where: { $0.code == snapshot.sessionTypeCode }) {
            selectedDay = matchingDay
        }

        // Rebuild exercise list for this day
        effectiveExercises = CustomSessionStore.effectiveExercises(
            forCode: snapshot.sessionTypeCode,
            context: context
        )

        // Restore session state
        isSessionActive = true
        isSessionPaused = snapshot.isPaused
        isSimpleMode = snapshot.isSimpleMode
        sessionStartTime = snapshot.startTime
        pausedElapsed = snapshot.pausedElapsed
        isFlareDay = snapshot.isFlareDay
        appStateRef = appState

        // Rebuild exercise states from snapshot, matching by exercise ID
        exerciseStates = [:]
        let snapshotMap = Dictionary(uniqueKeysWithValues: snapshot.exercises.map { ($0.id, $0) })

        for exercise in effectiveExercises {
            if let saved = snapshotMap[exercise.id] {
                // Restore user-entered data from snapshot
                let sets = saved.sets.map { s in
                    SetState(
                        setNumber: s.setNumber,
                        weightKg: s.weightKg,
                        reps: s.reps,
                        isCompleted: s.isCompleted,
                        isWarmup: s.isWarmup,
                        setType: SetType(rawValue: s.setTypeRaw) ?? .working,
                        rpe: s.rpe,
                        peakHR: s.peakHR,
                        avgHR: s.avgHR,
                        endHR: s.endHR
                    )
                }
                exerciseStates[exercise.id] = ExerciseState(
                    id: exercise.id,
                    definition: exercise,
                    sets: sets,
                    isExpanded: saved.isExpanded,
                    note: saved.note,
                    cableAttachment: saved.cableAttachment.flatMap { CableAttachment(rawValue: $0) },
                    cablePosition: saved.cablePosition.flatMap { CablePosition(rawValue: $0) }
                )
            } else {
                // Exercise wasn't in the snapshot (program changed?) — use fresh state
                let suggested = suggestedWeight(for: exercise)
                let sets = (1...exercise.sets).map { i in
                    SetState(setNumber: i, weightKg: suggested, reps: exercise.repRange.max)
                }
                exerciseStates[exercise.id] = ExerciseState(
                    id: exercise.id,
                    definition: exercise,
                    sets: sets,
                    cableAttachment: CableAttachment.infer(from: exercise.name),
                    cablePosition: CablePosition.infer(from: exercise.name)
                )
            }
        }

        // Also restore exercises from snapshot that aren't in the program
        // (mid-session additions via addExerciseForToday)
        for saved in snapshot.exercises {
            guard !effectiveExercises.contains(where: { $0.id == saved.id }) else { continue }
            // Re-create the definition for mid-session additions
            let definition = ExerciseDefinition(
                id: saved.id,
                name: saved.name,
                type: .isolation,
                sets: saved.sets.count,
                repRange: .tenToTwelve,
                startWeightKg: saved.sets.first?.weightKg ?? 0,
                progressionNote: "Restored from saved session",
                isJointSensitive: false,
                specialProgressionRule: nil,
                alternativeExercise: nil,
                muscleGroup: saved.muscleGroup,
                gifURL: nil,
                alternativeGifURL: nil
            )
            effectiveExercises.append(definition)
            let sets = saved.sets.map { s in
                SetState(
                    setNumber: s.setNumber,
                    weightKg: s.weightKg,
                    reps: s.reps,
                    isCompleted: s.isCompleted,
                    isWarmup: s.isWarmup,
                    setType: SetType(rawValue: s.setTypeRaw) ?? .working,
                    rpe: s.rpe,
                    peakHR: s.peakHR,
                    avgHR: s.avgHR,
                    endHR: s.endHR
                )
            }
            exerciseStates[saved.id] = ExerciseState(
                id: saved.id,
                definition: definition,
                sets: sets,
                isExpanded: saved.isExpanded,
                note: saved.note,
                cableAttachment: saved.cableAttachment.flatMap { CableAttachment(rawValue: $0) },
                cablePosition: saved.cablePosition.flatMap { CablePosition(rawValue: $0) }
            )
        }

        // Sync AppState
        appState.startSession()
        appState.sessionStartTime = snapshot.startTime
        appState.isSessionPaused = snapshot.isPaused
        pushProgressToAppState()

        // Reconnect peripherals
        BLEHeartRateManager.shared.attemptAutoReconnect()
        if !snapshot.isPaused {
            HRSampleBuffer.shared.startSampling()
        }

        return true
    }
}
