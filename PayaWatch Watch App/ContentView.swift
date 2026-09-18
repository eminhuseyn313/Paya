import SwiftUI
import Combine
import WatchKit

struct ContentView: View {
    var body: some View {
        TabView {
            ReadinessGlanceView()
            SessionView()
            WaterView()
            BreathworkView()
            QuickCheckInView()
        }
        .tabViewStyle(.page)
        .onAppear {
            WatchConnectivityManager.shared.activate()
        }
    }
}

// MARK: - Crown-driven input target

private enum CrownTarget {
    case weight, reps
}

// MARK: - Session

struct SessionView: View {
    @State private var wc = WatchConnectivityManager.shared
    @State private var weightKg: Double = 20
    @State private var reps: Int = 10
    @State private var showEndConfirm = false
    @State private var crownTarget: CrownTarget = .weight
    @State private var crownProxy: Double = 20
    @State private var now: Date = .now

    var color: Color { Color(hex: wc.colorHex) }
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var crownRange: ClosedRange<Double> {
        crownTarget == .weight ? 0...400 : 1...Double(wc.isTimed ? 300 : 50)
    }
    private var crownStep: Double {
        crownTarget == .weight ? 1.25 : (wc.isTimed ? 5 : 1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if wc.sessionActive, let restEnd = wc.restEndDate, restEnd > now {
                    RestingView(wc: wc, now: now)
                } else if wc.justLoggedSet {
                    LoggedConfirmationView()
                } else if wc.sessionActive {
                    activeSessionContent
                } else {
                    IdleView()
                }
            }
            .padding(.horizontal, 6)
        }
        .background(WatchPulse.canvas)
        .digitalCrownRotation(
            $crownProxy,
            from: crownRange.lowerBound,
            through: crownRange.upperBound,
            by: crownStep,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownProxy) { _, newValue in
            if crownTarget == .weight {
                weightKg = newValue
            } else {
                reps = Int(newValue.rounded())
            }
        }
        .onChange(of: wc.suggestedWeightKg) { _, newValue in
            weightKg = newValue
            if crownTarget == .weight { crownProxy = newValue }
        }
        .onChange(of: wc.suggestedReps) { _, newValue in
            reps = newValue
            if crownTarget == .reps { crownProxy = Double(newValue) }
        }
        .onAppear {
            weightKg = wc.suggestedWeightKg
            reps = wc.suggestedReps
            crownProxy = weightKg
        }
        .confirmationDialog("End this workout?", isPresented: $showEndConfirm) {
            Button("End Workout", role: .destructive) {
                WKInterfaceDevice.current().play(.stop)
                wc.endSession()
            }
            Button("Cancel", role: .cancel) {}
        }
        .onReceive(ticker) { new in
            if wc.sessionActive, let restEnd = wc.restEndDate {
                let remaining = Int(restEnd.timeIntervalSince(new).rounded(.up))
                if remaining >= 0, remaining <= 3, remaining != Int(restEnd.timeIntervalSince(now).rounded(.up)) {
                    WKInterfaceDevice.current().play(remaining == 0 ? .success : .click)
                }
            }
            now = new
        }
    }

    @ViewBuilder
    private var activeSessionContent: some View {
        // Session header
        VStack(spacing: 2) {
            Text(wc.sessionLabel.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(WatchPulse.textTertiary)
                .tracking(0.5)
            if !wc.exerciseProgress.isEmpty {
                Text(wc.exerciseProgress)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
        }

        Text(wc.exerciseName)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(WatchPulse.textPrimary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.bottom, 2)

        // Set badge
        Text(wc.setLabel)
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())

        if wc.showsWeightField {
            CrownValueField(
                value: String(format: "%.1f", weightKg),
                unit: "kg",
                isActive: crownTarget == .weight,
                tint: color
            ) {
                crownTarget = .weight
                crownProxy = weightKg
                WKInterfaceDevice.current().play(.click)
            }
        }

        CrownValueField(
            value: "\(reps)",
            unit: wc.isTimed ? "sec" : "reps",
            isActive: crownTarget == .reps,
            tint: color
        ) {
            crownTarget = .reps
            crownProxy = Double(reps)
            WKInterfaceDevice.current().play(.click)
        }

        Button {
            WKInterfaceDevice.current().play(.success)
            wc.logSet(weightKg: weightKg, reps: reps)
        } label: {
            Text("Log Set")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .padding(.top, 2)

        if wc.lastLogFailed {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Not sent — phone unreachable")
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(WatchPulse.warning)
            .multilineTextAlignment(.center)
        }

        Button(role: .destructive) {
            showEndConfirm = true
        } label: {
            Text("End Workout")
                .font(.caption2)
        }
        .buttonStyle(.plain)
        .foregroundColor(WatchPulse.textTertiary)
        .padding(.top, 6)
    }
}

// MARK: - Crown value field

private struct CrownValueField: View {
    let value: String
    let unit: String
    let isActive: Bool
    let tint: Color
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(isActive ? tint : WatchPulse.textPrimary)
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(WatchPulse.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? tint.opacity(0.1) : WatchPulse.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? tint.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Idle (no session)

private struct IdleView: View {
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(WatchPulse.surface)
                    .frame(width: 56, height: 56)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 24))
                    .foregroundColor(WatchPulse.textTertiary)
            }
            Text("No active session")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(WatchPulse.textPrimary)
            Text("Start from your iPhone")
                .font(.system(size: 11))
                .foregroundColor(WatchPulse.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }
}

// MARK: - Just logged confirmation

private struct LoggedConfirmationView: View {
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(WatchPulse.positive.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(WatchPulse.positive)
            }
            Text("Set logged")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(WatchPulse.textPrimary)
            Text("Next set loading…")
                .font(.system(size: 11))
                .foregroundColor(WatchPulse.textSecondary)
        }
        .padding(.top, 12)
    }
}

// MARK: - Resting

struct RestingView: View {
    var wc: WatchConnectivityManager
    var now: Date

    private var remaining: Int {
        guard let end = wc.restEndDate else { return 0 }
        return max(0, Int(end.timeIntervalSince(now).rounded(.up)))
    }
    private var progress: Double {
        guard wc.restTotalSeconds > 0 else { return 0 }
        return 1.0 - Double(remaining) / Double(wc.restTotalSeconds)
    }

    var body: some View {
        VStack(spacing: 10) {
            Text("REST")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(WatchPulse.textTertiary)
                .tracking(1)

            ZStack {
                Circle()
                    .fill(WatchPulse.surface)
                Circle()
                    .stroke(Color(hex: wc.colorHex).opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color(hex: wc.colorHex),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                Text(remaining >= 60
                     ? String(format: "%d:%02d", remaining / 60, remaining % 60)
                     : "\(remaining)s")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(WatchPulse.textPrimary)
            }
            .frame(width: 94, height: 94)

            Text(wc.exerciseName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(WatchPulse.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)

            Button {
                WKInterfaceDevice.current().play(.click)
                wc.skipRest()
            } label: {
                Text("Skip")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(WatchPulse.textTertiary)
        }
        .padding(.top, 4)
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
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(WatchPulse.textPrimary)
                    Text("of \(wc.waterTargetMl)ml")
                        .font(.system(size: 9, weight: .medium))
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
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(WatchPulse.hydration)

                Button {
                    WKInterfaceDevice.current().play(.click)
                    wc.addWater(500)
                } label: {
                    Text("+500")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
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
