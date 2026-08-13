import SwiftUI
import SwiftData

struct DailyCheckInView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var onDone: () -> Void = {}

    @State private var soreness: Int? = nil
    @State private var energy: Int? = nil
    @State private var sleep: Int? = nil
    @State private var stress: Int? = nil
    @State private var selectedTags: Set<String> = []
    @State private var selectedBehaviors: Set<String> = []
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: - Header
                    VStack(spacing: 6) {
                        Text(greetingEmoji)
                            .font(.system(size: 48))
                            .id(greetingEmoji)
                            .transition(.scale.combined(with: .opacity))
                        Text(greetingText)
                            .font(.title3.weight(.bold))
                        Text("Takes 10 seconds. Shapes your readiness score.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // MARK: - Body
                    MoodRow(
                        title: "Body",
                        subtitle: "How does your body feel?",
                        value: $soreness,
                        options: [
                            (1, "😣", "Wrecked"),
                            (2, "😕", "Sore"),
                            (3, "😐", "Tight"),
                            (4, "🙂", "Good"),
                            (5, "💪", "Fresh")
                        ]
                    )

                    // MARK: - Energy
                    MoodRow(
                        title: "Energy",
                        subtitle: "How's your energy right now?",
                        value: $energy,
                        options: [
                            (1, "🪫", "Empty"),
                            (2, "😴", "Low"),
                            (3, "⚡", "Normal"),
                            (4, "🔋", "Good"),
                            (5, "🚀", "Wired")
                        ]
                    )

                    // MARK: - Sleep
                    MoodRow(
                        title: "Sleep",
                        subtitle: "How'd you sleep?",
                        value: $sleep,
                        options: [
                            (1, "💀", "Awful"),
                            (2, "😩", "Poor"),
                            (3, "😶", "OK"),
                            (4, "😊", "Good"),
                            (5, "😴", "Great")
                        ]
                    )

                    // MARK: - Stress
                    MoodRow(
                        title: "Stress",
                        subtitle: "Mental load today?",
                        value: $stress,
                        options: [
                            (1, "🧘", "Calm"),
                            (2, "😌", "Light"),
                            (3, "😐", "Normal"),
                            (4, "😤", "High"),
                            (5, "🤯", "Maxed")
                        ]
                    )

                    // MARK: - Behavior Tags
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "tag.fill")
                                .foregroundColor(Color(hex: "8B5CF6"))
                                .font(.system(size: 12))
                            Text("Yesterday's behaviors")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(selectedBehaviors.count) tagged")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Text("What did you do yesterday? This helps Paya learn what helps your recovery.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        FlowLayout(spacing: 6) {
                            ForEach(BehaviorTags.all) { tag in
                                let isOn = selectedBehaviors.contains(tag.id)
                                Button {
                                    if isOn { selectedBehaviors.remove(tag.id) }
                                    else { selectedBehaviors.insert(tag.id) }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: tag.icon)
                                            .font(.system(size: 10))
                                        Text(tag.label)
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(isOn ? Color(hex: tag.colorHex).opacity(0.2) : Color(.tertiarySystemBackground))
                                    .foregroundStyle(isOn ? Color(hex: tag.colorHex) : .primary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(isOn ? Color(hex: tag.colorHex).opacity(0.5) : .clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .payaCard(padding: 14)

                    // MARK: - Flags
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Anything to flag?")
                            .font(.subheadline.weight(.semibold))

                        FlowLayout(spacing: 6) {
                            ForEach(flagOptions, id: \.id) { flag in
                                let isOn = selectedTags.contains(flag.id)
                                Button {
                                    if isOn { selectedTags.remove(flag.id) }
                                    else { selectedTags.insert(flag.id) }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(flag.emoji)
                                            .font(.system(size: 13))
                                        Text(flag.label)
                                            .font(.caption.weight(.semibold))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(isOn ? Color(hex: flag.color).opacity(0.2) : Color(.tertiarySystemBackground))
                                    .foregroundStyle(isOn ? Color(hex: flag.color) : .primary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(isOn ? Color(hex: flag.color).opacity(0.5) : .clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .payaCard(padding: 14)

                    // MARK: - Submit
                    VStack(spacing: 8) {
                        Button {
                            save()
                            withAnimation(.spring(response: 0.3)) { didSave = true }
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                onDone()
                                dismiss()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if didSave {
                                    Image(systemName: "checkmark")
                                        .font(.headline.weight(.bold))
                                        .transition(.scale)
                                }
                                Text(didSave ? "Done" : "Log check-in")
                                    .font(.headline.weight(.bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(hasAnyData ? Color(hex: "059669") : Color.secondary.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!hasAnyData || didSave)

                        Button {
                            onDone()
                            dismiss()
                        } label: {
                            Text("Skip today")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }

                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("Morning check-in")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
    }

    // MARK: - Data

    private var hasAnyData: Bool {
        soreness != nil || energy != nil || sleep != nil || stress != nil || !selectedTags.isEmpty
    }

    private var greetingEmoji: String {
        if let s = soreness, s <= 2 { return "🫂" }
        if let e = energy, e >= 4 { return "🔥" }
        if soreness != nil || energy != nil { return "👋" }
        return "☀️"
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private func save() {
        let sorenessValue = soreness.map { 6 - $0 } ?? 2
        let energyValue: Int
        if let e = energy {
            switch e {
            case 1, 2: energyValue = 1
            case 3: energyValue = 2
            default: energyValue = 3
            }
        } else {
            energyValue = 2
        }

        var allTags = Array(selectedTags)
        if let sl = sleep, sl <= 2 { allTags.append("poor_sleep") }
        if let st = stress, st >= 4 { allTags.append("high_stress") }

        let checkIn = DailyCheckIn(
            soreness: sorenessValue,
            energy: energyValue,
            symptomTags: allTags
        )
        checkIn.profileId = ActiveProfile.id
        modelContext.insert(checkIn)

        // Save behavior tags for yesterday (behaviors are "what did you do yesterday")
        if !selectedBehaviors.isEmpty {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
            let behaviorLog = BehaviorLog(date: yesterday, tagIds: Array(selectedBehaviors))
            modelContext.insert(behaviorLog)
        }

        try? modelContext.save()
    }

    // MARK: - Flag options

    struct FlagOption: Identifiable {
        let id: String
        let emoji: String
        let label: String
        let color: String
    }

    let flagOptions: [FlagOption] = [
        FlagOption(id: "feeling_unwell", emoji: "🤒", label: "Feeling unwell", color: "DC2626"),
        FlagOption(id: "shoulder_pain", emoji: "🦴", label: "Shoulder pain", color: "DC2626"),
        FlagOption(id: "wrist_pain", emoji: "✋", label: "Wrist pain", color: "DC2626"),
        FlagOption(id: "back_tight", emoji: "🔙", label: "Back tight", color: "D97706"),
        FlagOption(id: "knee_pain", emoji: "🦵", label: "Knee pain", color: "DC2626"),
        FlagOption(id: "headache", emoji: "🤕", label: "Headache", color: "D97706"),
        FlagOption(id: "digestive", emoji: "🫃", label: "Stomach off", color: "D97706"),
        FlagOption(id: "dehydrated", emoji: "💧", label: "Dehydrated", color: "0891B2"),
        FlagOption(id: "motivation_low", emoji: "😮‍💨", label: "Low motivation", color: "8B5CF6"),
        FlagOption(id: "travel", emoji: "✈️", label: "Traveling", color: "2563EB"),
    ]
}

// MARK: - Mood Row

struct MoodRow: View {
    let title: String
    let subtitle: String
    @Binding var value: Int?
    let options: [(id: Int, emoji: String, label: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(options, id: \.id) { opt in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            value = opt.id
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 3) {
                            Text(opt.emoji)
                                .font(.system(size: value == opt.id ? 26 : 22))
                                .scaleEffect(value == opt.id ? 1.1 : 1.0)
                            Text(opt.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(value == opt.id ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            value == opt.id
                                ? Color.accentColor.opacity(0.12)
                                : Color(.tertiarySystemBackground)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(value == opt.id ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Soreness Section (used by other views)

struct SorenessSection: View {
    @Binding var soreness: Int?

    let labels = ["", "Fresh", "A little tight", "Sore", "Quite sore", "Very sore"]
    let colors = ["", "059669", "84CC16", "D97706", "F97316", "DC2626"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Muscle soreness")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let s = soreness {
                    Text(labels[s])
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color(hex: colors[s]))
                }
            }
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        withAnimation(.spring(response: 0.2)) { soreness = value }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("\(value)")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(soreness == value ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(soreness == value ? Color(hex: colors[value]) : Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .payaCard(padding: 14)
    }
}
