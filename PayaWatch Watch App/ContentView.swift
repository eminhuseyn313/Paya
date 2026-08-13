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
// The Digital Crown is the one input watchOS users actually reach for
// mid-set — it replaces the pair of cramped +/- steppers the old layout
// used, which were genuinely hard to hit accurately with sweaty/moving
// fingers. Tapping the weight or rep number makes it the crown's target;
// the active one gets a colored ring so it's obvious which value turning
// the crown will change.

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
    // Ticks once a second so the view re-checks `wc.isResting` on its own —
    // without this, once the rest countdown hit 0 the view would stay
    // frozen on the resting screen until some unrelated WCSession update
    // happened to arrive and force a re-render.
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
            // Haptic pulse for the final 3 seconds of rest — the ring alone
            // is easy to miss at a glance; a countdown you can feel doesn't
            // need to be looked at.
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
        VStack(spacing: 2) {
            Text(wc.sessionLabel.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            if !wc.exerciseProgress.isEmpty {
                Text(wc.exerciseProgress)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color)
            }
        }

        Text(wc.exerciseName)
            .font(.system(size: 15, weight: .bold))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.bottom, 2)

        Text(wc.setLabel)
            .font(.caption2.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
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
                .font(.headline)
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
            .foregroundColor(Color(hex: "D97706"))
            .multilineTextAlignment(.center)
        }

        Button(role: .destructive) {
            showEndConfirm = true
        } label: {
            Text("End Workout")
                .font(.caption2)
        }
        .buttonStyle(.plain)
        .foregroundColor(.secondary)
        .padding(.top, 6)
    }
}

// MARK: - Crown value field
// A tappable "which value is the crown driving right now" control — the
// active field gets the session color as a ring so it's legible at a
// glance whether turning the crown will change weight or reps.

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
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? tint : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Idle (no session)

private struct IdleView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
            Text("No active session")
                .font(.subheadline.weight(.semibold))
            Text("Start a session on your iPhone to log sets from here.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
}

// MARK: - Just logged confirmation

private struct LoggedConfirmationView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(Color(hex: "059669"))
            Text("Set logged")
                .font(.headline)
            Text("Next set loading…")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.top, 16)
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
        VStack(spacing: 8) {
            Text("RESTING")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)

            ZStack {
                Circle()
                    .stroke(Color(hex: wc.colorHex).opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color(hex: wc.colorHex), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                Text(remaining >= 60
                     ? String(format: "%d:%02d", remaining / 60, remaining % 60)
                     : "\(remaining)s")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 90, height: 90)

            Text(wc.exerciseName)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)

            Button {
                WKInterfaceDevice.current().play(.click)
                wc.skipRest()
            } label: {
                Text("Skip Rest")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Water

struct WaterView: View {
    @State private var wc = WatchConnectivityManager.shared
    private let waterColor = Color(hex: "0891B2")

    var progress: Double {
        guard wc.waterTargetMl > 0 else { return 0 }
        return min(1.0, Double(wc.waterMl) / Double(wc.waterTargetMl))
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(waterColor.opacity(0.2), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(waterColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.4), value: progress)
                VStack(spacing: 0) {
                    Text("\(wc.waterMl)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("of \(wc.waterTargetMl)ml")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 84, height: 84)

            HStack(spacing: 8) {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    wc.addWater(250)
                } label: {
                    Text("+250")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(waterColor)

                Button {
                    WKInterfaceDevice.current().play(.click)
                    wc.addWater(500)
                } label: {
                    Text("+500")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(waterColor)
            }
        }
        .padding(.top, 8)
    }
}

#Preview {
    ContentView()
}
