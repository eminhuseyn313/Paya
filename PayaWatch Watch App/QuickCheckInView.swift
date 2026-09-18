import SwiftUI
import WatchKit

struct QuickCheckInView: View {

    @State private var energy: Int = 2
    @State private var soreness: Int = 1
    @State private var hasSymptom = false
    @State private var didSubmit = false

    var body: some View {
        if didSubmit {
            submittedView
        } else {
            formView
        }
    }

    // MARK: - Form

    private var formView: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("Check-in")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(WatchPulse.textPrimary)

                // Energy
                VStack(spacing: 4) {
                    Text("ENERGY")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(WatchPulse.textTertiary)
                        .tracking(0.5)

                    HStack(spacing: 8) {
                        energyButton(level: 1, label: "Low", icon: "battery.25percent")
                        energyButton(level: 2, label: "OK", icon: "battery.50percent")
                        energyButton(level: 3, label: "High", icon: "battery.100percent")
                    }
                }

                // Soreness
                VStack(spacing: 4) {
                    Text("SORENESS")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(WatchPulse.textTertiary)
                        .tracking(0.5)

                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { level in
                            Button {
                                soreness = level
                                WKInterfaceDevice.current().play(.click)
                            } label: {
                                Text("\(level)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .frame(width: 28, height: 28)
                                    .background(soreness == level ? sorenessColor(level).opacity(0.2) : WatchPulse.surface)
                                    .foregroundColor(soreness == level ? sorenessColor(level) : WatchPulse.textTertiary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(sorenessLabel)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(WatchPulse.textSecondary)
                }

                // Symptom flag
                Button {
                    hasSymptom.toggle()
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: hasSymptom ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 12))
                        Text("Feeling unwell")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(hasSymptom ? WatchPulse.critical : WatchPulse.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(hasSymptom ? WatchPulse.critical.opacity(0.1) : WatchPulse.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                // Submit
                Button {
                    submit()
                } label: {
                    Text("Log")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(WatchPulse.positive)
            }
            .padding(.horizontal, 4)
        }
        .background(WatchPulse.canvas)
    }

    // MARK: - Submitted

    private var submittedView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(WatchPulse.positive.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(WatchPulse.positive)
            }
            Text("Logged")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(WatchPulse.textPrimary)
            Text("Energy \(energyLabel) · Soreness \(soreness)/5")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(WatchPulse.textSecondary)
        }
        .padding(.top, 16)
        .background(WatchPulse.canvas)
    }

    // MARK: - Helpers

    private func energyButton(level: Int, label: String, icon: String) -> some View {
        Button {
            energy = level
            WKInterfaceDevice.current().play(.click)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(energy == level ? energyColor.opacity(0.2) : WatchPulse.surface)
            .foregroundColor(energy == level ? energyColor : WatchPulse.textTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var energyColor: Color {
        switch energy {
        case 1: return WatchPulse.critical
        case 3: return WatchPulse.positive
        default: return WatchPulse.warning
        }
    }

    private var energyLabel: String {
        switch energy {
        case 1: return "low"
        case 3: return "high"
        default: return "ok"
        }
    }

    private var sorenessLabel: String {
        switch soreness {
        case 1: return "No soreness"
        case 2: return "A little tight"
        case 3: return "Moderate"
        case 4: return "Very sore"
        default: return "Extremely sore"
        }
    }

    private func sorenessColor(_ level: Int) -> Color {
        switch level {
        case 1: return WatchPulse.positive
        case 2: return Color(hex: "84CC16")
        case 3: return WatchPulse.warning
        case 4: return Color(hex: "EA580C")
        default: return WatchPulse.critical
        }
    }

    private func submit() {
        WKInterfaceDevice.current().play(.success)
        didSubmit = true

        let payload: [String: Any] = [
            "type": "quickCheckIn",
            "energy": energy,
            "soreness": soreness,
            "hasSymptom": hasSymptom,
            "timestamp": Date().timeIntervalSince1970
        ]
        WatchConnectivityManager.shared.sendCheckIn(payload)
    }
}
