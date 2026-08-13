import SwiftUI

// MARK: - Health Activities
//
// Eye care, morning light, and distraction-blocking all existed already —
// eye care and morning light as silent background notification scheduling
// (off by default, toggle buried three taps deep in Settings → Notification
// preferences), and distraction-blocking as a single unlabeled-feeling row
// under Settings → Focus. None of them had anywhere a user would actually
// discover them. This is the front door: one page, one place, that explains
// what each does and lets you turn it on right there.

struct HealthActivitiesCard: View {
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "0EA5E9").opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "figure.mind.and.body")
                        .foregroundColor(Color(hex: "0EA5E9"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Health Activities")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text("Eye care, morning light, and blocking distractions during sessions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .payaCard(padding: 14)
        }
        .buttonStyle(.plain)
    }
}

struct HealthActivitiesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var showFocusModeSettings = false
    @State private var showHeartRateMonitor = false
    @State private var showEyeCare = false
    @State private var showMorningLight = false
    @State private var showHydration = false

    var body: some View {
        @Bindable var state = appState
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {

                    Button { showEyeCare = true } label: {
                        ActivityRow(
                            icon: "eye.fill",
                            color: Color(hex: "0EA5E9"),
                            title: "Eye Care",
                            description: "4 reminders/day, \(LifestyleReminderSettings.eyeCareStartHour):00–\(LifestyleReminderSettings.eyeCareEndHour):00, alternating lubricating drops and the 20-20-20 rule.",
                            isOn: Binding(
                                get: { state.profile.notificationCategoryEnabled[NotificationCategory.eyeCare.rawValue] ?? false },
                                set: { state.profile.notificationCategoryEnabled[NotificationCategory.eyeCare.rawValue] = $0 }
                            )
                        )
                    }
                    .buttonStyle(.plain)

                    Button { showMorningLight = true } label: {
                        ActivityRow(
                            icon: "sun.max.fill",
                            color: Color(hex: "D97706"),
                            title: "Morning Light",
                            description: "One reminder at \(morningLightLabel) — bright light soon after waking anchors your circadian rhythm (Czeisler et al.).",
                            isOn: Binding(
                                get: { state.profile.notificationCategoryEnabled[NotificationCategory.circadian.rawValue] ?? false },
                                set: { state.profile.notificationCategoryEnabled[NotificationCategory.circadian.rawValue] = $0 }
                            )
                        )
                    }
                    .buttonStyle(.plain)

                    Button { showHydration = true } label: {
                        ActivityRow(
                            icon: "drop.fill",
                            color: Color(hex: "0891B2"),
                            title: "Hydration",
                            description: "A nudge at \(LifestyleReminderSettings.hydrationCheckHour):00 if you're under 40% of your \(String(format: "%.1f", Double(LifestyleReminderSettings.hydrationTargetMl) / 1000))L target.",
                            isOn: Binding(
                                get: { state.profile.notificationCategoryEnabled[NotificationCategory.hydration.rawValue] ?? false },
                                set: { state.profile.notificationCategoryEnabled[NotificationCategory.hydration.rawValue] = $0 }
                            )
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showHeartRateMonitor = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "DC2626").opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "heart.text.square.fill")
                                    .foregroundColor(Color(hex: "DC2626"))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Heart Rate Monitor")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                Text("Connect a Bluetooth HR monitor to unlock the Effort Map — see which exercises actually pushed you each session")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .payaCard(padding: 14)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showFocusModeSettings = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "DC2626").opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "hand.raised.slash.fill")
                                    .foregroundColor(Color(hex: "DC2626"))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Block Distractions")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.primary)
                                Text("Shield social media and other apps you choose for the duration of a training session")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .payaCard(padding: 14)
                    }
                    .buttonStyle(.plain)

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Health Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showFocusModeSettings) {
            FocusModeSettingsView()
        }
        .sheet(isPresented: $showHeartRateMonitor) {
            HeartRateMonitorView()
        }
        .sheet(isPresented: $showEyeCare) {
            EyeCareDetailView()
        }
        .sheet(isPresented: $showMorningLight) {
            MorningLightDetailView()
        }
        .sheet(isPresented: $showHydration) {
            HydrationDetailView()
        }
    }

    private var morningLightLabel: String {
        let hour = LifestyleReminderSettings.morningLightHour
        let minute = LifestyleReminderSettings.morningLightMinute
        let period = hour < 12 ? "AM" : "PM"
        let display = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return String(format: "%d:%02d %@", display, minute, period)
    }
}

private struct ActivityRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    var isOn: Bool

    init(icon: String, color: Color, title: String, description: String, isOn: Binding<Bool>) {
        self.icon = icon
        self.color = color
        self.title = title
        self.description = description
        self.isOn = isOn.wrappedValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                Spacer()
                Text(isOn ? "On" : "Off")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(isOn ? color : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((isOn ? color : Color.secondary).opacity(0.12))
                    .clipShape(Capsule())
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .payaCard(padding: 14)
    }
}
