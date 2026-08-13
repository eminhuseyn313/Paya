import SwiftUI

// MARK: - VO2 Max Card
//
// Cardio fitness trend — Apple derives VO2 max from outdoor walk/run/hike
// workouts with GPS + HR data, so it only updates every few days at most.
// Heart rate recovery is recorded the same way and is the other standard
// autonomic-fitness marker exercise physiology cites alongside VO2 max, so
// the two are shown together rather than as separate cards.

struct VO2MaxCard: View {
    @State private var vo2: (value: Double, date: Date)? = nil
    @State private var hrRecovery: (value: Double, date: Date)? = nil
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lungs.fill")
                    .foregroundColor(Color(hex: "059669"))
                Text("Cardio Fitness")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                CardInfoButton(
                    title: "Cardio Fitness",
                    explanation: "VO2 max estimates how much oxygen your body can use during hard exercise — the standard lab measure of aerobic fitness, estimated by Apple from outdoor walk/run/hike workouts with GPS + heart rate. Heart rate recovery (how fast your HR drops in the minute after hard effort) is the other marker exercise physiology cites alongside it — a faster drop means better autonomic recovery. Both update only every few days since they need a real outdoor effort to compute."
                )
            }

            if isLoading {
                ProgressView()
                    .padding(.vertical, 8)
            } else if vo2 == nil && hrRecovery == nil {
                Text("No cardio fitness readings yet — do an outdoor walk, run, or hike with your Watch to start building this trend.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 20) {
                    if let vo2 {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .lastTextBaseline, spacing: 3) {
                                Text(String(format: "%.1f", vo2.value))
                                    .font(.title3.bold())
                                Text("VO2 max")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(vo2.date.formatted(.relative(presentation: .named)))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let hrRecovery {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .lastTextBaseline, spacing: 3) {
                                Text("\(Int(hrRecovery.value))")
                                    .font(.title3.bold())
                                Text("bpm recovery")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(hrRecovery.date.formatted(.relative(presentation: .named)))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Text("VO2 max: how efficiently your body uses oxygen during exercise. HR recovery: how fast your heart rate drops in the first minute after peak effort — both standard aerobic-fitness markers, both estimated from outdoor GPS workouts.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .payaCard(padding: 14)
        .task {
            async let vo2Fetch = HealthKitManager.shared.fetchVO2Max()
            async let hrFetch = HealthKitManager.shared.fetchHeartRateRecovery()
            vo2 = await vo2Fetch
            hrRecovery = await hrFetch
            isLoading = false
        }
    }
}
