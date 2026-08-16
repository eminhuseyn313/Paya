import SwiftUI
import SwiftData
import HealthKit

struct WeeklyEffortCard: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var report: EffortEngine.WeeklyReport? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Image(systemName: appState.profile.goal.icon)
                    .foregroundColor(appState.profile.goal.color)
                Text("Weekly Effort · \(appState.profile.goal.displayName)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let report = report {
                    Text(report.grade.label)
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: report.grade.colorHex))
                        .clipShape(Capsule())
                }
            }

            if let report = report {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color(hex: report.grade.colorHex).opacity(0.15), lineWidth: 9)
                            .frame(width: 76, height: 76)
                        Circle()
                            .trim(from: 0, to: Double(report.score) / 100.0)
                            .stroke(Color(hex: report.grade.colorHex),
                                    style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .frame(width: 76, height: 76)
                            .rotationEffect(.degrees(-90))
                            .animation(PayaAnimation.dataChange, value: report.score)
                        VStack(spacing: 0) {
                            HeroNumberText(value: "\(report.score)", size: 22, color: Color(hex: report.grade.colorHex))
                            Text("/100")
                                .font(.caption2)
                                .foregroundColor(Pulse.textTertiary)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Weekly effort score \(report.score) of 100, grade \(report.grade.label)")

                    Text(report.headline)
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }

                Divider()

                VStack(spacing: 8) {
                    ForEach(report.components) { component in
                        HStack(spacing: 10) {
                            Image(systemName: component.icon)
                                .font(.caption)
                                .foregroundColor(scoreColor(component.score))
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(component.name)
                                    .font(.caption.weight(.semibold))
                                Text(component.detail)
                                    .font(.caption2)
                                    .foregroundColor(Pulse.textTertiary)
                            }
                            Spacer()
                            Text("\(component.score)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(scoreColor(component.score))
                                .monospacedDigit()
                        }
                    }
                }
            } else {
                Text("Computing your week…")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
            }
        }
        .payaCard(padding: 14)
        .onAppear { Task { await recompute() } }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in Task { await recompute() } }
    }

    private func recompute() async {
        let planned = TrainingDayStore.all(context: modelContext)
            .filter { $0.weekday != 0 }.count

        let externalWorkouts = await HealthKitManager.shared.fetchRecentExternalWorkouts(daysBack: 7)
        let externalMinutes = Int(externalWorkouts.reduce(0.0) { $0 + $1.duration } / 60)

        report = EffortEngine.weeklyReport(
            goal: appState.profile.goal,
            context: modelContext,
            plannedSessionsPerWeek: max(1, planned),
            externalActiveMinutes: externalMinutes
        )
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return Pulse.positive
        case 55..<80: return Pulse.warning
        default: return Pulse.critical
        }
    }
}
