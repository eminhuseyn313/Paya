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

                    // Pulsing dot — breathes during active, static when paused
                    ZStack {
                        if !appState.isSessionPaused {
                            Circle()
                                .fill(appState.activeSessionColor)
                                .frame(width: 10, height: 10)
                                .scaleEffect(1.6)
                                .opacity(0.25)
                                .animation(
                                    UIAccessibility.isReduceMotionEnabled ? .default :
                                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                                    value: appState.isSessionActive
                                )
                        }
                        Circle()
                            .fill(appState.activeSessionColor)
                            .frame(width: 8, height: 8)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(appState.isSessionPaused ? "Paused" : "In progress")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Pulse.textPrimary)
                            Text("·")
                                .foregroundColor(Pulse.textTertiary)
                            Text(appState.activeSessionLabel)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(appState.activeSessionColor)
                                .lineLimit(1)
                        }
                        .lineLimit(1)
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .font(.system(size: 9))
                            Text(appState.sessionDurationDisplay)
                                .monospacedDigit()
                            Text("·")
                            Text("\(appState.completedSetsInSession)/\(appState.totalSetsInSession) sets")
                                .monospacedDigit()
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Pulse.textTertiary)
                        .lineLimit(1)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Text("Resume")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(appState.activeSessionColor)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(appState.activeSessionColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(appState.activeSessionColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(appState.activeSessionColor.opacity(0.1))
                        Rectangle()
                            .fill(appState.activeSessionColor)
                            .frame(width: geo.size.width * appState.sessionProgressPercent)
                            .animation(.spring(response: 0.4), value: appState.sessionProgressPercent)
                    }
                }
                .frame(height: 2.5)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Pulse.surfaceElevatedFallback)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(appState.activeSessionColor.opacity(0.2), lineWidth: 0.5)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: appState.activeSessionColor.opacity(0.12), radius: 12, y: 4)
            .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
        }
        .buttonStyle(PulsePress(scale: 0.98))
        .padding(.horizontal, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
