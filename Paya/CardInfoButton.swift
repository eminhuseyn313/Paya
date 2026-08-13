import SwiftUI

// MARK: - Card Info Button
//
// Every health/performance card computes something from real data, but
// showing a number with no explanation of what it means or why it moved is
// exactly the kind of "just a chart" experience that makes people stop
// trusting an app's numbers. Drop this into any card's header — it's a
// lightweight, always-available "explain this" affordance for cards that
// don't warrant a full custom detail sheet the way Readiness/Flare Risk do.

struct CardInfoButton: View {
    let title: String
    let explanation: String
    @State private var showing = false

    var body: some View {
        Button {
            showing = true
        } label: {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(explanation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(minWidth: 250, idealWidth: 280, maxWidth: 320)
            .presentationCompactAdaptation(.popover)
        }
    }
}
