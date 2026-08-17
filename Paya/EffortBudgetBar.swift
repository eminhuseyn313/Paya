import SwiftUI
import SwiftData

// MARK: - Effort Budget Bar
// In-workout pacing signal: live TRIMP accumulated so far vs your own
// historical average for this session type. Answers "how much of a typical
// Session A have I already spent?" while you're still mid-session — the
// piece WHOOP-style strain gives cardio athletes but lifters never get.
// HRSampleBuffer is @Observable, so this refreshes as samples arrive.

struct EffortBudgetBar: View {

    @Environment(\.modelContext) private var modelContext

    var vm: TrainViewModel

    @State private var baselineTrimp: Double? = nil
    private var buffer: HRSampleBuffer { .shared }

    private var liveTrimp: Double {
        let samples = buffer.sessionSamples
        guard !samples.isEmpty else { return 0 }
        return SessionStrainCalculator.computeStrain(
            hrSamples: samples,
            intervalSeconds: buffer.sessionSamplingIntervalSeconds,
            maxHR: LiveHRManager.shared.maxHR,
            restingHR: vm.recoveryContext.restingHR ?? 60
        ).trimpScore
    }

    private var fraction: Double? {
        guard let baselineTrimp, baselineTrimp > 0 else { return nil }
        return liveTrimp / baselineTrimp
    }

    private var barColor: Color {
        guard let fraction else { return Pulse.hydration }
        switch fraction {
        case ..<0.8: return Pulse.positive
        case 0.8..<1.1: return Pulse.warning
        default: return Pulse.critical
        }
    }

    var body: some View {
        // Only meaningful with live HR flowing and a session history to compare to.
        if vm.isSessionActive, !buffer.sessionSamples.isEmpty, let fraction {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "gauge.with.needle")
                        .font(.caption)
                        .foregroundColor(barColor)
                    Text("Effort budget")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(Int(fraction * 100))% of your typical \(vm.selectedDay.name)")
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(barColor.opacity(0.15))
                        Capsule()
                            .fill(barColor)
                            .frame(width: geo.size.width * min(1.0, fraction))
                            .animation(.spring(response: 0.5), value: fraction)
                    }
                }
                .frame(height: 6)

                if fraction > 1.15 {
                    Text("You're well past your usual load — extra sets now cost more recovery than they build.")
                        .font(.caption2)
                        .foregroundColor(Pulse.critical)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .payaCard(padding: 10)
            .onAppear { loadBaseline() }
        }
    }

    private func loadBaseline() {
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        let baseline = SessionTrendsCalculator.baselines(sessions: sessions)
            .first { $0.sessionType == vm.selectedDay.code }
        baselineTrimp = (baseline?.count ?? 0) >= 2 ? baseline?.avgTrimp : nil
    }
}
