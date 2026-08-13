import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Session Live Activity
// Lock Screen + Dynamic Island tracker for an active training session —
// current exercise, set progress, and rest timer, glanceable without
// unlocking into the app. Content comes straight from TrainViewModel's
// pushWatchSnapshot(), the same computation that already feeds the watch app.

struct PayaSessionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PayaSessionActivityAttributes.self) { context in
            LockScreenSessionView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Color(hex: context.attributes.colorHex).opacity(0.12))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.sessionLabel)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(Color(hex: context.attributes.colorHex))
                        Text(context.state.exerciseName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let restEndDate = context.state.restEndDate {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("REST")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(timerInterval: Date.now...restEndDate, countsDown: true)
                                .font(.caption.monospacedDigit())
                                .frame(width: 40)
                        }
                    } else {
                        Text(context.state.setLabel)
                            .font(.caption2.weight(.semibold))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.exerciseProgress)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } compactLeading: {
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(Color(hex: context.attributes.colorHex))
            } compactTrailing: {
                if let restEndDate = context.state.restEndDate {
                    Text(timerInterval: Date.now...restEndDate, countsDown: true)
                        .font(.caption2.monospacedDigit())
                        .frame(width: 34)
                } else {
                    Text(context.state.setLabel)
                        .font(.system(size: 9, weight: .semibold))
                }
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(Color(hex: context.attributes.colorHex))
            }
        }
    }
}

private struct LockScreenSessionView: View {
    let attributes: PayaSessionActivityAttributes
    let state: PayaSessionActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: attributes.colorHex).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(Color(hex: attributes.colorHex))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(attributes.sessionLabel)
                    .font(.caption2.weight(.bold))
                    .foregroundColor(Color(hex: attributes.colorHex))
                Text(state.exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(state.exerciseProgress)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let restEndDate = state.restEndDate {
                VStack(spacing: 2) {
                    Text("REST")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(timerInterval: Date.now...restEndDate, countsDown: true)
                        .font(.title3.monospacedDigit().weight(.bold))
                        .frame(width: 56)
                }
            } else {
                Text(state.setLabel)
                    .font(.subheadline.weight(.bold))
            }
        }
        .padding(16)
    }
}

private extension Color {
    init(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
