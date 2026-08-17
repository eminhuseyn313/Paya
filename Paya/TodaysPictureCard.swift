import SwiftUI

// MARK: - Today's Picture Card
// The "quick, glanceable version" of Personal Health Management, right on
// the Dashboard — sunny hours actually walked, time in meetings, water so
// far, and the day's single most useful habit nudge, all visible without
// opening anything. Tapping still opens the full hour-by-hour view.

struct TodaysPictureCard: View {
    var overview: DayOverview?
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(Pulse.warning)
                    Text("Today's Picture")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Pulse.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                }

                if let overview {
                    HStack(spacing: 12) {
                        PictureStat(icon: "sun.max.fill", value: "\(overview.sunnyHoursWalked)h", label: "sunny + walked", color: Pulse.warning)
                        // Real ambient-light-sensor reading (Watch), not
                        // inferred from weather + steps like the stat above —
                        // a different, more direct measurement of the same
                        // underlying "did I get outside" question.
                        PictureStat(icon: "sun.horizon.fill", value: "\(overview.timeInDaylightMin)m", label: "in daylight", color: Pulse.warning)
                        PictureStat(icon: "calendar", value: "\(overview.meetingMinutes)m", label: "in meetings", color: Pulse.hydration)
                        PictureStat(icon: "drop.fill", value: "\(overview.totalWaterMl)ml", label: "water", color: Pulse.recovery)
                    }

                    if let nudge = overview.insights.first {
                        Text(nudge)
                            .font(.caption2)
                            .foregroundColor(Pulse.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                } else {
                    HStack {
                        SwiftUI.ProgressView()
                        Text("Building today's picture…")
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .payaCard(padding: 14)
        }
        .buttonStyle(PulsePress())
    }
}

private struct PictureStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(value)
                    .font(.caption.weight(.bold))
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(Pulse.textTertiary)
        }
    }
}
