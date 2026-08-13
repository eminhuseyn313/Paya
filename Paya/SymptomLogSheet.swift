import SwiftUI
import SwiftData

// MARK: - Symptom Store

enum SymptomStore {
    @MainActor
    static func todaysLogs(context: ModelContext) -> [SymptomLog] {
        let pid = ActiveProfile.id
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<SymptomLog>(
            predicate: #Predicate<SymptomLog> { $0.date >= startOfDay && $0.profileId == pid },
            sortBy: [SortDescriptor(\.onsetDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    static func recent(daysBack: Int, context: ModelContext) -> [SymptomLog] {
        let pid = ActiveProfile.id
        let cutoff = Calendar.current.date(byAdding: .day, value: -daysBack, to: .now) ?? .now
        let descriptor = FetchDescriptor<SymptomLog>(
            predicate: #Predicate<SymptomLog> { $0.date >= cutoff && $0.profileId == pid },
            sortBy: [SortDescriptor(\.onsetDate, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

// MARK: - Symptom Options

struct SymptomOption: Identifiable {
    let id: String
    let emoji: String
    let label: String
    let color: String
}

let symptomOptions: [SymptomOption] = [
    SymptomOption(id: "headache", emoji: "🤕", label: "Headache", color: "D97706"),
    SymptomOption(id: "feeling_unwell", emoji: "🤒", label: "Feeling unwell", color: "DC2626"),
    SymptomOption(id: "nausea", emoji: "🤢", label: "Nausea", color: "059669"),
    SymptomOption(id: "dizziness", emoji: "😵‍💫", label: "Dizziness", color: "8B5CF6"),
    SymptomOption(id: "fatigue", emoji: "😮‍💨", label: "Fatigue", color: "D97706"),
    SymptomOption(id: "digestive", emoji: "🫃", label: "Stomach off", color: "D97706"),
    SymptomOption(id: "shoulder_pain", emoji: "🦴", label: "Shoulder pain", color: "DC2626"),
    SymptomOption(id: "back_tight", emoji: "🔙", label: "Back tight", color: "D97706"),
    SymptomOption(id: "knee_pain", emoji: "🦵", label: "Knee pain", color: "DC2626"),
    SymptomOption(id: "wrist_pain", emoji: "✋", label: "Wrist pain", color: "DC2626"),
    SymptomOption(id: "anxiety", emoji: "😰", label: "Anxiety", color: "8B5CF6"),
    SymptomOption(id: "brain_fog", emoji: "🌫️", label: "Brain fog", color: "6B7280"),
    SymptomOption(id: "chest_tight", emoji: "🫁", label: "Chest tight", color: "DC2626"),
    SymptomOption(id: "eye_strain", emoji: "👁️", label: "Eye strain", color: "D97706"),
    SymptomOption(id: "dehydrated", emoji: "💧", label: "Dehydrated", color: "0891B2"),
]

// MARK: - Log Sheet

struct SymptomLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var onSaved: () -> Void = {}

    @State private var selectedTag: String? = nil
    @State private var severity: Int = 2
    @State private var onsetDate: Date = .now
    @State private var notes: String = ""
    @State private var didSave = false

    private let severityLabels = ["Mild", "Moderate", "Severe"]
    private let severityColors = ["F59E0B", "D97706", "DC2626"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    Text("What are you experiencing?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)

                    FlowLayout(spacing: 6) {
                        ForEach(symptomOptions) { option in
                            let isOn = selectedTag == option.id
                            Button {
                                selectedTag = isOn ? nil : option.id
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack(spacing: 5) {
                                    Text(option.emoji).font(.system(size: 13))
                                    Text(option.label).font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(isOn ? Color(hex: option.color).opacity(0.2) : Color(.tertiarySystemBackground))
                                .foregroundStyle(isOn ? Color(hex: option.color) : .primary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().strokeBorder(isOn ? Color(hex: option.color).opacity(0.5) : .clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .payaCard(padding: 14)

                    if selectedTag != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("When did it start?")
                                .font(.subheadline.weight(.semibold))

                            DatePicker("Onset", selection: $onsetDate, in: ...Date.now, displayedComponents: [.hourAndMinute])
                                .labelsHidden()
                                .datePickerStyle(.compact)

                            HStack(spacing: 8) {
                                onsetQuickButton("Just now", date: .now)
                                onsetQuickButton("~30 min ago", date: Date.now.addingTimeInterval(-1800))
                                onsetQuickButton("~1h ago", date: Date.now.addingTimeInterval(-3600))
                                onsetQuickButton("~2h ago", date: Date.now.addingTimeInterval(-7200))
                            }
                        }
                        .payaCard(padding: 14)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Severity")
                                .font(.subheadline.weight(.semibold))

                            HStack(spacing: 8) {
                                ForEach(1...3, id: \.self) { level in
                                    Button {
                                        severity = level
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        Text(severityLabels[level - 1])
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(severity == level ? .white : .primary)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(severity == level ? Color(hex: severityColors[level - 1]) : Color(.tertiarySystemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .payaCard(padding: 14)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notes (optional)")
                                .font(.subheadline.weight(.semibold))
                            TextField("Any context — what you were doing, ate, etc.", text: $notes, axis: .vertical)
                                .font(.caption)
                                .lineLimit(2...4)
                                .padding(10)
                                .background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .payaCard(padding: 14)
                    }

                    Button {
                        save()
                        withAnimation(.spring(response: 0.3)) { didSave = true }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onSaved()
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if didSave {
                                Image(systemName: "checkmark")
                                    .font(.headline.weight(.bold))
                                    .transition(.scale)
                            }
                            Text(didSave ? "Logged" : "Log symptom")
                                .font(.headline.weight(.bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(selectedTag != nil ? Color(hex: "DC2626") : Color.secondary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(selectedTag == nil || didSave)
                    .padding(.horizontal, 16)

                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("Log a symptom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func onsetQuickButton(_ label: String, date: Date) -> some View {
        Button {
            onsetDate = date
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func save() {
        guard let tag = selectedTag else { return }
        let log = SymptomLog(tag: tag, onsetDate: onsetDate, severity: severity, notes: notes)
        log.profileId = ActiveProfile.id
        modelContext.insert(log)
        try? modelContext.save()
    }
}

// MARK: - Symptom Log Card (inline summary for Health tab)

struct SymptomLogCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var todaysLogs: [SymptomLog] = []
    @State private var showSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "stethoscope")
                    .foregroundColor(Color(hex: "DC2626"))
                Text("Symptoms")
                    .font(.subheadline.weight(.semibold))
                CardInfoButton(
                    title: "Symptom Tracking",
                    explanation: "Log symptoms anytime — headache, fatigue, pain, nausea. Each entry records when it started so the correlation engine can trace what happened in the hours before onset (sleep, meals, water gaps, stress, noise)."
                )
                Spacer()
                Button {
                    showSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Log")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundColor(Color(hex: "DC2626"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "DC2626").opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if todaysLogs.isEmpty {
                Text("Nothing logged today — tap + to record a symptom when it happens.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ForEach(todaysLogs) { log in
                    let option = symptomOptions.first { $0.id == log.tag }
                    HStack(spacing: 8) {
                        Text(option?.emoji ?? "🩹")
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(option?.label ?? log.tag)
                                .font(.caption.weight(.semibold))
                            Text("Started \(log.onsetDate.formatted(date: .omitted, time: .shortened)) · \(["Mild", "Moderate", "Severe"][min(log.severity - 1, 2)])")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if !log.notes.isEmpty {
                            Image(systemName: "note.text")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .payaCard(padding: 14)
        .onAppear { todaysLogs = SymptomStore.todaysLogs(context: modelContext) }
        .sheet(isPresented: $showSheet) {
            SymptomLogSheet {
                todaysLogs = SymptomStore.todaysLogs(context: modelContext)
            }
        }
    }
}

// MARK: - Symptom Timeline Card (for Personal Health view)

struct SymptomTimelineCard: View {
    let symptomLogs: [SymptomLog]
    var onLogged: () -> Void = {}
    @State private var showSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "stethoscope")
                    .foregroundColor(Color(hex: "DC2626"))
                Text("Symptoms")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button { showSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Log")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundColor(Color(hex: "DC2626"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "DC2626").opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if symptomLogs.isEmpty {
                Text("Log a symptom when it happens — the earlier you capture it, the better the correlation engine can trace what led to it.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                ForEach(symptomLogs) { log in
                    let option = symptomOptions.first { $0.id == log.tag }
                    HStack(spacing: 8) {
                        Text(option?.emoji ?? "🩹")
                            .font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(option?.label ?? log.tag)
                                .font(.caption.weight(.semibold))
                            HStack(spacing: 4) {
                                Text("Started \(log.onsetDate.formatted(date: .omitted, time: .shortened))")
                                Text("·")
                                Text(["Mild", "Moderate", "Severe"][min(log.severity - 1, 2)])
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .payaCard(padding: 14)
        .sheet(isPresented: $showSheet) {
            SymptomLogSheet { onLogged() }
        }
    }
}
