import SwiftUI

// MARK: - Sleep Stages Card
//
// BiometricStore already fetches deep/REM sleep from HealthKit for its
// z-score baselines (FlareDetectionEngine, ReadinessEngine) but never
// surfaced the actual numbers anywhere — deep sleep specifically is when
// growth hormone release and tissue/immune repair concentrate (Besedovsky
// L, Lange T, Born J. "Sleep and immune function." Pflugers Arch. 2012),
// which is directly relevant to recovery, not just a curiosity stat.

struct SleepStagesCard: View {
    @State private var deepHours: Double? = nil
    @State private var remHours: Double? = nil
    @State private var totalHours: Double? = nil
    @State private var isLoading = true

    private var deepPercent: Int? {
        guard let deepHours, let totalHours, totalHours > 0 else { return nil }
        return Int((deepHours / totalHours * 100).rounded())
    }
    private var remPercent: Int? {
        guard let remHours, let totalHours, totalHours > 0 else { return nil }
        return Int((remHours / totalHours * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bed.double.fill")
                    .foregroundColor(Color(hex: "6366F1"))
                Text("Sleep Stages")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            if isLoading {
                SwiftUI.ProgressView()
                    .padding(.vertical, 8)
            } else if deepHours == nil && remHours == nil {
                Text("No sleep-stage data yet — the Apple Watch tracks this automatically once you sleep with it on.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 20) {
                    if let deepHours, let deepPercent {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .lastTextBaseline, spacing: 3) {
                                Text(String(format: "%.1fh", deepHours))
                                    .font(.title3.bold())
                                Text("(\(deepPercent)%)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text("Deep sleep")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let remHours, let remPercent {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .lastTextBaseline, spacing: 3) {
                                Text(String(format: "%.1fh", remHours))
                                    .font(.title3.bold())
                                Text("(\(remPercent)%)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text("REM sleep")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Text("Deep sleep is when the body concentrates most of its tissue and immune repair — a useful recovery signal beyond raw hours slept.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .payaCard(padding: 14)
        .task {
            let biometrics = BiometricStore.shared
            if biometrics.history.isEmpty {
                await biometrics.loadHistory(daysBack: 14)
            }
            let today = biometrics.today ?? biometrics.yesterday
            deepHours = today?.sleepDeep
            remHours = today?.sleepREM
            totalHours = today?.sleepHours
            isLoading = false
        }
    }
}
