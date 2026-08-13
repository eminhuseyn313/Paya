import SwiftUI
import AudioToolbox
import UserNotifications

// MARK: - Rest Timer Manager
// Singleton observable that drives the floating timer overlay.
// Any view can start/stop/skip the timer from anywhere in the app.

@MainActor
@Observable
class RestTimerManager {

    static let shared = RestTimerManager()

    var isActive: Bool = false
    var secondsRemaining: Int = 0
    var totalSeconds: Int = 0
    var exerciseName: String = ""
    var sessionColor: Color = .blue
    
    var peakBPM: Int? = nil

    private var tickTask: Task<Void, Never>?
    private var hasWarned: Bool = false
    private var hasFinished: Bool = false
    private var notificationScheduled: Bool = false

    private static let pendingNotificationId = "rest_timer_pending"

    // MARK: Start

    /// `profile` is optional so existing call sites keep working without
    /// changes — pass it to also schedule a local push for when rest ends,
    /// which matters if the app gets backgrounded mid-rest (the in-app
    /// countdown's Task.sleep loop isn't guaranteed to keep ticking once
    /// suspended, so this is the reliable fallback, not the primary path).
    func start(
        seconds: Int,
        exerciseName: String,
        sessionColor: Color,
        profile: UserProfile? = nil,
        exerciseId: String = ""
    ) {
        // Record rest from the previous timer before starting a new one
        if isActive && !currentExerciseId.isEmpty {
            recordRestDuration(exerciseId: currentExerciseId)
        }
        stop()
        self.totalSeconds = seconds
        self.secondsRemaining = seconds
        self.exerciseName = exerciseName
        self.sessionColor = sessionColor
        self.currentExerciseId = exerciseId
        self.isActive = true
        self.hasWarned = false
        self.hasFinished = false
        self.peakBPM = LiveHRManager.shared.currentBPM

        notificationScheduled = false
        if let profile, NotificationManager.shared.isCategoryEnabled(.restTimer, profile: profile) {
            notificationScheduled = true
            scheduleCompletionNotification(in: seconds, exerciseName: exerciseName)
        }

        // A structured Task loop instead of Timer — the closure is
        // @MainActor from creation, so there's no captured-self-in-
        // concurrently-executing-code warning under Swift 6 strict
        // concurrency the way a Timer's non-isolated callback produces.
        tickTask = Task { @MainActor [weak self] in
            while let self, self.isActive {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    private func scheduleCompletionNotification(in seconds: Int, exerciseName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Back to \(exerciseName) — next set is ready."
        content.sound = .default
        content.userInfo = ["destination": NotificationDestination.train.rawValue]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, Double(seconds)), repeats: false)
        let request = UNNotificationRequest(identifier: Self.pendingNotificationId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelPendingNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.pendingNotificationId])
    }

    // MARK: Tick

    private func tick() {
            if let current = LiveHRManager.shared.currentBPM {
                if let peak = peakBPM {
                    if current > peak { peakBPM = current }
                } else {
                    peakBPM = current
                }
            }

            guard secondsRemaining > 0 else {
                finish()
                return
            }
            secondsRemaining -= 1

        if secondsRemaining == 10 && !hasWarned {
            hasWarned = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        if secondsRemaining == 0 {
            finish()
        }
    }

    // MARK: Finish

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        // Record that the user took the full rest period
        if !currentExerciseId.isEmpty {
            recordRestDuration(exerciseId: currentExerciseId)
        }
        cancelPendingNotification()
        AudioServicesPlaySystemSound(1322)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let strong = UIImpactFeedbackGenerator(style: .heavy)
        strong.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { strong.impactOccurred() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { strong.impactOccurred() }
    }

    // MARK: Stop / Skip

    func stop() {
            tickTask?.cancel()
            tickTask = nil
            isActive = false
            secondsRemaining = 0
            totalSeconds = 0
            peakBPM = nil
            cancelPendingNotification()
        }

    func skip() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        // Record the rest the user actually took before skipping
        if !exerciseName.isEmpty {
            recordRestDuration(exerciseId: currentExerciseId)
        }
        stop()
    }

    /// The exercise ID currently being rested for — set on start.
    private(set) var currentExerciseId: String = ""

    // MARK: Adjust

    func add(_ delta: Int) {
        secondsRemaining = max(0, secondsRemaining + delta)
        totalSeconds = max(totalSeconds, secondsRemaining)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if notificationScheduled {
            cancelPendingNotification()
            scheduleCompletionNotification(in: secondsRemaining, exerciseName: exerciseName)
        }
    }

    // MARK: - Smart Rest Recommendation
    //
    // Evidence-based rest duration informed by:
    // - Schoenfeld et al. (2016): 3-min rest between sets produces
    //   greater hypertrophy and strength gains than 1-min rest.
    // - de Salles et al. (2009) meta-analysis: 2–5 min for compound
    //   multi-joint, 1–2 min for isolation single-joint.
    // - Grgic et al. (2017): longer rest = more volume = more gains;
    //   the rest period is a ceiling on performance recovery.
    //
    // The smart recommendation adjusts the base rest using:
    //   1. Previous session average rest for this specific exercise
    //      (what the user actually chose last time — the best signal)
    //   2. Current HR: if HR is still elevated (>75% of peak drop
    //      hasn't occurred), extend rest
    //   3. Set difficulty: heavier weight or higher RPE → more rest

    /// Tracks rest durations the user actually takes per exercise.
    /// Keyed by exercise ID → array of durations (seconds the timer ran
    /// before they skipped or it completed).
    private(set) var restHistory: [String: [Int]] = [:]

    /// Call when rest ends (skip or natural completion) to record what
    /// rest the user actually took for the exercise.
    func recordRestDuration(exerciseId: String) {
        let elapsed = totalSeconds - secondsRemaining
        guard elapsed > 5 else { return } // ignore accidental instant skips
        var history = restHistory[exerciseId] ?? []
        history.append(elapsed)
        if history.count > 10 { history.removeFirst() }
        restHistory[exerciseId] = history
    }

    /// Smart rest for this exercise based on history, HR, and effort.
    static func smartRest(
        for exercise: ExerciseDefinition,
        history: [Int]? = nil,
        currentHR: Int? = nil,
        peakHR: Int? = nil,
        lastSetRPE: Int = 0,
        lastSetWeightKg: Double = 0
    ) -> Int {
        // Base: exercise-type default
        var rest = defaultRest(for: exercise)

        // Override with user's own average if we have history
        if let history, !history.isEmpty {
            let avg = history.reduce(0, +) / history.count
            // Use their average but clamp within ±30s of base to
            // prevent wildly short/long values
            rest = min(rest + 30, max(rest - 30, avg))
        }

        // HR-based extension: if current HR > 70% of peak,
        // cardiovascular recovery hasn't caught up — add time
        if let current = currentHR, let peak = peakHR, peak > 100 {
            let recoveryPct = Double(peak - current) / Double(peak - 60)
            if recoveryPct < 0.5 {
                rest += 30   // still very elevated
            } else if recoveryPct < 0.7 {
                rest += 15   // partially recovered
            }
        }

        // RPE-based: RPE 9-10 → add rest for neural recovery
        if lastSetRPE >= 9 {
            rest += 30
        } else if lastSetRPE >= 8 {
            rest += 15
        }

        // Heavy set bonus (>80% of exercise start weight suggests
        // strength-biased work needing more recovery)
        if exercise.startWeightKg > 0 && lastSetWeightKg > exercise.startWeightKg * 1.3 {
            rest += 15
        }

        return min(300, max(30, rest)) // clamp 30s–5min
    }

    // MARK: Defaults (fallback when no smart data available)

    static func defaultRest(for exercise: ExerciseDefinition) -> Int {
        let mg = exercise.muscleGroup.lowercased()
        switch exercise.type {
        case .compound:
            let heavy = mg.contains("quad") || mg.contains("glute")
                || mg.contains("hamstring") || mg.contains("back")
            return heavy ? 180 : 120
        case .isolation:
            let small = mg.contains("bicep") || mg.contains("tricep")
                || mg.contains("forearm") || mg.contains("calf")
                || mg.contains("calves") || mg.contains("ab")
            return small ? 60 : 90
        }
    }
}

// MARK: - Rest Timer Floating Bar
//
// Redesigned for readability on all screen widths. The original layout
// crammed 6 elements into one HStack (icon, label, HR pill, −15s, +15s,
// dismiss), causing text truncation and hyphenation on smaller phones.
//
// New layout: two clean rows.
//   Row 1: large countdown + HR badge + dismiss
//   Row 2: adjust buttons + peak/now recovery info

struct RestTimerBar: View {

    @Bindable var manager: RestTimerManager
    var hr: LiveHRManager = .shared

    var progress: Double {
        guard manager.totalSeconds > 0 else { return 0 }
        return 1.0 - Double(manager.secondsRemaining) / Double(manager.totalSeconds)
    }

    var timeText: String {
        let mins = manager.secondsRemaining / 60
        let secs = manager.secondsRemaining % 60
        return mins > 0
            ? String(format: "%d:%02d", mins, secs)
            : "\(secs)s"
    }

    var displayColor: Color {
        if manager.secondsRemaining == 0 { return Color(hex: "059669") }
        if manager.secondsRemaining <= 10 { return Color(hex: "B45309") }
        return manager.sessionColor
    }

    var showHR: Bool { hr.currentBPM != nil }

    var recoveryDrop: Int? {
        guard let peak = manager.peakBPM,
              let current = hr.currentBPM,
              peak > current else { return nil }
        return peak - current
    }

    private var isComplete: Bool { manager.secondsRemaining == 0 }

    var body: some View {
        VStack(spacing: 0) {

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(displayColor.opacity(0.15))
                    Rectangle()
                        .fill(displayColor)
                        .frame(width: geo.size.width * progress)
                        .animation(.linear(duration: 1), value: progress)
                }
            }
            .frame(height: 4)
            .clipShape(RoundedRectangle(cornerRadius: 2))

            // Row 1: status + time + HR + dismiss
            HStack(spacing: 10) {

                // Icon
                ZStack {
                    Circle()
                        .fill(displayColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: isComplete ? "checkmark" : "timer")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(displayColor)
                }

                // Time — the star of the card, always readable
                VStack(alignment: .leading, spacing: 1) {
                    Text(isComplete ? "Ready for next set" : "Resting")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                    Text(isComplete ? "Go" : timeText)
                        .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(displayColor)
                        .lineLimit(1)
                        .fixedSize()
                }

                Spacer()

                // HR pill (compact)
                if showHR {
                    LiveHRPill(hr: hr)
                }

                // Dismiss
                Button {
                    manager.skip()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Skip rest")
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Row 2: adjust buttons + recovery info (only while counting)
            if manager.isActive && !isComplete {
                HStack(spacing: 8) {

                    // Adjust buttons — compact, clear
                    Button { manager.add(-15) } label: {
                        Label("−15", systemImage: "minus")
                            .labelStyle(.titleOnly)
                            .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundColor(.secondary)
                            .frame(width: 52, height: 32)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Button { manager.add(15) } label: {
                        Label("+15", systemImage: "plus")
                            .labelStyle(.titleOnly)
                            .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundColor(manager.sessionColor)
                            .frame(width: 52, height: 32)
                            .background(manager.sessionColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Spacer()

                    // Peak → Now recovery
                    if let peak = manager.peakBPM, let current = hr.currentBPM {
                        HStack(spacing: 6) {
                            Text("\(peak)")
                                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundColor(.secondary)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.6))
                            Text("\(current)")
                                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())

                            if let drop = recoveryDrop, drop > 0 {
                                Text("↓\(drop)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                                    .foregroundColor(Color(hex: "059669"))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(displayColor.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
        .padding(.horizontal, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
