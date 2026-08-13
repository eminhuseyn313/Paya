import SwiftUI
import WatchKit

// MARK: - Watch Quick Check-in
//
// A stripped-down morning check-in for the wrist. Users pick energy
// (1-3), soreness (1-5), and an optional symptom flag — takes ~8
// seconds. Data is sent to the phone via WatchConnectivity where it
// becomes a full DailyCheckIn entry.
//
// Why on watch: the morning check-in prompt on the phone only fires
// when the user opens the app. Many users see the notification and
// dismiss it — but they're already wearing the watch when they wake up.

struct QuickCheckInView: View {

    @State private var energy: Int = 2      // 1=low, 2=ok, 3=high
    @State private var soreness: Int = 1    // 1=none … 5=very sore
    @State private var hasSymptom = false
    @State private var didSubmit = false

    private let green = Color(hex: "059669")
    private let amber = Color(hex: "F59E0B")

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
                Text("Quick Check-in")
                    .font(.headline)

                // Energy
                VStack(spacing: 4) {
                    Text("ENERGY")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        energyButton(level: 1, label: "Low", icon: "battery.25percent")
                        energyButton(level: 2, label: "OK", icon: "battery.50percent")
                        energyButton(level: 3, label: "High", icon: "battery.100percent")
                    }
                }

                // Soreness
                VStack(spacing: 4) {
                    Text("SORENESS")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { level in
                            Button {
                                soreness = level
                                WKInterfaceDevice.current().play(.click)
                            } label: {
                                Text("\(level)")
                                    .font(.system(size: 14, weight: .bold))
                                    .frame(width: 28, height: 28)
                                    .background(soreness == level ? sorenessColor(level).opacity(0.2) : Color(.darkGray).opacity(0.3))
                                    .foregroundColor(soreness == level ? sorenessColor(level) : .secondary)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text(sorenessLabel)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
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
                            .font(.caption2)
                    }
                    .foregroundColor(hasSymptom ? Color(hex: "DC2626") : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(hasSymptom ? Color(hex: "DC2626").opacity(0.1) : Color(.darkGray).opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)

                // Submit
                Button {
                    submit()
                } label: {
                    Text("Log Check-in")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(green)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Submitted

    private var submittedView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(green)
            Text("Logged")
                .font(.headline)
            Text("Energy \(energyLabel) · Soreness \(soreness)/5")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.top, 16)
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
                    .font(.system(size: 9, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(energy == level ? energyColor.opacity(0.2) : Color(.darkGray).opacity(0.3))
            .foregroundColor(energy == level ? energyColor : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var energyColor: Color {
        switch energy {
        case 1: return Color(hex: "DC2626")
        case 3: return green
        default: return amber
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
        case 1: return green
        case 2: return Color(hex: "84CC16")
        case 3: return amber
        case 4: return Color(hex: "EA580C")
        default: return Color(hex: "DC2626")
        }
    }

    private func submit() {
        WKInterfaceDevice.current().play(.success)
        didSubmit = true

        // Send to phone via WatchConnectivity
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
