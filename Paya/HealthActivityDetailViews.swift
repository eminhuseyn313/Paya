import SwiftUI

// MARK: - Health Activity Detail Pages
//
// Health Activities used to be a list of on/off toggles — real logic
// underneath, but nothing to actually configure once switched on: eye care
// fired at four fixed clock hours regardless of when someone's day starts,
// morning light always meant 8:30am, hydration always meant a fixed 2.5L
// target checked at 3pm. These are the real inner pages: each explains the
// science, then lets you change the actual numbers that drive it.

struct EyeCareDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var startHour: Double = Double(LifestyleReminderSettings.eyeCareStartHour)
    @State private var endHour: Double = Double(LifestyleReminderSettings.eyeCareEndHour)

    private let accent = Color(hex: "0EA5E9")

    var body: some View {
        @Bindable var state = appState
        let isOn = state.profile.notificationCategoryEnabled[NotificationCategory.eyeCare.rawValue] ?? false
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // MARK: - Today's Schedule
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "eye.fill")
                                .foregroundColor(accent)
                            Text("Today's Schedule")
                                .font(.subheadline.weight(.semibold))
                        }

                        if isOn {
                            ForEach(todaySlots, id: \.hour) { slot in
                                HStack(spacing: 10) {
                                    Image(systemName: slot.isPast ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(slot.isPast ? Pulse.positive : .secondary.opacity(0.4))
                                        .font(.body)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(slot.label)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundColor(slot.isPast ? .secondary : .primary)
                                        Text(slot.isDropSlot ? "Lubricating drops" : "20-20-20 break")
                                            .font(.caption2)
                                            .foregroundColor(Pulse.textTertiary)
                                    }
                                    Spacer()
                                    if slot.isNext {
                                        Text("Next")
                                            .font(.caption2.weight(.bold))
                                            .foregroundColor(accent)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(accent.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(Color(hex: "D97706"))
                                    .font(.caption)
                                Text("Reminders are off — turn them on below.")
                                    .font(.caption)
                                    .foregroundColor(Pulse.textTertiary)
                            }
                        }
                    }
                    .payaCard(padding: 14)

                    // MARK: - Quick Guide
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Quick Guide")
                            .font(.subheadline.weight(.semibold))

                        guideRow(icon: "drop.fill", color: "0891B2",
                                 title: "Eye Drops",
                                 detail: "OTC lubricating drops every ~4 hours relieve dry-eye symptoms. Not medicated drops — those need a prescription schedule.")

                        guideRow(icon: "eye.trianglebadge.exclamationmark.fill", color: "8B5CF6",
                                 title: "20-20-20 Rule",
                                 detail: "Every 20 min of screen work, look 20 ft away for 20 sec. American Optometric Association's guideline for reducing digital eye strain.")

                        guideRow(icon: "sun.max.fill", color: "D97706",
                                 title: "Outdoor Time",
                                 detail: "2+ hours/day of outdoor light significantly reduces myopia progression in children and adolescents (Sherwin et al., Ophthalmology 2012).")
                    }
                    .payaCard(padding: 14)

                    // MARK: - Toggle
                    Toggle(isOn: Binding(
                        get: { isOn },
                        set: { state.profile.notificationCategoryEnabled[NotificationCategory.eyeCare.rawValue] = $0 }
                    )) {
                        Text("Enable eye care reminders").font(.subheadline.weight(.semibold))
                    }
                    .payaCard(padding: 14)
                    .tint(accent)

                    // MARK: - Schedule
                    VStack(alignment: .leading, spacing: 14) {
                        Text("ACTIVE WINDOW").font(.caption2.weight(.bold)).foregroundColor(Pulse.textTertiary)

                        VStack(spacing: 6) {
                            HStack {
                                Text("Starts").font(.subheadline)
                                Spacer()
                                Text(hourLabel(startHour)).font(.subheadline.weight(.semibold)).monospacedDigit()
                            }
                            Slider(value: $startHour, in: 5...14, step: 1)
                                .tint(accent)
                                .onChange(of: startHour) { _, v in
                                    LifestyleReminderSettings.eyeCareStartHour = Int(v)
                                    if endHour <= v { endHour = min(23, v + 1); LifestyleReminderSettings.eyeCareEndHour = Int(endHour) }
                                }
                        }
                        VStack(spacing: 6) {
                            HStack {
                                Text("Ends").font(.subheadline)
                                Spacer()
                                Text(hourLabel(endHour)).font(.subheadline.weight(.semibold)).monospacedDigit()
                            }
                            Slider(value: $endHour, in: 15...23, step: 1)
                                .tint(accent)
                                .onChange(of: endHour) { _, v in
                                    LifestyleReminderSettings.eyeCareEndHour = Int(v)
                                }
                        }
                    }
                    .payaCard(padding: 14)

                    Spacer().frame(height: 16)
                }
                .padding(16)
            }
            .navigationTitle("Eye Care")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Today's Slots

    private struct SlotInfo {
        let hour: Int
        let label: String
        let isDropSlot: Bool
        let isPast: Bool
        let isNext: Bool
    }

    private var todaySlots: [SlotInfo] {
        let start = Int(startHour)
        let end = max(start + 1, Int(endHour))
        let span = end - start
        let hours = (0..<4).map { start + (span * $0) / 3 }
        let currentHour = Calendar.current.component(.hour, from: .now)
        var foundNext = false
        return hours.enumerated().map { index, hour in
            let past = hour <= currentHour
            let isNext = !past && !foundNext
            if isNext { foundNext = true }
            return SlotInfo(
                hour: hour,
                label: hourLabel(Double(hour)),
                isDropSlot: index % 2 == 0,
                isPast: past,
                isNext: isNext
            )
        }
    }

    private func guideRow(icon: String, color: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Color(hex: color))
                .frame(width: 20, alignment: .center)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold))
                Text(detail).font(.caption2).foregroundColor(Pulse.textTertiary)
            }
        }
    }

    private func hourLabel(_ h: Double) -> String {
        let hour = Int(h)
        let period = hour < 12 ? "AM" : "PM"
        let display = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(display):00 \(period)"
    }
}

struct MorningLightDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var reminderTime: Date = {
        var comps = DateComponents()
        comps.hour = LifestyleReminderSettings.morningLightHour
        comps.minute = LifestyleReminderSettings.morningLightMinute
        return Calendar.current.date(from: comps) ?? .now
    }()

    var body: some View {
        @Bindable var state = appState
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Bright light soon after waking is the strongest daily anchor for your circadian rhythm (Czeisler et al. on light's role in resetting the human circadian pacemaker). A single well-timed reminder beats a vague intention.")
                        .font(.subheadline)
                        .foregroundColor(Pulse.textTertiary)
                        .payaCard(padding: 14)

                    Toggle(isOn: Binding(
                        get: { state.profile.notificationCategoryEnabled[NotificationCategory.circadian.rawValue] ?? false },
                        set: { state.profile.notificationCategoryEnabled[NotificationCategory.circadian.rawValue] = $0 }
                    )) {
                        Text("Enable morning light reminder").font(.subheadline.weight(.semibold))
                    }
                    .payaCard(padding: 14)
                    .tint(Color(hex: "D97706"))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("REMINDER TIME").font(.caption2.weight(.bold)).foregroundColor(Pulse.textTertiary)
                        DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            .onChange(of: reminderTime) { _, newValue in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                LifestyleReminderSettings.morningLightHour = comps.hour ?? 8
                                LifestyleReminderSettings.morningLightMinute = comps.minute ?? 30
                            }
                    }
                    .payaCard(padding: 14)
                }
                .padding(16)
            }
            .navigationTitle("Morning Light")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}

struct HydrationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var targetMl: Double = Double(LifestyleReminderSettings.hydrationTargetMl)
    @State private var checkTime: Date = {
        var comps = DateComponents()
        comps.hour = LifestyleReminderSettings.hydrationCheckHour
        comps.minute = 0
        return Calendar.current.date(from: comps) ?? .now
    }()

    var body: some View {
        @Bindable var state = appState
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("A nudge fires once, if you're still under 40% of your daily target by the check time you set below.")
                        .font(.subheadline)
                        .foregroundColor(Pulse.textTertiary)
                        .payaCard(padding: 14)

                    Toggle(isOn: Binding(
                        get: { state.profile.notificationCategoryEnabled[NotificationCategory.hydration.rawValue] ?? false },
                        set: { state.profile.notificationCategoryEnabled[NotificationCategory.hydration.rawValue] = $0 }
                    )) {
                        Text("Enable hydration reminder").font(.subheadline.weight(.semibold))
                    }
                    .payaCard(padding: 14)
                    .tint(Pulse.recovery)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("DAILY TARGET").font(.caption2.weight(.bold)).foregroundColor(Pulse.textTertiary)
                        HStack {
                            Text(String(format: "%.1f L", targetMl / 1000))
                                .font(.title3.bold())
                                .monospacedDigit()
                            Spacer()
                            Stepper("", value: $targetMl, in: 1000...5000, step: 250)
                                .labelsHidden()
                        }
                        .onChange(of: targetMl) { _, v in
                            LifestyleReminderSettings.hydrationTargetMl = Int(v)
                        }
                    }
                    .payaCard(padding: 14)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("CHECK TIME").font(.caption2.weight(.bold)).foregroundColor(Pulse.textTertiary)
                        DatePicker("", selection: $checkTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.wheel)
                            .frame(maxWidth: .infinity)
                            .onChange(of: checkTime) { _, newValue in
                                let comps = Calendar.current.dateComponents([.hour], from: newValue)
                                LifestyleReminderSettings.hydrationCheckHour = comps.hour ?? 15
                            }
                    }
                    .payaCard(padding: 14)
                }
                .padding(16)
            }
            .navigationTitle("Hydration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }
}
