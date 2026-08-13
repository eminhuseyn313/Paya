import SwiftUI

// MARK: - Floating Session Bar
// Persistent bar that appears at the top of every non-Train tab while a session is active.

struct FloatingSessionBar: View {

    @Bindable var appState: AppState
    @Binding var selectedTab: Int

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedTab = 1   // Train tab
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            VStack(spacing: 0) {

                HStack(spacing: 12) {

                    // Pulsing dot
                    ZStack {
                        Circle()
                            .fill(appState.activeSessionColor)
                            .frame(width: 10, height: 10)
                            .scaleEffect(1.4)
                            .opacity(0.3)
                            .animation(
                                .easeInOut(duration: 1.0)
                                    .repeatForever(autoreverses: true),
                                value: appState.isSessionActive
                            )
                        Circle()
                            .fill(appState.activeSessionColor)
                            .frame(width: 10, height: 10)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(appState.isSessionPaused ? "Session paused" : "Session in progress")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.primary)
                            Text("·")
                                .foregroundColor(.secondary)
                            Text(appState.activeSessionLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(appState.activeSessionColor)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .font(.system(size: 9))
                            Text(appState.sessionDurationDisplay)
                            Text("·")
                            Text("\(appState.completedSetsInSession)/\(appState.totalSetsInSession) sets")
                        }
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("Resume")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(appState.activeSessionColor)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(appState.activeSessionColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(appState.activeSessionColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(appState.activeSessionColor.opacity(0.12))
                        Rectangle()
                            .fill(appState.activeSessionColor)
                            .frame(width: geo.size.width * appState.sessionProgressPercent)
                            .animation(.spring(response: 0.4), value: appState.sessionProgressPercent)
                    }
                }
                .frame(height: 2)
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(appState.activeSessionColor.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
