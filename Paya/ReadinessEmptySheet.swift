import SwiftUI

/// Shown instead of a blank sheet when the user taps the readiness ring but
/// there is no wearable/baseline data yet. Explains how to get a real score.
struct ReadinessEmptySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "heart.text.square")
                    .font(.pulse(size: 40))
                    .foregroundColor(Pulse.recovery)
                Text("No readiness score yet")
                    .font(.title3.weight(.bold))
                    .foregroundColor(Pulse.textPrimary)
                Text("Readiness is calculated from your own sleep, resting heart rate and heart-rate variability compared with your personal baseline. Paya never guesses a number.")
                    .foregroundColor(Pulse.textSecondary)
                VStack(alignment: .leading, spacing: 10) {
                    Label("Wear your Apple Watch, including overnight, for about a week", systemImage: "applewatch")
                    Label("Allow Health access in iPhone Settings → Privacy & Security → Health", systemImage: "heart.fill")
                    Label("Or log a quick morning check-in from Home", systemImage: "sun.max.fill")
                }
                .font(.subheadline)
                .foregroundColor(Pulse.textPrimary)
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Pulse.canvasFallback.ignoresSafeArea())
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}
