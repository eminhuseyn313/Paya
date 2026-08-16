import SwiftUI
import SwiftData

// MARK: - Weekly Health Goals Card

struct WeeklyHealthGoalsCard: View {

    var modelContext: ModelContext

    @State private var report: HealthGoalsEngine.Report? = nil
    @State private var activeCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(Pulse.positive)
                Text("Weekly Goals")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            if let report = report {
                GoalRow(
                    icon: "checkmark.seal.fill",
                    label: "Daily check-ins",
                    value: "\(report.weekCheckIns)/7",
                    progress: Double(report.weekCheckIns) / 7.0,
                    color: Pulse.hydration
                )
                GoalRow(
                    icon: "pills.fill",
                    label: "Supplement adherence",
                    value: "\(Int(report.weekSupplementAdherence * 100))%",
                    progress: report.weekSupplementAdherence,
                    color: Pulse.ai
                )
                GoalRow(
                    icon: "moon.zzz.fill",
                    label: "7h+ sleep nights",
                    value: "\(report.weekSleepGoalNights)/7",
                    progress: Double(report.weekSleepGoalNights) / 7.0,
                    color: Pulse.recovery
                )
            } else {
                Text("Log your health daily to track weekly goals.")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
            }
        }
        .payaCard(padding: 14)
        .onAppear { recompute() }
    }

    private func recompute() {
        let supplements = UserSupplementStore.active(context: modelContext)
        activeCount = supplements.count
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let logs = (try? modelContext.fetch(descriptor)) ?? []
        report = HealthGoalsEngine.compute(logs: logs, activeSupplementCount: activeCount)
    }
}

struct GoalRow: View {
    let icon: String
    let label: String
    let value: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                    .frame(width: 20)
                Text(label)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundColor(color)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.12))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(1, progress))
                }
            }
            .frame(height: 6)
        }
    }
}//
//  HealthGamificationCards.swift
//  Paya
//
//  Created by Emin Huseynzade on 11.07.26.
//

