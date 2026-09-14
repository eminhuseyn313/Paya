import SwiftUI
import SwiftData

// MARK: - Program Gap Card
//
// Shown on a day's pre-session overview (not mid-workout — this is
// "before you start" context, not something to interrupt a live session
// with). One card per muscle-group gap targeted at THIS day — see
// ProgramGapEngine for how the muscle, exercise, and day are chosen.

struct ProgramGapCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    let dayCode: String
    var onAdded: () -> Void = {}

    @State private var gaps: [ProgramGapEngine.Gap] = []
    @State private var addedIds: Set<String> = []
    @State private var expanded = false

    var body: some View {
        // `.task` must run regardless of whether there's currently
        // anything to show — attaching it inside the `if !visible.isEmpty`
        // branch below would mean it never fires at all, since `gaps`
        // starts empty and that branch would never render to trigger it.
        Group {
            let visible = gaps.filter { !addedIds.contains($0.id) }
            if !visible.isEmpty {
                content(visible)
            }
        }
        .task { await loadGaps() }
    }

    // Multiple gaps can land on the same day (e.g. a muscle missing from
    // the program entirely tends to route to whichever day has the fewest
    // exercises, which can hit several times). Stacking a full row per gap
    // was a big part of why the pre-session screen turned into a wall of
    // cards — show the single most useful one up front, with the rest one
    // tap away instead of pre-expanded.
    @ViewBuilder
    private func content(_ visible: [ProgramGapEngine.Gap]) -> some View {
        let lead = visible[0]
        let rest = Array(visible.dropFirst())

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .foregroundColor(Pulse.ai)
                Text("Program gap")
                    .font(.subheadline.weight(.bold))
                Spacer()
            }

            gapRow(lead)

            if !rest.isEmpty {
                if expanded {
                    ForEach(rest) { gapRow($0) }
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    Text(expanded ? "Show less" : "+\(rest.count) more gap\(rest.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Pulse.ai)
                }
            }

            Text("Based on Renaissance Periodization's published hypertrophy volume guidance, weighed against your equipment, experience, and any joint areas you've flagged — not a diagnosis, a starting point.")
                .font(.system(size: 9.5))
                .foregroundColor(Pulse.textTertiary)
        }
        .payaCard(padding: 14)
    }

    @ViewBuilder
    private func gapRow(_ gap: ProgramGapEngine.Gap) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(gap.reason)
                .font(.system(size: 12))
                .foregroundColor(Pulse.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Pulse.ai.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Pulse.ai)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(gap.recommendedExercise.name)
                        .font(.system(size: 13, weight: .semibold))
                    Text("Add to \(gap.targetDayName)")
                        .font(.system(size: 10))
                        .foregroundColor(Pulse.textTertiary)
                }
                Spacer()
                Button {
                    ProgramGapEngine.addToProgram(gap, context: modelContext)
                    addedIds.insert(gap.id)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onAdded()
                } label: {
                    Text("Add")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Pulse.ai)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(10)
        .background(Pulse.surfaceFallback)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loadGaps() async {
        guard let profile = ProfileStore.current(context: modelContext) else { return }
        gaps = ProgramGapEngine.gaps(for: dayCode, context: modelContext, profile: profile)
    }
}
