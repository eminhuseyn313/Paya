import SwiftUI

// MARK: - Session Intensity Heatmap
// Which exercises in THIS session actually drove your heart rate up, and
// which you coasted through — a per-exercise breakdown instead of the
// single whole-session average/peak the completion screen used to show.

struct SessionIntensityCard: View {
    let session: TrainingSession
    @State private var showHRMonitorSetup = false

    private var intensities: [SessionIntensityEngine.ExerciseIntensity] {
        SessionIntensityEngine.analyze(session: session, maxHR: LiveHRManager.shared.maxHR)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(Color(hex: "DC2626"))
                Text("Effort Map")
                    .font(.subheadline.weight(.semibold))
                CardInfoButton(
                    title: "Effort Map",
                    explanation: "Each exercise's average heart rate during its sets, expressed as % of your estimated max HR (220 − age, or your set value). Zones follow ACSM's exercise-intensity classification: Light <64%, Moderate 64-76%, Vigorous 77-93%, Near-max 94%+. This shows which exercises actually pushed you, not just the whole-session average."
                )
                Spacer()
            }

            if SessionIntensityEngine.hasUsableData(intensities) {
                VStack(spacing: 8) {
                    ForEach(intensities) { intensity in
                        IntensityRow(intensity: intensity)
                    }
                }

                HStack(spacing: 10) {
                    legendDot(.light)
                    legendDot(.moderate)
                    legendDot(.vigorous)
                    legendDot(.nearMax)
                }
            } else {
                // This card depends entirely on per-set heart rate, which
                // comes from a Bluetooth HR monitor connected during the
                // session (BLEHeartRateManager) — nothing to do with the
                // Watch app. Without one connected, the card used to just
                // silently not render at all, which looks identical to the
                // feature not existing.
                Button {
                    showHRMonitorSetup = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "heart.text.square")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No heart rate data for this session")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.primary)
                            Text("Connect a Bluetooth heart rate monitor before your next session to see which exercises actually pushed you.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .payaCard(padding: 14)
        .sheet(isPresented: $showHRMonitorSetup) {
            HeartRateMonitorView()
        }
    }

    private func legendDot(_ zone: SessionIntensityEngine.IntensityZone) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: zone.colorHex))
                .frame(width: 6, height: 6)
            Text(zone.rawValue)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

private struct IntensityRow: View {
    let intensity: SessionIntensityEngine.ExerciseIntensity

    var body: some View {
        HStack(spacing: 10) {
            Text(intensity.exerciseName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(.tertiarySystemBackground))
                    if let pct = intensity.percentMaxHR {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(hex: intensity.zone.colorHex))
                            .frame(width: geo.size.width * min(1, pct / 100))
                    }
                }
            }
            .frame(height: 18)

            Text(intensity.avgHR.map { "\(Int($0))" } ?? "—")
                .font(.caption.weight(.bold))
                .foregroundColor(Color(hex: intensity.zone.colorHex))
                .frame(width: 32, alignment: .trailing)
        }
    }
}
