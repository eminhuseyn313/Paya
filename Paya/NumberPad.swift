import SwiftUI

// MARK: - Number Pad
// Custom in-app numeric keypad for logging weight and reps.
// Slides up from the bottom, has quick-adjust chips, and auto-advances fields.

struct NumberPadSheet: View {

    enum Field { case weight, reps }

    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    @Binding var weight: Double
    @Binding var reps: Int

    var setNumber: Int
    var totalSets: Int
    var exerciseName: String
    var sessionColor: Color
    var measurement: ExerciseMeasurement = .weightedReps
    var previousWeight: Double?
    var previousReps: Int?

    var onComplete: () -> Void

    @State private var activeField: Field = .weight
    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var showPlateCalculator = false

    private var useLbs: Bool { appState.profile.prefersLbs }
    private var weightUnit: String { useLbs ? "lbs" : "kg" }
    private func toDisplay(_ kg: Double) -> Double { useLbs ? kg * 2.20462 : kg }
    private func toKg(_ display: Double) -> Double { useLbs ? display / 2.20462 : display }

    private var repsLabel: String {
        measurement == .timed ? "DURATION" : "REPS"
    }
    private var repsUnit: String {
        measurement == .timed ? "sec" : ""
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Header
            VStack(spacing: 4) {
                HStack {
                    // 44pt is the empirically-measured minimum for reliable
                    // single-tap accuracy (Parhi, Karlson & Bederson,
                    // MobileHCI'06) — these were 28pt, well under that, and
                    // this sheet is exactly the "sweaty, glance-and-tap"
                    // context that threshold matters most for.
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                    Text("Set \(setNumber) of \(totalSets)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    if measurement.showsWeightField {
                        Button {
                            showPlateCalculator = true
                        } label: {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.title3)
                                .foregroundColor(sessionColor)
                                .frame(width: 44, height: 44)
                        }
                    } else {
                        Color.clear.frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Text(exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .padding(.bottom, 8)
            }
            .background(Color(.secondarySystemBackground))

            // MARK: Active field display
            HStack(spacing: 12) {
                if measurement.showsWeightField {
                    ValueDisplay(
                        label: "WEIGHT",
                        unit: weightUnit,
                        value: weightText,
                        isActive: activeField == .weight,
                        sessionColor: sessionColor,
                        previousText: previousWeight.map { "prev \(formatWeight(toDisplay($0))) \(weightUnit)" }
                    ) {
                        activeField = .weight
                    }
                }

                ValueDisplay(
                    label: repsLabel,
                    unit: repsUnit,
                    value: repsText,
                    isActive: activeField == .reps,
                    sessionColor: sessionColor,
                    previousText: previousReps.map { measurement == .timed ? "prev \($0)s" : "prev \($0) reps" }
                ) {
                    activeField = .reps
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground))

            // MARK: Quick-adjust chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if activeField == .weight {
                        if useLbs {
                            QuickChip(text: "−10", color: .secondary) { adjustWeight(-10) }
                            QuickChip(text: "−5", color: .secondary) { adjustWeight(-5) }
                            QuickChip(text: "−2.5", color: .secondary) { adjustWeight(-2.5) }
                            QuickChip(text: "+2.5", color: sessionColor) { adjustWeight(+2.5) }
                            QuickChip(text: "+5", color: sessionColor) { adjustWeight(+5) }
                            QuickChip(text: "+10", color: sessionColor) { adjustWeight(+10) }
                        } else {
                            QuickChip(text: "−5", color: .secondary) { adjustWeight(-5) }
                            QuickChip(text: "−2.5", color: .secondary) { adjustWeight(-2.5) }
                            QuickChip(text: "−1.25", color: .secondary) { adjustWeight(-1.25) }
                            QuickChip(text: "−0.5", color: .secondary) { adjustWeight(-0.5) }
                            QuickChip(text: "+0.5", color: sessionColor) { adjustWeight(+0.5) }
                            QuickChip(text: "+1.25", color: sessionColor) { adjustWeight(+1.25) }
                            QuickChip(text: "+2.5", color: sessionColor) { adjustWeight(+2.5) }
                            QuickChip(text: "+5", color: sessionColor) { adjustWeight(+5) }
                        }
                    } else if measurement == .timed {
                        QuickChip(text: "−15", color: .secondary) { adjustReps(-15) }
                        QuickChip(text: "−5", color: .secondary) { adjustReps(-5) }
                        QuickChip(text: "+5", color: sessionColor) { adjustReps(+5) }
                        QuickChip(text: "+10", color: sessionColor) { adjustReps(+10) }
                        QuickChip(text: "+15", color: sessionColor) { adjustReps(+15) }
                        QuickChip(text: "+30", color: sessionColor) { adjustReps(+30) }
                    } else {
                        QuickChip(text: "−5", color: .secondary) { adjustReps(-5) }
                        QuickChip(text: "−1", color: .secondary) { adjustReps(-1) }
                        QuickChip(text: "+1", color: sessionColor) { adjustReps(+1) }
                        QuickChip(text: "+2", color: sessionColor) { adjustReps(+2) }
                        QuickChip(text: "+5", color: sessionColor) { adjustReps(+5) }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)
            .background(Color(.tertiarySystemBackground))

            // MARK: Numeric keypad
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    KeypadButton(text: "1") { tap("1") }
                    KeypadButton(text: "2") { tap("2") }
                    KeypadButton(text: "3") { tap("3") }
                }
                HStack(spacing: 8) {
                    KeypadButton(text: "4") { tap("4") }
                    KeypadButton(text: "5") { tap("5") }
                    KeypadButton(text: "6") { tap("6") }
                }
                HStack(spacing: 8) {
                    KeypadButton(text: "7") { tap("7") }
                    KeypadButton(text: "8") { tap("8") }
                    KeypadButton(text: "9") { tap("9") }
                }
                HStack(spacing: 8) {
                    if activeField == .weight {
                        KeypadButton(text: ".") { tap(".") }
                    } else {
                        KeypadButton(text: "0", isWide: false) { tap("0") }
                    }
                    if activeField == .weight {
                        KeypadButton(text: "0") { tap("0") }
                    } else {
                        KeypadButton(text: "", systemImage: "delete.left") { backspace() }
                    }
                    KeypadButton(text: "", systemImage: activeField == .weight ? "delete.left" : "checkmark", isPrimary: activeField == .reps, sessionColor: sessionColor) {
                        if activeField == .weight {
                            backspace()
                        } else {
                            commit()
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))

            // MARK: Action buttons
            HStack(spacing: 10) {
                if activeField == .weight {
                    Button {
                        activeField = .reps
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack {
                            Text("Next: Reps")
                                .font(.headline)
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(sessionColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                } else {
                    if measurement.showsWeightField {
                        Button {
                            activeField = .weight
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: "arrow.left")
                                .font(.headline)
                                .frame(width: 60)
                                .padding(.vertical, 16)
                                .background(Color(.tertiarySystemBackground))
                                .foregroundColor(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    Button {
                        commit()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Log Set")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "059669"))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground))
        }
        .background(Color(.secondarySystemBackground))
        .presentationDetents([.height(560)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
        .onAppear {
            weightText = formatWeight(toDisplay(weight))
            repsText = "\(reps)"
            if !measurement.showsWeightField { activeField = .reps }
        }
        .sheet(isPresented: $showPlateCalculator) {
            PlateCalculatorView(targetWeightKg: weight, sessionColor: sessionColor)
        }
    }

    // MARK: - Logic

    private func tap(_ digit: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if activeField == .weight {
            if digit == "." && weightText.contains(".") { return }
            if weightText == "0" && digit != "." { weightText = digit }
            else { weightText += digit }
            if let v = Double(weightText) { weight = toKg(v) }
        } else {
            if digit == "." { return }
            if repsText == "0" { repsText = digit }
            else { repsText += digit }
            if let v = Int(repsText) { reps = v }
        }
    }

    private func backspace() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if activeField == .weight {
            if !weightText.isEmpty { weightText.removeLast() }
            if weightText.isEmpty { weightText = "0" }
            weight = toKg(Double(weightText) ?? 0)
        } else {
            if !repsText.isEmpty { repsText.removeLast() }
            if repsText.isEmpty { repsText = "0" }
            reps = Int(repsText) ?? 0
        }
    }

    private func adjustWeight(_ delta: Double) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let displayVal = max(0, toDisplay(weight) + delta)
        weight = toKg(displayVal)
        weightText = formatWeight(displayVal)
    }

    private func adjustReps(_ delta: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let newVal = max(0, reps + delta)
        reps = newVal
        repsText = "\(newVal)"
    }

    private func commit() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onComplete()
        isPresented = false
    }

    private func formatWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        let oneDecimal = (value * 10).rounded() / 10
        if abs(value - oneDecimal) < 0.01 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }
}

// MARK: - Value Display

struct ValueDisplay: View {
    var label: String
    var unit: String
    var value: String
    var isActive: Bool
    var sessionColor: Color
    var previousText: String?
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isActive ? sessionColor : .secondary)
                    Spacer()
                    if isActive {
                        Circle()
                            .fill(sessionColor)
                            .frame(width: 6, height: 6)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value.isEmpty ? "0" : value)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Text(previousText ?? " ")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? sessionColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Chip

struct QuickChip: View {
    var text: String
    var color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 14)
                // These get tapped repeatedly in a row (e.g. "+2.5" three
                // times to dial in a weight) — exactly the sequential-tap
                // case the research flags as needing the larger ~45pt/9.6mm
                // minimum, not just the 44pt single-tap one.
                .frame(minHeight: 45)
                .background(color.opacity(0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Keypad Button

struct KeypadButton: View {
    var text: String
    var systemImage: String? = nil
    var isWide: Bool = false
    var isPrimary: Bool = false
    var sessionColor: Color = .accentColor
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isPrimary
                        ? sessionColor
                        : Color(.tertiarySystemBackground))
                    .frame(height: 54)
                if let img = systemImage {
                    Image(systemName: img)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(isPrimary ? .white : .primary)
                } else {
                    Text(text)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(isPrimary ? .white : .primary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }
}
