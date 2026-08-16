import SwiftUI
import SwiftData

// MARK: - Reflection Sheet
// Fast post-session subjective capture. 3-second target time to fill.

struct ReflectionSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    var session: TrainingSession
    var onDone: () -> Void = {}

    @State private var rpe: Int? = nil
    @State private var energyAfter: Int? = nil
    @State private var selectedTags: Set<String> = []
    @State private var notes: String = ""
    @State private var showNotes: Bool = false
    @State private var shareImage: UIImage? = nil
    @State private var activeCondition: ChronicCondition? = nil

    // Predefined tag options — meaningful for strength training + RA context
    let generalTags: [ReflectionTag] = [
        ReflectionTag(id: "in_the_zone", label: "In the zone", color: "059669"),
        ReflectionTag(id: "great_pump", label: "Great pump", color: "059669"),
        ReflectionTag(id: "strong_today", label: "Strong today", color: "059669"),
        ReflectionTag(id: "trained_through", label: "Pushed through", color: "D97706"),
        ReflectionTag(id: "low_energy", label: "Low energy", color: "D97706"),
        ReflectionTag(id: "distracted", label: "Distracted", color: "D97706"),
        ReflectionTag(id: "form_breaking", label: "Form breaking", color: "DC2626")
    ]

    /// Tag options tailored to what the user actually reported having —
    /// these used to be one person's own specific joint/RA context ("AC
    /// joint clicked") shown to every user regardless of whether they even
    /// have a chronic condition set, which meant nothing here applied to
    /// fibromyalgia, ME/CFS, lupus, or anyone without a condition at all.
    private func jointTags(for condition: ChronicCondition) -> [ReflectionTag] {
        switch condition {
        case .rheumatoidArthritis, .psoriaticArthritis:
            return [
                ReflectionTag(id: "joint_clicked", label: "Joint clicked/caught", color: "DC2626"),
                ReflectionTag(id: "joint_swelling", label: "Joint swelling", color: "DC2626"),
                ReflectionTag(id: "shoulder_pain", label: "Shoulder pain", color: "DC2626"),
                ReflectionTag(id: "wrist_pain", label: "Wrist pain", color: "DC2626"),
                ReflectionTag(id: "reduced_rom", label: "Reduced range of motion", color: "D97706")
            ]
        case .ankylosingSpondylitis:
            return [
                ReflectionTag(id: "back_tight", label: "Back tight/stiff", color: "D97706"),
                ReflectionTag(id: "hip_pain", label: "Hip pain", color: "DC2626"),
                ReflectionTag(id: "reduced_rom", label: "Reduced range of motion", color: "D97706"),
                ReflectionTag(id: "morning_stiffness", label: "Morning stiffness lingered", color: "D97706")
            ]
        case .lupus:
            return [
                ReflectionTag(id: "joint_pain", label: "Joint pain", color: "DC2626"),
                ReflectionTag(id: "fatigue_crash", label: "Fatigue crash", color: "DC2626"),
                ReflectionTag(id: "skin_flare", label: "Skin flare", color: "D97706")
            ]
        case .fibromyalgia:
            return [
                ReflectionTag(id: "widespread_pain", label: "Widespread pain", color: "DC2626"),
                ReflectionTag(id: "fatigue_crash", label: "Fatigue crash", color: "DC2626"),
                ReflectionTag(id: "brain_fog", label: "Brain fog", color: "D97706"),
                ReflectionTag(id: "tender_points", label: "Tender points sore", color: "D97706")
            ]
        case .mecfs, .longCovid:
            return [
                ReflectionTag(id: "pem_crash", label: "Post-exertional crash", color: "DC2626"),
                ReflectionTag(id: "fatigue_spike", label: "Fatigue spike", color: "DC2626"),
                ReflectionTag(id: "brain_fog", label: "Brain fog", color: "D97706")
            ]
        case .hypothyroidism:
            return [
                ReflectionTag(id: "fatigue_crash", label: "Fatigue crash", color: "DC2626"),
                ReflectionTag(id: "joint_stiffness", label: "Joint stiffness", color: "D97706")
            ]
        case .other:
            return [
                ReflectionTag(id: "joint_pain", label: "Joint pain", color: "DC2626"),
                ReflectionTag(id: "fatigue_crash", label: "Fatigue crash", color: "DC2626"),
                ReflectionTag(id: "reduced_rom", label: "Reduced range of motion", color: "D97706")
            ]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Compact session header
                    SessionHeaderStrip(session: session)

                    // Which exercises actually drove HR up this session
                    SessionIntensityCard(session: session)
                    BodyHeatmapCard(session: session)

                    // RPE
                    RPESection(rpe: $rpe)

                    // Energy after
                    EnergyAfterSection(energy: $energyAfter)

                    // Tags — general
                    TagSection(
                        title: "How it felt",
                        tags: generalTags,
                        selected: $selectedTags
                    )

                    // Tags — tailored to the user's actual condition, only
                    // shown when they have one set (irrelevant noise otherwise)
                    if let activeCondition {
                        TagSection(
                            title: "Joint & body",
                            tags: jointTags(for: activeCondition),
                            selected: $selectedTags
                        )
                    }

                    // Notes (progressive disclosure)
                    NotesSection(notes: $notes, showNotes: $showNotes)

                    // Actions
                    VStack(spacing: 8) {
                        Button {
                            saveReflection()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            onDone()
                            dismiss()
                        } label: {
                            Text("Save reflection")
                                .font(.headline.weight(.bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(hasAnyData ? Pulse.positive : Color.secondary.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(!hasAnyData)

                        Button {
                            onDone()
                            dismiss()
                        } label: {
                            Text("Skip")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Pulse.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
            .navigationTitle("How did that go?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let shareImage {
                        ShareLink(
                            item: Image(uiImage: shareImage),
                            preview: SharePreview("My Paya session", image: Image(uiImage: shareImage))
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            // If reflecting on an existing session, prefill
            rpe = session.subjectiveRPE
            energyAfter = session.energyAfter
            selectedTags = Set(session.reflectionTags)
            notes = session.reflectionNotes ?? ""
            if !notes.isEmpty { showNotes = true }
            shareImage = SessionShareRenderer.render(
                session: session,
                profileName: appState.profile.name,
                profileColor: SessionType(rawValue: session.sessionType)?.color ?? Pulse.hydration
            )
            if let profile = ProfileStore.current(context: modelContext), profile.hasInflammatoryCondition {
                activeCondition = profile.chronicCondition
            }
        }
    }

    var hasAnyData: Bool {
        rpe != nil || energyAfter != nil || !selectedTags.isEmpty || !notes.isEmpty
    }

    func saveReflection() {
        session.subjectiveRPE = rpe
        session.energyAfter = energyAfter
        session.reflectionTags = Array(selectedTags)
        session.reflectionNotes = notes.isEmpty ? nil : notes
        session.reflectedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Reflection Tag

struct ReflectionTag: Identifiable, Hashable {
    let id: String
    let label: String
    let color: String   // hex
}

// MARK: - Session Header Strip

struct SessionHeaderStrip: View {
    var session: TrainingSession

    var sessionType: SessionType? {
        SessionType(rawValue: session.sessionType)
    }

    var totalVolume: Double {
        session.exercises.reduce(0.0) { total, ex in
            total + ex.sets
                .filter { $0.isCompleted }
                .reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }
        }
    }

    var totalSets: Int {
        session.exercises.reduce(0) { total, ex in
            total + ex.sets.filter { $0.isCompleted }.count
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            if let type = sessionType {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(type.color.opacity(0.15))
                        .frame(width: 46, height: 46)
                    Text(type.rawValue)
                        .font(.title2.bold())
                        .foregroundColor(type.color)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(sessionType?.displayName ?? "Session")
                    .font(.subheadline.weight(.semibold))
                Text(
                    "\(session.durationMinutes)m · \(totalSets) sets · \(Int(totalVolume))kg"
                    + (session.hrRecovery60.map { " · HRR \($0)↓" } ?? "")
                )
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
            }
            Spacer()
        }
        .payaCard(padding: 12)
    }
}

// MARK: - RPE Section

struct RPESection: View {
    @Binding var rpe: Int?

    func colorForRPE(_ value: Int) -> Color {
        switch value {
        case 1...3:  return Pulse.positive
        case 4...6:  return Pulse.warning
        case 7...8:  return Color(hex: "C2410C")
        default:     return Pulse.critical
        }
    }

    func labelForRPE(_ value: Int) -> String {
        switch value {
        case 1...2:  return "Very easy"
        case 3...4:  return "Easy"
        case 5...6:  return "Moderate"
        case 7...8:  return "Hard"
        case 9:      return "Very hard"
        case 10:     return "Maximum"
        default:     return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("How hard did it feel?")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let r = rpe {
                    Text("\(r) · \(labelForRPE(r))")
                        .font(.caption.weight(.bold))
                        .foregroundColor(colorForRPE(r))
                }
            }

            HStack(spacing: 4) {
                ForEach(1...10, id: \.self) { value in
                    Button {
                        withAnimation(.spring(response: 0.2)) {
                            rpe = value
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("\(value)")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(rpe == value ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(rpe == value
                                ? colorForRPE(value)
                                : Pulse.surfaceElevatedFallback)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            HStack {
                Text("Easy")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Pulse.textTertiary)
                Spacer()
                Text("Moderate")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Pulse.textTertiary)
                Spacer()
                Text("Max")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Pulse.textTertiary)
            }
            .padding(.horizontal, 4)
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Energy After Section

struct EnergyAfterSection: View {
    @Binding var energy: Int?

    let options: [(id: Int, icon: String, label: String, color: String)] = [
        (1, "battery.25", "Drained", "DC2626"),
        (2, "battery.50", "OK", "D97706"),
        (3, "battery.100", "Energized", "059669")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Energy after session")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                ForEach(options, id: \.id) { option in
                    Button {
                        withAnimation(.spring(response: 0.2)) {
                            energy = option.id
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: option.icon)
                                .font(.title3)
                                .foregroundColor(energy == option.id
                                    ? .white
                                    : Color(hex: option.color))
                            Text(option.label)
                                .font(.caption.weight(.bold))
                                .foregroundColor(energy == option.id ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(energy == option.id
                            ? Color(hex: option.color)
                            : Pulse.surfaceElevatedFallback)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Tag Section

struct TagSection: View {
    var title: String
    var tags: [ReflectionTag]
    @Binding var selected: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            FlowLayout(spacing: 6) {
                ForEach(tags) { tag in
                    let isSelected = selected.contains(tag.id)
                    Button {
                        if isSelected {
                            selected.remove(tag.id)
                        } else {
                            selected.insert(tag.id)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 4) {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            Text(tag.label)
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected
                            ? Color(hex: tag.color)
                            : Color(hex: tag.color).opacity(0.10))
                        .foregroundColor(isSelected
                            ? .white
                            : Color(hex: tag.color))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Notes Section

struct NotesSection: View {
    @Binding var notes: String
    @Binding var showNotes: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showNotes {
                HStack {
                    Text("Notes")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showNotes = false
                            notes = ""
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Pulse.textTertiary)
                    }
                }
                TextField("Anything else you want to remember?", text: $notes, axis: .vertical)
                    .lineLimit(2...5)
                    .padding(10)
                    .background(Pulse.surfaceElevatedFallback)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showNotes = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add notes (optional)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .foregroundColor(Pulse.textTertiary)
                }
            }
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Flow Layout for tag wrapping (iOS 16+)

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentRowWidth + size.width > maxWidth {
                totalHeight += currentRowHeight + spacing
                currentRowWidth = size.width + spacing
                currentRowHeight = size.height
            } else {
                currentRowWidth += size.width + spacing
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }
        totalHeight += currentRowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX {
                currentY += currentRowHeight + spacing
                currentX = bounds.minX
                currentRowHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}//
//  ReflectionSheet.swift
//  Paya
//
//  Created by Emin Huseynzade on 05.07.26.
//

