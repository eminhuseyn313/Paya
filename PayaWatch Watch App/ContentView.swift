import SwiftUI
import Combine
import WatchKit

// MARK: - Root

struct ContentView: View {
    @State private var workout = WorkoutManager.shared
    @State private var wc = WatchConnectivityManager.shared

    var body: some View {
        Group {
            if workout.isActive {
                ActiveWorkoutView()
            } else if let summary = workout.lastSummary {
                SummaryView(summary: summary)
            } else {
                TabView {
                    TodayView()
                    StartWorkoutView()
                    ReadinessGlanceView()
                    if !wc.meds.isEmpty { MedsView() }
                    WaterView()
                    QuickLogView()
                    BreathworkView()
                    QuickCheckInView()
                }
                // Digital Crown moves between screens (Apple's recommended
                // watchOS navigation); the active-workout pager stays
                // horizontal because the Crown edits weight/reps there.
                .tabViewStyle(.verticalPage)
            }
        }
        .background(WatchPulse.canvas)
        .overlay { if let msg = wc.flareAlertBanner { FlareAlertView(message: msg) } }
        .onChange(of: wc.flareAlertBanner) { _, msg in
            if msg != nil { WKInterfaceDevice.current().play(.notification) }
        }
        .onAppear {
            WatchConnectivityManager.shared.activate()
            WorkoutManager.shared.recoverIfNeeded()
        }
    }
}

// MARK: - Helpers

private func clock(_ t: TimeInterval) -> String {
    let s = max(0, Int(t))
    return s >= 3600
        ? String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        : String(format: "%d:%02d", s / 60, s % 60)
}

private func kindTint(for kind: WorkoutManager.Kind) -> Color {
    switch kind {
    case .strength: return WatchPulse.ai
    case .run: return WatchPulse.positive
    case .walk: return WatchPulse.hydration
    case .cycle: return WatchPulse.energy
    case .hiit: return WatchPulse.critical
    case .other: return WatchPulse.recovery
    }
}

/// HR zone from the user's max HR (same 50/60/70/80/90 % bands as the phone).
private func hrZone(_ bpm: Int?, maxHR: Int?) -> (n: Int, color: Color)? {
    guard let bpm, let maxHR, maxHR > 0 else { return nil }
    switch Double(bpm) / Double(maxHR) {
    case 0.90...: return (5, WatchPulse.critical)
    case 0.80..<0.90: return (4, Color(hex: "F97316"))
    case 0.70..<0.80: return (3, WatchPulse.warning)
    case 0.60..<0.70: return (2, WatchPulse.positive)
    case 0.50..<0.60: return (1, WatchPulse.hydration)
    default: return nil
    }
}

// MARK: - Today (briefing + flare)

private func flareColor(_ level: String) -> Color {
    switch level {
    case "low": return WatchPulse.positive
    case "moderate": return WatchPulse.warning
    case "elevated": return Color(hex: "F97316")
    case "high": return WatchPulse.critical
    default: return WatchPulse.textTertiary
    }
}

struct TodayView: View {
    @State private var wc = WatchConnectivityManager.shared
    @State private var offline = OfflineSessionManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY")
                    .font(.pulse(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(WatchPulse.textTertiary)
                    .tracking(1)

                if !wc.briefing.isEmpty {
                    Text(wc.briefing)
                        .font(.pulse(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(WatchPulse.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Your daily briefing appears here once Paya has today's data.")
                        .font(.pulse(size: 12))
                        .foregroundColor(WatchPulse.textSecondary)
                }

                if let score = wc.phoneReadinessScore {
                    chip("bolt.heart.fill", "Readiness \(score)\(wc.phoneReadinessBand.map { " · \($0)" } ?? "")", WatchPulse.recovery)
                    if let verdict = verdict(for: wc.phoneReadinessBand) {
                        Text(verdict)
                            .font(.pulse(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(WatchPulse.textPrimary)
                    }
                }
                if wc.sleepHours > 0 || wc.hrvMs > 0 || wc.restingHR > 0 {
                    HStack(spacing: 10) {
                        if wc.sleepHours > 0 { vital("moon.fill", String(format: "%.1fh", wc.sleepHours), "Sleep", WatchPulse.ai) }
                        if wc.hrvMs > 0 { vital("waveform.path.ecg", "\(Int(wc.hrvMs.rounded()))", "HRV ms", WatchPulse.recovery) }
                        if wc.restingHR > 0 { vital("heart.fill", "\(wc.restingHR)", "Rest HR", WatchPulse.vitals) }
                    }
                }
                if !wc.flareLevel.isEmpty {
                    chip("exclamationmark.triangle.fill",
                         "Flare risk: \(wc.flareLevel.capitalized)\(wc.flareWorsening ? " · rising" : "")",
                         flareColor(wc.flareLevel))
                }
                if offline.hasPlan {
                    chip("list.bullet.clipboard", "\(offline.dayName) · \(offline.plan.count) exercises", WatchPulse.ai)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
        }
    }

    /// A plain-language read of the readiness band — wording only, no new calculation.
    private func verdict(for band: String?) -> String? {
        switch band?.lowercased() {
        case "primed": return "Good day to push"
        case "steady": return "Train as planned"
        case "caution": return "Go a bit lighter"
        case "recover": return "Prioritise rest today"
        default: return nil
        }
    }

    private func vital(_ symbol: String, _ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Image(systemName: symbol).font(.system(size: 11)).foregroundColor(color)
            Text(value).font(.pulse(size: 15, weight: .bold, design: .rounded)).monospacedDigit()
            Text(label).font(.pulse(size: 9)).foregroundColor(WatchPulse.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func chip(_ symbol: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.pulse(size: 11, weight: .semibold))
            Text(text).font(.pulse(size: 12, weight: .semibold, design: .rounded)).lineLimit(2)
            Spacer(minLength: 0)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.16)))
    }
}

// MARK: - Pre-workout check (shown before a Paya session starts)

private struct PreWorkoutCheckView: View {
    @State private var wc = WatchConnectivityManager.shared
    let onStart: () -> Void

    private var headline: String {
        guard let score = wc.phoneReadinessScore else { return "No readiness score yet" }
        return "Readiness \(score)\(wc.phoneReadinessBand.map { " · \($0)" } ?? "")"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("BEFORE YOU START")
                    .font(.pulse(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(WatchPulse.textTertiary)
                    .tracking(1)
                Text(headline)
                    .font(.pulse(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(WatchPulse.textPrimary)

                if let rec = wc.phoneReadinessRecommendation, !rec.isEmpty {
                    Text(rec)
                        .font(.pulse(size: 12))
                        .foregroundColor(WatchPulse.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if wc.phoneReadinessScore == nil {
                    Text("Wear your watch overnight so Paya can score your recovery.")
                        .font(.pulse(size: 12))
                        .foregroundColor(WatchPulse.textSecondary)
                }

                if !wc.flareLevel.isEmpty {
                    HStack(spacing: 6) {
                        Circle().fill(flareColor(wc.flareLevel)).frame(width: 8, height: 8)
                        Text("Flare risk \(wc.flareLevel)\(wc.flareWorsening ? " · rising" : "")")
                            .font(.pulse(size: 12, weight: .semibold))
                            .foregroundColor(WatchPulse.textPrimary)
                    }
                }

                Button(action: onStart) {
                    Text("Start workout")
                        .font(.pulse(size: 15, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchPulse.recovery)
            }
            .padding(.horizontal, 6)
        }
    }
}

// MARK: - Flare early-warning banner

private struct FlareAlertView: View {
    @State private var wc = WatchConnectivityManager.shared
    let message: String

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.pulse(size: 22))
                    .foregroundColor(WatchPulse.warning)
                Text("Flare risk rising")
                    .font(.pulse(size: 15, weight: .bold, design: .rounded))
                Text(message)
                    .font(.pulse(size: 11))
                    .foregroundColor(WatchPulse.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Log a symptom") { wc.logSymptomFromAlert() }
                    .buttonStyle(.borderedProminent)
                    .tint(WatchPulse.warning)
                Button("Dismiss") { wc.flareAlertBanner = nil }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 6)
        }
        .background(WatchPulse.canvas)
    }
}

// MARK: - Quick log (weight + saved meals)

struct QuickLogView: View {
    @State private var wc = WatchConnectivityManager.shared
    @State private var weight: Double = 70
    @State private var weightSent = false
    @State private var loggedMeal: String?

    private var lbs: Bool { wc.prefersLbs }

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("QUICK LOG")
                    .font(.pulse(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(WatchPulse.textTertiary)
                    .tracking(1)

                // Weight — turn the Crown, then Save.
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(String(format: "%.1f", weight))
                            .font(.pulse(size: 26, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text(lbs ? "lb" : "kg").font(.pulse(size: 11)).foregroundColor(WatchPulse.textSecondary)
                    }
                    Button {
                        WKInterfaceDevice.current().play(.success)
                        wc.logWeight(kg: lbs ? weight / 2.20462262 : weight)
                        weightSent = true
                        Task { try? await Task.sleep(for: .seconds(2)); weightSent = false }
                    } label: {
                        Text(weightSent ? "✓ Saved" : "Save weight")
                            .font(.pulse(size: 13, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(weightSent ? WatchPulse.positive : WatchPulse.recovery)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(WatchPulse.surface))
                .focusable()
                .digitalCrownRotation($weight, from: lbs ? 60 : 30, through: lbs ? 660 : 300, by: 0.1,
                                      sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
                .onAppear {
                    // Start from your last recorded weight, not a made-up number.
                    if wc.latestWeightKg > 0 { weight = (wc.latestWeightKg * (lbs ? 2.20462262 : 1) * 10).rounded() / 10 }
                }

                if wc.quickMeals.isEmpty {
                    Text("Save meals in Paya → Nutrition → Quick meals to log them here in one tap.")
                        .font(.pulse(size: 10))
                        .foregroundColor(WatchPulse.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    ForEach(wc.quickMeals) { meal in
                        Button {
                            WKInterfaceDevice.current().play(.success)
                            wc.logMeal(meal.id)
                            loggedMeal = meal.id
                            Task { try? await Task.sleep(for: .seconds(2)); loggedMeal = nil }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(meal.name).font(.pulse(size: 13, weight: .semibold, design: .rounded)).lineLimit(1)
                                    Text("\(meal.kcal) kcal · \(meal.protein) g protein")
                                        .font(.pulse(size: 10)).foregroundColor(WatchPulse.textSecondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: loggedMeal == meal.id ? "checkmark.circle.fill" : "plus.circle.fill")
                                    .foregroundColor(loggedMeal == meal.id ? WatchPulse.positive : WatchPulse.energy)
                            }
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(RoundedRectangle(cornerRadius: 12).fill(WatchPulse.surface))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Medications (due today)

struct MedsView: View {
    @State private var wc = WatchConnectivityManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("MEDICATIONS")
                    .font(.pulse(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(WatchPulse.textTertiary)
                    .tracking(1)
                ForEach(wc.meds) { med in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(med.name)
                                .font(.pulse(size: 13, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                            if !med.dose.isEmpty {
                                Text(med.dose).font(.pulse(size: 10)).foregroundColor(WatchPulse.textSecondary).lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                        if med.taken {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(WatchPulse.positive)
                        } else {
                            Button("Taken") {
                                WKInterfaceDevice.current().play(.success)
                                wc.markMedTaken(med.id)
                            }
                            .font(.pulse(size: 12, weight: .bold, design: .rounded))
                            .buttonStyle(.borderedProminent)
                            .tint(WatchPulse.hydration)
                            .frame(width: 74)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(WatchPulse.surface))
                }
                Text("Logs to Paya. Follow your prescriber's instructions.")
                    .font(.pulse(size: 9))
                    .foregroundColor(WatchPulse.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Start (idle)

private enum PendingStart: String, Identifiable { case phone, offline; var id: String { rawValue } }

struct StartWorkoutView: View {
    @State private var pendingStart: PendingStart?
    @State private var offline = OfflineSessionManager.shared
    @State private var wc = WatchConnectivityManager.shared
    @State private var workout = WorkoutManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("WORKOUT")
                    .font(.pulse(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(WatchPulse.textTertiary)
                    .tracking(1)

                StartRow(symbol: "list.bullet.clipboard.fill",
                         title: "Today's session",
                         subtitle: sessionSubtitle,
                         tint: WatchPulse.recovery) {
                    pendingStart = .phone
                }

                if let rec = offline.recoverable, !workout.isActive {
                    StartRow(symbol: "arrow.triangle.2.circlepath",
                             title: "Unfinished workout",
                             subtitle: "\(rec.logged.count) sets · tap to save to iPhone",
                             tint: WatchPulse.warning) {
                        WKInterfaceDevice.current().play(.success)
                        offline.saveRecoverableToPhone()
                    }
                    StartRow(symbol: "trash", title: "Discard it", subtitle: nil, tint: WatchPulse.critical) {
                        offline.discardRecoverable()
                    }
                }

                if offline.hasPlan {
                    StartRow(symbol: "iphone.slash",
                             title: "Plan · no phone",
                             subtitle: "\(offline.dayName) · \(offline.plan.count) exercises",
                             tint: WatchPulse.positive) {
                        pendingStart = .offline
                    }
                }

                ForEach(WorkoutManager.Kind.allCases) { kind in
                    StartRow(symbol: kind.symbol, title: kind.title, subtitle: nil, tint: kindTint(for: kind)) {
                        WKInterfaceDevice.current().play(.start)
                        workout.start(kind, linked: false)
                    }
                }

                if let err = workout.errorMessage {
                    Text(err)
                        .font(.pulse(size: 10, weight: .medium))
                        .foregroundColor(WatchPulse.warning)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 4)
        }
        .onAppear { wc.startResult = .idle }
        .sheet(item: $pendingStart) { mode in
            PreWorkoutCheckView {
                pendingStart = nil
                WKInterfaceDevice.current().play(.start)
                if mode == .phone { wc.requestStartSession() } else { offline.start() }
            }
        }
    }

    private var sessionSubtitle: String {
        switch wc.startResult {
        case .idle: return "Log sets with your iPhone"
        case .starting: return "Starting…"
        case .started: return "Started"
        case .needsPhone: return "Open Paya on iPhone → Train"
        }
    }
}

private struct StartRow: View {
    let symbol: String
    let title: String
    let subtitle: String?
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(tint.opacity(0.22))
                    Image(systemName: symbol)
                        .font(.pulse(size: 15, weight: .semibold))
                        .foregroundColor(tint)
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.pulse(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(WatchPulse.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.pulse(size: 10))
                            .foregroundColor(WatchPulse.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 14).fill(WatchPulse.surface))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Active workout (pager: Controls | Metrics | Log)

struct ActiveWorkoutView: View {
    @State private var wc = WatchConnectivityManager.shared
    @State private var page = 1

    var body: some View {
        TabView(selection: $page) {
            ControlsPage().tag(0)
            MetricsPage().tag(1)
            if wc.sessionActive {
                LogSetPage().tag(2)
            }
        }
        .tabViewStyle(.page)
        .onAppear { page = wc.sessionActive ? 2 : 1 }
        .onChange(of: wc.sessionActive) { _, active in page = active ? 2 : 1 }
    }
}

// MARK: Controls

private struct ControlsPage: View {
    @State private var workout = WorkoutManager.shared
    @State private var wc = WatchConnectivityManager.shared
    @State private var confirmEnd = false

    @State private var detector = MotionSetDetector.shared
    @State private var showNote = false
    @State private var noteText = ""

    var body: some View {
        ScrollView {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                control(symbol: "xmark", label: "End", color: WatchPulse.critical) {
                    confirmEnd = true
                }
                control(symbol: workout.isPaused ? "play.fill" : "pause.fill",
                        label: workout.isPaused ? "Resume" : "Pause",
                        color: WatchPulse.warning) {
                    workout.isPaused ? workout.resume() : workout.pause()
                    WKInterfaceDevice.current().play(.click)
                }
            }
            Text(workout.kind.title + (workout.linkedToPhone ? " · synced with iPhone" : (OfflineSessionManager.shared.isActive ? " · saves to iPhone later" : "")))
                .font(.pulse(size: 10, weight: .medium))
                .foregroundColor(WatchPulse.textSecondary)

            if workout.linkedToPhone || OfflineSessionManager.shared.isActive {
                if wc.flareEnabled && !OfflineSessionManager.shared.isActive {
                    PillToggle(symbol: "exclamationmark.triangle.fill",
                               title: "Light day",
                               isOn: wc.isFlareDay,
                               tint: WatchPulse.warning) {
                        wc.setFlareDay(!wc.isFlareDay)
                    }
                }
                if wc.sessionActive && wc.showsWeightField && !OfflineSessionManager.shared.isActive {
                    PillButton(symbol: "flame.fill", title: "Add warm-up sets", tint: WatchPulse.energy) {
                        WKInterfaceDevice.current().play(.click)
                        wc.requestWarmups()
                    }
                }
                if wc.sessionActive && !OfflineSessionManager.shared.isActive {
                    PillButton(symbol: "mic.fill", title: "Add note", tint: WatchPulse.hydration) {
                        noteText = ""
                        showNote = true
                    }
                }
                PillButton(symbol: "metronome.fill",
                           title: detector.tempoSeconds == 0 ? "Tempo taps · off" : "Tempo taps · \(detector.tempoSeconds) s",
                           tint: WatchPulse.positive) {
                    let order = [0, 2, 3, 4]
                    let i = order.firstIndex(of: detector.tempoSeconds) ?? 0
                    detector.tempoSeconds = order[(i + 1) % order.count]
                    WKInterfaceDevice.current().play(.click)
                }
                PillToggle(symbol: "waveform.path",
                           title: "Auto sets · beta",
                           isOn: detector.enabled,
                           tint: WatchPulse.ai) {
                    detector.enabled.toggle()
                    if detector.enabled { detector.start() }
                }
            }
        }
        .padding(.horizontal, 6)
        }
        .sheet(isPresented: $showNote) {
            VStack(spacing: 8) {
                Text("Note for \(wc.exerciseName)")
                    .font(.pulse(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                TextField("Dictate or write…", text: $noteText)
                Button("Save note") {
                    let t = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !t.isEmpty { wc.sendNote(t) }
                    showNote = false
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchPulse.hydration)
            }
            .padding(.horizontal, 6)
        }
        .confirmationDialog("End workout?", isPresented: $confirmEnd) {
            Button("End & Save", role: .destructive) {
                WKInterfaceDevice.current().play(.stop)
                if workout.linkedToPhone || OfflineSessionManager.shared.isActive { wc.endSession() } else { workout.end() }
            }
            Button("Keep Going", role: .cancel) {}
        }
    }

    private func controlPlaceholder() {}

    private func control(symbol: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            Button(action: action) {
                Image(systemName: symbol)
                    .font(.pulse(size: 22, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 62, height: 62)
                    .background(Circle().fill(color.opacity(0.22)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            Text(label)
                .font(.pulse(size: 11, weight: .semibold))
                .foregroundColor(WatchPulse.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PillButton: View {
    let symbol: String
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.pulse(size: 12, weight: .semibold))
                Text(title).font(.pulse(size: 12, weight: .semibold, design: .rounded)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }
}

private struct PillToggle: View {
    let symbol: String
    let title: String
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.pulse(size: 12, weight: .semibold))
                Text(title).font(.pulse(size: 12, weight: .semibold, design: .rounded)).lineLimit(1)
                Spacer(minLength: 0)
                Text(isOn ? "ON" : "OFF")
                    .font(.pulse(size: 10, weight: .black, design: .rounded))
            }
            .foregroundColor(isOn ? tint : WatchPulse.textSecondary)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(RoundedRectangle(cornerRadius: 12).fill(isOn ? tint.opacity(0.2) : WatchPulse.surface))
        }
        .buttonStyle(.plain)
    }
}

// MARK: Metrics

private struct MetricsPage: View {
    @State private var workout = WorkoutManager.shared
    @State private var wc = WatchConnectivityManager.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: workout.kind.symbol)
                        .font(.pulse(size: 10, weight: .semibold))
                    Text(workout.isPaused ? "PAUSED" : workout.kind.title.uppercased())
                        .font(.pulse(size: 10, weight: .black, design: .rounded))
                        .tracking(0.8)
                }
                .foregroundColor(workout.isPaused ? WatchPulse.warning : WatchPulse.textTertiary)

                Text(clock(workout.elapsedNow))
                    .font(.pulse(size: 38, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(WatchPulse.warning)

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(workout.heartRate.map(String.init) ?? "--")
                        .font(.pulse(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Text("BPM")
                        .font(.pulse(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(WatchPulse.textSecondary)
                    Image(systemName: "heart.fill")
                        .font(.pulse(size: 12))
                        .foregroundColor(WatchPulse.vitals)
                    if let z = hrZone(workout.heartRate, maxHR: wc.maxHR) {
                        Text("Z\(z.n)")
                            .font(.pulse(size: 11, weight: .black, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(z.color.opacity(0.25)))
                            .foregroundColor(z.color)
                    }
                }
                .foregroundColor(WatchPulse.textPrimary)

                metric(Int(workout.activeKcal.rounded()), "ACTIVE CAL")
                metric(Int(workout.totalKcal.rounded()), "TOTAL CAL")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
        }
    }

    private func metric(_ value: Int, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(value)")
                .font(.pulse(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(WatchPulse.textPrimary)
            Text(label)
                .font(.pulse(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(WatchPulse.energy)
        }
    }
}

// MARK: Log set (phone-linked strength session)

private enum CrownTarget { case weight, reps }

private struct LogSetPage: View {
    @State private var wc = WatchConnectivityManager.shared
    @State private var workout = WorkoutManager.shared
    @State private var detector = MotionSetDetector.shared
    @State private var weight: Double = 20   // in the user's display unit (kg or lb)
    @State private var reps: Int = 10
    @State private var crownTarget: CrownTarget = .weight
    @State private var crownProxy: Double = 20
    @State private var now: Date = .now
    @State private var hrCued = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var color: Color { Color(hex: wc.colorHex) }
    private var isResting: Bool {
        if let end = wc.restEndDate { return end > now }
        return false
    }
    /// "Set 4 of 4" → true. Gets a different haptic when it appears.
    private var isLastSet: Bool {
        let parts = wc.setLabel.components(separatedBy: " ")
        guard parts.count >= 4, let n = Int(parts[1]), let total = Int(parts[3]) else { return false }
        return total > 1 && n == total
    }
    private var lbs: Bool { wc.prefersLbs }
    private var factor: Double { lbs ? 2.20462262 : 1 }
    private var unitLabel: String { lbs ? "lb" : "kg" }
    private var weightMax: Double { lbs ? 900 : 400 }
    private var weightButtonStep: Double { lbs ? 5 : 2.5 }
    private func toDisplay(_ kg: Double) -> Double {
        let step = lbs ? 2.5 : 1.25
        return (kg * factor / step).rounded() * step
    }
    private func fmt(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", v)
            : String(format: "%.2f", v).replacingOccurrences(of: "0$", with: "", options: .regularExpression)
    }
    private var lastHint: String? {
        guard let r = wc.previousReps else { return nil }
        if wc.showsWeightField, let w = wc.previousWeightKg, w > 0 {
            return "last \(fmt(toDisplay(w)))×\(r)"
        }
        return "last \(r)\(wc.isTimed ? "s" : " reps")"
    }
    private var crownRange: ClosedRange<Double> {
        crownTarget == .weight ? 0...weightMax : (wc.isTimed ? 5...300 : 1...50)
    }
    private var crownStep: Double {
        crownTarget == .weight ? (lbs ? 2.5 : 1.25) : (wc.isTimed ? 5 : 1)
    }

    var body: some View {
        Group {
            if isResting {
                RestingView(wc: wc, now: now, heartRate: workout.heartRate, restStartPeak: workout.restStartPeak, hrReady: hrCued)
            } else {
                logContent
            }
        }
        .padding(.horizontal, 6)
        .onReceive(ticker) { new in
            if let end = wc.restEndDate {
                let remaining = Int(end.timeIntervalSince(new).rounded(.up))
                if remaining >= 0, remaining <= 3, remaining != Int(end.timeIntervalSince(now).rounded(.up)) {
                    WKInterfaceDevice.current().play(remaining == 0 ? .success : .click)
                }
            }
            // Smart rest cue: one buzz when HR has recovered (after ≥30 s of rest).
            if let end = wc.restEndDate, end > new, wc.restTotalSeconds > 0 {
                let elapsed = wc.restTotalSeconds - Int(end.timeIntervalSince(new).rounded(.up))
                if elapsed >= 30, workout.isHRRecovered, !hrCued {
                    hrCued = true
                    WKInterfaceDevice.current().play(.directionUp)
                }
            } else {
                hrCued = false
            }
            now = new
        }
        .onAppear {
            weight = toDisplay(wc.suggestedWeightKg)
            reps = wc.suggestedReps
            crownProxy = crownTarget == .weight ? weight : Double(reps)
            detector.suspended = isResting
            detector.start()
        }
        .onChange(of: wc.setLabel) { _, _ in
            if isLastSet { WKInterfaceDevice.current().play(.directionUp) }   // heads-up: final set
        }
        .onChange(of: wc.prBanner) { _, text in
            guard text != nil else { return }
            WKInterfaceDevice.current().play(.success)
            Task {
                try? await Task.sleep(for: .seconds(4))
                wc.prBanner = nil
            }
        }
        .overlay(alignment: .top) {
            if let pr = wc.prBanner {
                Text("🏆 New PR · \(pr)")
                    .font(.pulse(size: 11, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(WatchPulse.warning))
                    .foregroundColor(.black)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35), value: wc.prBanner)
        .onChange(of: isResting) { _, resting in
            detector.suspended = resting
            if !resting { detector.consume() }
        }
        .onChange(of: detector.detectedReps) { _, detected in
            guard let detected else { return }
            reps = min(wc.isTimed ? 300 : 50, max(1, detected + wc.repOffset))
            if crownTarget == .reps { crownProxy = Double(reps) }
        }
        .onChange(of: wc.suggestedWeightKg) { _, v in
            weight = toDisplay(v)
            if crownTarget == .weight { crownProxy = weight }
        }
        .onChange(of: wc.suggestedReps) { _, v in
            reps = v
            if crownTarget == .reps { crownProxy = Double(v) }
        }
    }

    private var logContent: some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                Text(wc.setLabel.replacingOccurrences(of: " of ", with: "/")
                     + (detector.detectedReps.map { " · ≈\(max(1, $0 + wc.repOffset)) detected" } ?? lastHint.map { " · \($0)" } ?? ""))
                    .font(.pulse(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Image(systemName: "heart.fill")
                    .font(.pulse(size: 9))
                    .foregroundColor(hrZone(workout.heartRate, maxHR: wc.maxHR)?.color ?? WatchPulse.vitals)
                Text(workout.heartRate.map(String.init) ?? "--")
                    .font(.pulse(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(hrZone(workout.heartRate, maxHR: wc.maxHR)?.color ?? WatchPulse.textPrimary)
            }

            Text(wc.exerciseName)
                .font(.pulse(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(WatchPulse.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if isLastSet {
                Text("LAST SET")
                    .font(.pulse(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(WatchPulse.warning)
            }

            if wc.adjustPct != 0 && wc.showsWeightField {
                Text(wc.adjustPct < 0 ? "↓ \(abs(wc.adjustPct))% for recovery" : "↑ \(wc.adjustPct)% progression")
                    .font(.pulse(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(wc.adjustPct < 0 ? WatchPulse.warning : WatchPulse.positive)
            }

            if wc.showsWeightField {
                StepperRow(
                    value: fmt(weight),
                    unit: unitLabel,
                    isActive: crownTarget == .weight,
                    tint: color,
                    onSelect: { select(.weight) },
                    onMinus: { weight = max(0, weight - weightButtonStep); crownProxy = weight; select(.weight) },
                    onPlus: { weight = min(weightMax, weight + weightButtonStep); crownProxy = weight; select(.weight) }
                )
            }

            StepperRow(
                value: "\(reps)",
                unit: wc.isTimed ? "sec" : "reps",
                isActive: crownTarget == .reps,
                tint: color,
                onSelect: { select(.reps) },
                onMinus: { reps = max(1, reps - (wc.isTimed ? 5 : 1)); crownProxy = Double(reps); select(.reps) },
                onPlus: { reps = min(wc.isTimed ? 300 : 50, reps + (wc.isTimed ? 5 : 1)); crownProxy = Double(reps); select(.reps) }
            )

            Button {
                WKInterfaceDevice.current().play(.success)
                let recovery = workout.currentRecovery
                workout.markSetEnd()
                wc.logSet(weightKg: (weight / factor * 100).rounded() / 100, reps: reps,
                          detected: detector.detectedReps, hrRecovery: recovery)
                detector.consume()
            } label: {
                Text(wc.justLoggedSet ? "✓ Logged" : "Log Set")
                    .font(.pulse(size: 15, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.borderedProminent)
            .tint(wc.justLoggedSet ? WatchPulse.positive : color)

            if wc.lastLogFailed {
                Text("Saved on watch — syncs when iPhone is near")
                    .font(.pulse(size: 9, weight: .semibold))
                    .foregroundColor(WatchPulse.warning)
                    .multilineTextAlignment(.center)
            }
        }
        .focusable()
        .digitalCrownRotation(
            $crownProxy,
            from: crownRange.lowerBound,
            through: crownRange.upperBound,
            by: crownStep,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownProxy) { _, v in
            if crownTarget == .weight { weight = v } else { reps = Int(v.rounded()) }
        }
    }

    private func select(_ t: CrownTarget) {
        if crownTarget != t {
            crownTarget = t
            crownProxy = t == .weight ? weight : Double(reps)
        }
        WKInterfaceDevice.current().play(.click)
    }
}

private struct StepperRow: View {
    let value: String
    let unit: String
    let isActive: Bool
    let tint: Color
    let onSelect: () -> Void
    let onMinus: () -> Void
    let onPlus: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            roundButton("minus", action: onMinus)
            Button(action: onSelect) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.pulse(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(isActive ? tint : WatchPulse.textPrimary)
                        .minimumScaleFactor(0.6)
                    Text(unit)
                        .font(.pulse(size: 10, weight: .medium))
                        .foregroundColor(WatchPulse.textTertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isActive ? tint.opacity(0.14) : WatchPulse.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isActive ? tint.opacity(0.5) : .clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            roundButton("plus", action: onPlus)
        }
    }

    private func roundButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.pulse(size: 13, weight: .bold))
                .foregroundColor(WatchPulse.textPrimary)
                .frame(width: 38, height: 40)
                .background(RoundedRectangle(cornerRadius: 10).fill(WatchPulse.surfaceElevated))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "plus" ? "Increase" : "Decrease")
    }
}

// MARK: - Resting

struct RestingView: View {
    var wc: WatchConnectivityManager
    var now: Date
    var heartRate: Int? = nil
    var restStartPeak: Int? = nil
    var hrReady: Bool = false

    private var recovery: Int? {
        guard let peak = restStartPeak, let hr = heartRate, peak > hr else { return nil }
        return peak - hr
    }

    private var remaining: Int {
        guard let end = wc.restEndDate else { return 0 }
        return max(0, Int(end.timeIntervalSince(now).rounded(.up)))
    }
    private var progress: Double {
        guard wc.restTotalSeconds > 0 else { return 0 }
        return 1.0 - Double(remaining) / Double(wc.restTotalSeconds)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("REST")
                    .font(.pulse(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(WatchPulse.textTertiary)
                    .tracking(1)
                Spacer()
                Image(systemName: "heart.fill")
                    .font(.pulse(size: 9))
                    .foregroundColor(WatchPulse.vitals)
                Text(heartRate.map(String.init) ?? "--")
                    .font(.pulse(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            ZStack {
                Circle().stroke(Color(hex: wc.colorHex).opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color(hex: wc.colorHex), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                VStack(spacing: 0) {
                Text(remaining >= 60
                     ? String(format: "%d:%02d", remaining / 60, remaining % 60)
                     : "\(remaining)s")
                    .font(.pulse(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(WatchPulse.textPrimary)
                if let drop = recovery {
                    Text("↓\(drop) bpm")
                        .font(.pulse(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(WatchPulse.positive)
                }
                }
            }
            .frame(width: 92, height: 92)

            Button {
                WKInterfaceDevice.current().play(.click)
                wc.skipRest()
            } label: {
                Text("Skip Rest")
                    .font(.pulse(size: 13, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(WatchPulse.textSecondary)

            if hrReady {
                Text("HR recovered · ready")
                    .font(.pulse(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(WatchPulse.positive)
            }
        }
    }
}

// MARK: - Summary

private struct SummaryView: View {
    let summary: WorkoutManager.Summary
    @State private var workout = WorkoutManager.shared
    @State private var wc = WatchConnectivityManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: summary.kind.symbol)
                        .foregroundColor(kindTint(for: summary.kind))
                    Text("Workout complete")
                        .font(.pulse(size: 14, weight: .bold, design: .rounded))
                }
                row(clock(summary.duration), "TIME", WatchPulse.warning)
                if let sets = summary.sets {
                    row("\(sets)", "SETS", WatchPulse.ai)
                }
                if let kg = summary.volumeKg {
                    let lbs = WatchConnectivityManager.shared.prefersLbs
                    row(String(format: "%.0f", kg * (lbs ? 2.20462262 : 1)), lbs ? "LB LIFTED" : "KG LIFTED", WatchPulse.ai)
                }
                row(summary.avgHeartRate.map(String.init) ?? "--", "AVG BPM", WatchPulse.vitals)
                row("\(summary.activeKcal)", "ACTIVE CAL", WatchPulse.energy)
                row("\(summary.totalKcal)", "TOTAL CAL", WatchPulse.energy)
                Text("Saved to Apple Health")
                    .font(.pulse(size: 10))
                    .foregroundColor(WatchPulse.textTertiary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("RECOVERY")
                        .font(.pulse(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(WatchPulse.textTertiary)
                        .tracking(1)
                    if wc.postWorkoutProteinG > 0 {
                        Text("≈\(wc.postWorkoutProteinG) g protein in your next meal")
                            .font(.pulse(size: 12, weight: .semibold, design: .rounded))
                        Text("About 0.3 g per kg of body weight, within the 0.25–0.4 range studies support.")
                            .font(.pulse(size: 9))
                            .foregroundColor(WatchPulse.textTertiary)
                    }
                    Button {
                        WKInterfaceDevice.current().play(.success)
                        wc.addWater(500)
                    } label: {
                        Text("+500 ml water")
                            .font(.pulse(size: 13, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(WatchPulse.hydration)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(WatchPulse.surface))
                Button("Done") { workout.dismissSummary() }
                    .buttonStyle(.borderedProminent)
                    .tint(WatchPulse.recovery)
            }
            .padding(.horizontal, 8)
        }
    }

    private func row(_ value: String, _ label: String, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.pulse(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.pulse(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }
}

// MARK: - Water

struct WaterView: View {
    @State private var wc = WatchConnectivityManager.shared

    var progress: Double {
        guard wc.waterTargetMl > 0 else { return 0 }
        return min(1.0, Double(wc.waterMl) / Double(wc.waterTargetMl))
    }

    private var stateColor: Color {
        if progress >= 0.8 { return WatchPulse.positive }
        if progress >= 0.5 { return WatchPulse.hydration }
        return WatchPulse.warning
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(WatchPulse.surface)
                Circle()
                    .stroke(stateColor.opacity(0.15), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(stateColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.4), value: progress)
                VStack(spacing: 0) {
                    Text("\(wc.waterMl)")
                        .font(.pulse(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(WatchPulse.textPrimary)
                    Text("of \(wc.waterTargetMl)ml")
                        .font(.pulse(size: 9, weight: .medium))
                        .foregroundColor(WatchPulse.textSecondary)
                }
            }
            .frame(width: 88, height: 88)

            HStack(spacing: 8) {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    wc.addWater(250)
                } label: {
                    Text("+250")
                        .font(.pulse(size: 13, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(WatchPulse.hydration)

                Button {
                    WKInterfaceDevice.current().play(.click)
                    wc.addWater(500)
                } label: {
                    Text("+500")
                        .font(.pulse(size: 13, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchPulse.hydration)
            }
        }
        .padding(.top, 4)
        .background(WatchPulse.canvas)
    }
}

#Preview {
    ContentView()
}
