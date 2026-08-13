import SwiftUI

// MARK: - Milestone Toast Manager
// Singleton observable that surfaces a milestone the instant it's recorded
// while the app is in the foreground, instead of leaving it silent until
// the user opens the Notification Center.

@MainActor
@Observable
final class MilestoneToastManager {

    static let shared = MilestoneToastManager()

    private(set) var current: MilestoneEngine.Milestone?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(_ milestone: MilestoneEngine.Milestone) {
        dismissTask?.cancel()
        current = milestone
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            current = nil
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}

// MARK: - Toast Overlay

struct MilestoneToastOverlay: View {

    @State private var manager = MilestoneToastManager.shared

    var body: some View {
        VStack {
            if let milestone = manager.current {
                MilestoneToastCard(milestone: milestone)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { manager.dismiss() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Dismiss")
            }
            Spacer()
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.current?.id)
        .allowsHitTesting(manager.current != nil)
    }
}

private struct MilestoneToastCard: View {
    let milestone: MilestoneEngine.Milestone

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundColor(Color(hex: "B45309"))
                .frame(width: 44, height: 44)
                .background(Color(hex: "B45309").opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(milestone.title)
                    .font(.subheadline.weight(.bold))
                Text(milestone.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
    }
}
