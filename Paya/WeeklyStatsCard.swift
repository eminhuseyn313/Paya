import SwiftUI
import SwiftData

struct WeeklyStatsCard: View {

    @Environment(AppState.self) private var appState

    var thisWeekSessions: Int
    var plannedSessions: Int
    var weekStreak: Int
    var thisWeekVolume: Double

    private var useLbs: Bool { appState.profile.prefersLbs }

    var body: some View {
        HStack(spacing: 0) {
            statCell(
                icon: "figure.strengthtraining.traditional",
                value: "\(thisWeekSessions)/\(plannedSessions)",
                label: "Sessions",
                color: sessionColor
            )
            divider
            statCell(
                icon: "flame.fill",
                value: "\(weekStreak)",
                label: weekStreak == 1 ? "Week" : "Weeks",
                color: Color(hex: "DC2626")
            )
            divider
            statCell(
                icon: "scalemass.fill",
                value: volumeLabel,
                label: "Volume",
                color: Color(hex: "0891B2")
            )
        }
        .payaCard(padding: 12)
    }

    private var sessionColor: Color {
        if thisWeekSessions >= plannedSessions { return Color(hex: "059669") }
        if thisWeekSessions > 0 { return Color(hex: "F59E0B") }
        return .secondary
    }

    private var volumeLabel: String {
        let vol = useLbs ? thisWeekVolume * 2.20462 : thisWeekVolume
        let unit = useLbs ? "lbs" : "kg"
        if vol >= 1000 {
            return String(format: "%.1f%@", vol / 1000, useLbs ? "klbs" : "t")
        }
        return String(format: "%.0f%@", vol, unit)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 0.5, height: 36)
            .padding(.horizontal, 4)
    }

    private func statCell(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(color)
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
