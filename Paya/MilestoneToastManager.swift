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
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Pulse.nutrition.opacity(0.15))
                    .frame(width: 44, height: 44)
                Circle()
                    .fill(Pulse.nutrition.opacity(0.06))
                    .frame(width: 52, height: 52)
                    .blur(radius: 6)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Pulse.nutrition)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(milestone.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Pulse.textPrimary)
                Text(milestone.body)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Pulse.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Pulse.surfaceElevatedFallback)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Pulse.nutrition.opacity(0.15), lineWidth: 0.5)
                )
        )
        .shadow(color: Pulse.nutrition.opacity(0.15), radius: 12, y: 4)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
        .scaleEffect(appeared ? 1 : 0.9)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                appeared = true
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}
