import SwiftUI
import SwiftData

// MARK: - Session Edit View
// Full editor for any past completed session.

struct SessionEditView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var session: TrainingSession

    @State private var showAddExerciseSheet = false
    @State private var showDeleteSessionConfirm = false
    @State private var editedNotes: String = ""

    var sessionType: SessionType? {
        SessionType(rawValue: session.sessionType)
    }

    var sessionColor: Color {
        sessionType?.color ?? .blue
    }

    var sortedExercises: [ExerciseLog] {
        session.exercises.sorted { $0.orderIndex < $1.orderIndex }
    }

    var totalVolume: Double {
        session.exercises.reduce(0.0) { total, ex in
            total + ex.sets.filter { $0.isCompleted }.reduce(0.0) {
                $0 + ($1.weightKg * Double($1.reps))
            }
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            ScrollView {
                VStack(spacing: 16) {

                    // Session header
                                        SessionEditHeader(
                                            session: session,
                                            sessionColor: sessionColor,
                                            totalVolume: totalVolume
                                        )

                                        // Effort map — which exercises actually drove HR up
                                        SessionIntensityCard(session: session)
                                        BodyHeatmapCard(session: session)

                                        // Reflection card
                                        SessionReflectionCard(session: session)

                                        // Notes
                                        SessionNotesField(
                                            notes: $editedNotes,
                                            onSave: {
                                                session.notes = editedNotes
                                                try? modelContext.save()
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            }
                                        )

                    // Exercises
                    ForEach(sortedExercises) { exerciseLog in
                        EditableExerciseCard(
                            session: session,
                            exerciseLog: exerciseLog,
                            sessionColor: sessionColor
                        )
                    }

                    // Add exercise button
                    Button {
                        showAddExerciseSheet = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text("Add Exercise")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(sessionColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(sessionColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Delete session
                    Button {
                        showDeleteSessionConfirm = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "trash.fill")
                            Text("Delete Session")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.top, 8)

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .frame(width: geo.size.width)
            }
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showAddExerciseSheet) {
                AddExerciseToSessionSheet(
                    session: session,
                    sessionColor: sessionColor
                )
            }
            .alert("Delete this session?", isPresented: $showDeleteSessionConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    modelContext.delete(session)
                    try? modelContext.save()
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    dismiss()
                }
            } message: {
                Text("This session and all its logged sets will be permanently removed.")
            }
            .onAppear {
                editedNotes = session.notes
            }
        }
    }
}

// MARK: - Session Edit Header

struct SessionEditHeader: View {
    var session: TrainingSession
    var sessionColor: Color
    var totalVolume: Double

    var sessionType: SessionType? {
        SessionType(rawValue: session.sessionType)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(sessionColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Text(session.sessionType)
                        .font(.title2.bold())
                        .foregroundColor(sessionColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(sessionType?.displayName ?? "Session \(session.sessionType)")
                        .font(.headline)
                    Text(session.date.formatted(.dateTime.weekday(.wide).day().month().year()))
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                    if session.isFlareDay {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text("Flare day")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundColor(Pulse.warning)
                    }
                }
                Spacer()
            }

            HStack(spacing: 10) {
                EditStatPill(
                    icon: "timer",
                    value: "\(session.durationMinutes)m",
                    color: Pulse.hydration
                )
                EditStatPill(
                    icon: "dumbbell.fill",
                    value: "\(session.exercises.count) ex",
                    color: Pulse.positive
                )
                EditStatPill(
                    icon: "scalemass.fill",
                    value: String(format: "%.0fkg", totalVolume),
                    color: sessionColor
                )
            }
        }
        .payaCard(padding: 16)
    }
}

struct EditStatPill: View {
    var icon: String
    var value: String
    var color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundColor(Pulse.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Session Notes Field

struct SessionNotesField: View {
    @Binding var notes: String
    var onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.caption.weight(.semibold))
                .foregroundColor(Pulse.textTertiary)
            TextField("How did this session feel?", text: $notes, axis: .vertical)
                .font(.subheadline)
                .padding(10)
                .background(Pulse.surfaceElevatedFallback)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .lineLimit(2...5)
                .onChange(of: notes) { _, _ in onSave() }
        }
        .payaCard(padding: 12)
    }
}

// MARK: - Editable Exercise Card

struct EditableExerciseCard: View {

    @Environment(\.modelContext) private var modelContext

    var session: TrainingSession
    var exerciseLog: ExerciseLog
    var sessionColor: Color

    @State private var isExpanded: Bool = false
    @State private var showDeleteConfirm: Bool = false

    var sortedSets: [SetLog] {
        exerciseLog.sets.sorted { $0.setNumber < $1.setNumber }
    }

    var body: some View {
        VStack(spacing: 0) {

            // Header
            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(sessionColor.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: "dumbbell.fill")
                                .font(.caption)
                                .foregroundColor(sessionColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exerciseLog.exerciseName)
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            HStack(spacing: 4) {
                                Text("\(exerciseLog.sets.count) sets")
                                    .font(.caption)
                                    .foregroundColor(Pulse.textTertiary)
                                if let att = exerciseLog.cableAttachment.flatMap({ CableAttachment(rawValue: $0) }) {
                                    Text("· \(att.displayName)")
                                        .font(.caption)
                                        .foregroundColor(sessionColor.opacity(0.8))
                                }
                                if let pos = exerciseLog.cablePosition.flatMap({ CablePosition(rawValue: $0) }) {
                                    Text("· \(pos.displayName)")
                                        .font(.caption)
                                        .foregroundColor(sessionColor.opacity(0.8))
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                    }
                }
                .buttonStyle(PulsePress())

                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(12)

            // Set list
            if isExpanded {
                Divider().padding(.horizontal, 12)

                VStack(spacing: 8) {
                    HStack {
                        Text("#")
                            .frame(width: 24, alignment: .leading)
                        Text("WEIGHT (KG)")
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("REPS")
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("✓")
                            .frame(width: 32, alignment: .center)
                        Color.clear.frame(width: 28)
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Pulse.textTertiary)

                    ForEach(sortedSets) { setLog in
                        EditableSetRow(
                            setLog: setLog,
                            sessionColor: sessionColor,
                            onDelete: {
                                modelContext.delete(setLog)
                                try? modelContext.save()
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        )
                    }

                    Button {
                        addSet()
                    } label: {
                        Label("Add Set", systemImage: "plus.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(sessionColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(sessionColor.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(12)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .alert("Remove this exercise?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                modelContext.delete(exerciseLog)
                try? modelContext.save()
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        } message: {
            Text("All sets logged for \(exerciseLog.exerciseName) will be removed.")
        }
    }

    func addSet() {
        let nextNumber = (exerciseLog.sets.map { $0.setNumber }.max() ?? 0) + 1
        let lastSet = sortedSets.last
        let newSet = SetLog(
            setNumber: nextNumber,
            weightKg: lastSet?.weightKg ?? 0,
            reps: lastSet?.reps ?? 10,
            isCompleted: true
        )
        modelContext.insert(newSet)
        newSet.exercise = exerciseLog
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - Editable Set Row

struct EditableSetRow: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var setLog: SetLog
    var sessionColor: Color
    var onDelete: () -> Void

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @FocusState private var weightFocused: Bool
    @FocusState private var repsFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text("\(setLog.setNumber)")
                .font(.subheadline.weight(.bold))
                .foregroundColor(Pulse.textTertiary)
                .frame(width: 24, alignment: .leading)

            TextField("0", text: $weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Pulse.surfaceElevatedFallback)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .focused($weightFocused)
                .onChange(of: weightText) { _, new in
                    if let val = Double(new) {
                        setLog.weightKg = val
                        try? modelContext.save()
                    }
                }

            TextField("0", text: $repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Pulse.surfaceElevatedFallback)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .focused($repsFocused)
                .onChange(of: repsText) { _, new in
                    if let val = Int(new) {
                        setLog.reps = val
                        try? modelContext.save()
                    }
                }

            Button {
                setLog.isCompleted.toggle()
                try? modelContext.save()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: setLog.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(setLog.isCompleted ? sessionColor : .secondary)
            }
            .frame(width: 32)

            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(.red.opacity(0.7))
            }
            .frame(width: 28)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    weightFocused = false
                    repsFocused = false
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            weightText = formatWeight(setLog.weightKg)
            repsText = "\(setLog.reps)"
        }
    }

    private func formatWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        let oneDecimal = (value * 10).rounded() / 10
        if abs(value - oneDecimal) < 0.01 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }
}

// MARK: - Add Exercise to Session Sheet

struct AddExerciseToSessionSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var session: TrainingSession
    var sessionColor: Color

    @State private var customName: String = ""
    @State private var initialSets: Int = 3

    var sessionType: SessionType? {
        SessionType(rawValue: session.sessionType)
    }

    var existingIds: Set<String> {
        Set(session.exercises.map { $0.exerciseId })
    }

    var availableProgramExercises: [ExerciseDefinition] {
        guard let type = sessionType else { return [] }
        return ProgramData.exercises(for: type)
            .filter { !existingIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // From program
                    if !availableProgramExercises.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Add from program")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 4)

                            ForEach(availableProgramExercises) { exercise in
                                Button {
                                    addProgramExercise(exercise)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(sessionColor)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(exercise.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundColor(Pulse.textPrimary)
                                            Text("\(exercise.muscleGroup) · \(exercise.sets) sets")
                                                .font(.caption)
                                                .foregroundColor(Pulse.textTertiary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(Pulse.textTertiary)
                                    }
                                    .payaCard(padding: 12)
                                }
                            }
                        }
                    }

                    // Custom
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Add custom exercise")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 4)

                        VStack(spacing: 10) {
                            TextField("Exercise name", text: $customName)
                                .padding(12)
                                .background(Pulse.surfaceElevatedFallback)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            HStack {
                                Text("Sets")
                                    .font(.subheadline)
                                    .foregroundColor(Pulse.textTertiary)
                                Spacer()
                                Stepper("\(initialSets)", value: $initialSets, in: 1...10)
                                    .labelsHidden()
                                Text("\(initialSets)")
                                    .font(.subheadline.weight(.bold))
                                    .frame(width: 28)
                            }
                            .padding(12)
                            .background(Pulse.surfaceElevatedFallback)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            Button {
                                addCustomExercise()
                                dismiss()
                            } label: {
                                Text("Add Custom Exercise")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(customName.isEmpty
                                        ? Pulse.surfaceElevatedFallback
                                        : sessionColor)
                                    .foregroundColor(customName.isEmpty ? .secondary : .white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(customName.isEmpty)
                        }
                        .payaCard(padding: 12)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Pulse.textTertiary)
                }
            }
        }
        .presentationDetents([.large])
    }

    func addProgramExercise(_ exercise: ExerciseDefinition) {
        let nextOrder = (session.exercises.map { $0.orderIndex }.max() ?? -1) + 1
        let log = ExerciseLog(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            orderIndex: nextOrder,
            muscleGroup: exercise.muscleGroup
        )
        modelContext.insert(log)
        log.session = session

        for i in 1...exercise.sets {
            let set = SetLog(
                setNumber: i,
                weightKg: exercise.startWeightKg,
                reps: exercise.repRange.min,
                isCompleted: false
            )
            modelContext.insert(set)
            set.exercise = log
        }
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func addCustomExercise() {
        let nextOrder = (session.exercises.map { $0.orderIndex }.max() ?? -1) + 1
        let log = ExerciseLog(
            exerciseId: "custom_\(UUID().uuidString)",
            exerciseName: customName,
            orderIndex: nextOrder
        )
        modelContext.insert(log)
        log.session = session

        for i in 1...initialSets {
            let set = SetLog(
                setNumber: i,
                weightKg: 0,
                reps: 10,
                isCompleted: false
            )
            modelContext.insert(set)
            set.exercise = log
        }
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    // MARK: - Session Reflection Card

    struct SessionReflectionCard: View {

        var session: TrainingSession

        @State private var showReflectionSheet: Bool = false

        var hasReflection: Bool {
            session.reflectedAt != nil
        }

        var body: some View {
            Button {
                showReflectionSheet = true
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: hasReflection
                              ? "text.bubble.fill"
                              : "text.bubble")
                            .foregroundColor(Pulse.ai)
                        Text(hasReflection ? "Your reflection" : "Add reflection")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Pulse.textPrimary)
                        Spacer()
                        Image(systemName: hasReflection ? "pencil" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                    }

                    if hasReflection {
                        if let rpe = session.subjectiveRPE {
                            HStack(spacing: 8) {
                                RPEBadge(rpe: rpe)
                                if let energy = session.energyAfter {
                                    EnergyBadge(energy: energy)
                                }
                                Spacer()
                            }
                        }

                        if !session.reflectionTags.isEmpty {
                            FlowLayout(spacing: 4) {
                                ForEach(session.reflectionTags, id: \.self) { tagId in
                                    Text(displayLabel(for: tagId))
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Pulse.ai.opacity(0.12))
                                        .foregroundColor(Pulse.ai)
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        if let notes = session.reflectionNotes, !notes.isEmpty {
                            Text(notes)
                                .font(.caption)
                                .foregroundColor(Pulse.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        Text("How did this session feel? Tap to add.")
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                    }
                }
                .payaCard(padding: 14)
            }
            .buttonStyle(PulsePress())
            .sheet(isPresented: $showReflectionSheet) {
                ReflectionSheet(session: session)
            }
        }

        // Map tag IDs to display labels (mirrors ReflectionSheet's tag definitions)
        func displayLabel(for id: String) -> String {
            switch id {
            case "in_the_zone":       return "In the zone"
            case "great_pump":        return "Great pump"
            case "strong_today":      return "Strong today"
            case "trained_through":   return "Pushed through"
            case "low_energy":        return "Low energy"
            case "distracted":        return "Distracted"
            case "form_breaking":     return "Form breaking"
            case "ac_clicked":        return "AC joint clicked"   // legacy id, kept for old logged sessions
            case "shoulder_pain":     return "Shoulder pain"
            case "wrist_pain":        return "Wrist pain"
            case "elbow_flare":       return "Elbow flare"
            case "back_tight":        return "Back tight/stiff"
            case "joint_clicked":     return "Joint clicked/caught"
            case "joint_swelling":    return "Joint swelling"
            case "reduced_rom":       return "Reduced range of motion"
            case "hip_pain":          return "Hip pain"
            case "morning_stiffness": return "Morning stiffness lingered"
            case "joint_pain":        return "Joint pain"
            case "fatigue_crash":     return "Fatigue crash"
            case "skin_flare":        return "Skin flare"
            case "widespread_pain":   return "Widespread pain"
            case "brain_fog":         return "Brain fog"
            case "tender_points":     return "Tender points sore"
            case "pem_crash":         return "Post-exertional crash"
            case "fatigue_spike":     return "Fatigue spike"
            case "joint_stiffness":   return "Joint stiffness"
            default:                  return id
            }
        }
    }

    // MARK: - RPE Badge

    struct RPEBadge: View {
        var rpe: Int

        var color: Color {
            switch rpe {
            case 1...3:  return Pulse.positive
            case 4...6:  return Pulse.warning
            case 7...8:  return Color(hex: "C2410C")
            default:     return Pulse.critical
            }
        }

        var label: String {
            switch rpe {
            case 1...2:  return "Very easy"
            case 3...4:  return "Easy"
            case 5...6:  return "Moderate"
            case 7...8:  return "Hard"
            case 9:      return "Very hard"
            case 10:     return "Max"
            default:     return ""
            }
        }

        var body: some View {
            HStack(spacing: 5) {
                Text("RPE \(rpe)")
                    .font(.caption.weight(.bold))
                Text(label)
                    .font(.caption)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
        }
    }

    // MARK: - Energy Badge

    struct EnergyBadge: View {
        var energy: Int

        var icon: String {
            switch energy {
            case 1: return "battery.25"
            case 2: return "battery.50"
            default: return "battery.100"
            }
        }

        var label: String {
            switch energy {
            case 1: return "Drained"
            case 2: return "OK"
            default: return "Energized"
            }
        }

        var color: Color {
            switch energy {
            case 1: return Pulse.critical
            case 2: return Pulse.warning
            default: return Pulse.positive
            }
        }

        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
        }
    }
}
