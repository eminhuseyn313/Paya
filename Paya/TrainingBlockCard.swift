import SwiftUI
import SwiftData

// MARK: - Training Block Card
// Sits alongside DeloadCard — deload manages the mesocycle (weeks),
// this manages the block (mesocycles). Shows where you are in a typical
// 8-12 week block and, once it's run its course, offers to rotate into
// the complementary goal using the same rebuild pipeline the AI Training
// Coach uses (deterministic ProgramAssembler regeneration, not a freehand
// AI-invented program).

struct TrainingBlockCard: View {
    var profile: PersonProfile
    var onRebuilt: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var status: PeriodizationEngine.BlockStatus? = nil
    @State private var isRebuilding = false

    var body: some View {
        Group {
            if let status {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(Color(hex: "8B5CF6"))
                        Text("Training Block")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("Week \(status.weeksInBlock)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(.tertiarySystemBackground))
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(status.isPhaseChangeDue ? Color(hex: "B45309") : Color(hex: "8B5CF6"))
                                .frame(width: geo.size.width * min(1.0, Double(status.weeksInBlock) / Double(PeriodizationEngine.suggestedBlockWeeks)), height: 6)
                        }
                    }
                    .frame(height: 6)

                    Text(status.rationale)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if status.isPhaseChangeDue {
                        Button {
                            rebuild(to: status.suggestedNextGoal)
                        } label: {
                            if isRebuilding {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            } else {
                                Text("Switch to a \(status.suggestedNextGoal.displayName) block")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color(hex: "B45309"))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .disabled(isRebuilding)
                    }
                }
                .payaCard(padding: 12)
            }
        }
        .onAppear { reload() }
    }

    private func reload() {
        status = PeriodizationEngine.evaluate(profile: profile, context: modelContext)
    }

    private func rebuild(to newGoal: TrainingGoal) {
        isRebuilding = true
        profile.goalRaw = newGoal.rawValue
        TrainingCoachEngine.rebuildProgram(profile: profile, context: modelContext, priorityMuscle: profile.priorityMuscle)
        try? modelContext.save()
        isRebuilding = false
        reload()
        onRebuilt()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
