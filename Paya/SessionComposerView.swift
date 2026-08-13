import SwiftUI
import SwiftData

// MARK: - Session Composer View
// Full editor for a session's exercise composition. Drag to reorder,
// tap to edit params, add from library, remove, reset to default.

struct SessionComposerView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let dayCode: String
    let dayName: String
    let dayColor: Color
    var onSave: () -> Void

    var hasBuiltInDefault: Bool {
        SessionType(rawValue: dayCode) != nil
    }

    @State private var custom: CustomSession? = nil
    @State private var showLibraryPicker: Bool = false
    @State private var showResetConfirm: Bool = false
    @State private var exerciseToEdit: CustomSessionExercise? = nil

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            ScrollView {
                VStack(spacing: 14) {

                    ComposerHeaderCard(dayCode: dayCode, dayName: dayName, dayColor: dayColor, isCustomized: custom != nil)

                    if let custom = custom {
                        let sorted = custom.sortedExercises
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, exercise in
                            ComposerExerciseCard(
                                exercise: exercise,
                                sessionColor: dayColor,
                                onEdit: { exerciseToEdit = exercise },
                                onMoveUp: { move(exercise, direction: -1) },
                                onMoveDown: { move(exercise, direction: 1) },
                                onDelete: { remove(exercise) },
                                canMoveUp: exercise.orderIndex > 0,
                                canMoveDown: exercise.orderIndex < (custom.exercises.count - 1),
                                isLinkedWithNext: index + 1 < sorted.count
                                    && exercise.supersetGroup != nil
                                    && exercise.supersetGroup == sorted[index + 1].supersetGroup,
                                hasNext: index + 1 < sorted.count,
                                onToggleSuperset: { toggleSuperset(exercise, next: index + 1 < sorted.count ? sorted[index + 1] : nil) }
                            )
                        }

                        Button {
                            showLibraryPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add exercise from library")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundColor(dayColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(dayColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    if custom != nil && hasBuiltInDefault {
                                            Button {
                                                showResetConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.uturn.backward")
                                Text("Reset to default program")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, 8)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .frame(width: geo.size.width)
            }
            }
            .navigationTitle("Customize \(dayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showLibraryPicker) {
                LibraryPickerSheet { picked in
                    add(fromLibrary: picked)
                }
            }
            .sheet(item: $exerciseToEdit) { ex in
                ExerciseParamEditor(
                    exercise: ex,
                    sessionColor: dayColor,
                    onSave: {
                        touchLastEdited()
                    }
                )
            }
            .alert("Reset to default?", isPresented: $showResetConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    reset()
                }
            } message: {
                Text("Your custom \(dayName) composition will be lost. The built-in V-taper program will be restored.")
            }
        }
        .onAppear {
            loadOrCreate()
        }
    }

    // MARK: - Data ops

    private func loadOrCreate() {
        if let existing = CustomSessionStore.fetch(code: dayCode, context: modelContext) {
            custom = existing
        } else {
            custom = CustomSessionStore.createSeeded(code: dayCode, context: modelContext)
        }
    }

    private func touchLastEdited() {
        custom?.lastEditedAt = Date()
        try? modelContext.save()
    }

    private func move(_ exercise: CustomSessionExercise, direction: Int) {
        guard let custom = custom else { return }
        let sorted = custom.sortedExercises
        guard let currentIndex = sorted.firstIndex(where: { $0.id == exercise.id }) else { return }
        let targetIndex = currentIndex + direction
        guard targetIndex >= 0, targetIndex < sorted.count else { return }
        let other = sorted[targetIndex]
        let tmp = exercise.orderIndex
        exercise.orderIndex = other.orderIndex
        other.orderIndex = tmp
        touchLastEdited()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Toggles a superset link between an exercise and the next one in
    /// order — same group number means "back to back, no rest between
    /// them." Reuses either exercise's existing group if one already has
    /// one (so linking a third exercise into an existing pair extends the
    /// group rather than creating a separate one).
    private func toggleSuperset(_ exercise: CustomSessionExercise, next: CustomSessionExercise?) {
        guard let next else { return }
        if exercise.supersetGroup != nil, exercise.supersetGroup == next.supersetGroup {
            // Already linked — unlink. If either side is still linked to a
            // THIRD exercise via the same group, leave the group id alone
            // (breaking only the boundary between these two would need
            // renumbering neighbors, out of scope for a simple toggle).
            exercise.supersetGroup = nil
            next.supersetGroup = nil
        } else {
            let group = exercise.supersetGroup ?? next.supersetGroup ?? Int(Date().timeIntervalSince1970)
            exercise.supersetGroup = group
            next.supersetGroup = group
        }
        touchLastEdited()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func remove(_ exercise: CustomSessionExercise) {
        guard let custom = custom else { return }
        modelContext.delete(exercise)
        // Renumber remaining
        let remaining = custom.sortedExercises.filter { $0.id != exercise.id }
        for (idx, ex) in remaining.enumerated() {
            ex.orderIndex = idx
        }
        touchLastEdited()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func add(fromLibrary libraryExercise: Exercise) {
        guard let custom = custom else { return }
        let nextIndex = (custom.exercises.map { $0.orderIndex }.max() ?? -1) + 1
        let primaryMuscle = libraryExercise.primaryMuscles.first ?? "General"
        let cse = CustomSessionExercise(
            exerciseId: libraryExercise.id,
            exerciseName: libraryExercise.name,
            orderIndex: nextIndex,
            sets: 3,
            repMin: 8,
            repMax: 12,
            startWeightKg: 20,
            restSeconds: 90,
            isJointSensitive: false,
            notes: "",
            muscleGroup: primaryMuscle.capitalized,
            sourceRaw: CustomSessionExercise.Source.library.rawValue
        )
        modelContext.insert(cse)
        cse.session = custom
        touchLastEdited()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func reset() {
        CustomSessionStore.resetToDefault(code: dayCode, context: modelContext)
        custom = nil
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        dismiss()
        onSave()
    }
}

// MARK: - Header

struct ComposerHeaderCard: View {
    let dayCode: String
    let dayName: String
    let dayColor: Color
    let isCustomized: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(dayColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                Text(dayCode)
                    .font(.title2.bold())
                    .foregroundColor(dayColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(dayName)
                    .font(.subheadline.weight(.semibold))
                Text(isCustomized ? "Custom composition" : "Using default program")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Exercise Card

struct ComposerExerciseCard: View {
    let exercise: CustomSessionExercise
    let sessionColor: Color
    let onEdit: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    let canMoveUp: Bool
    let canMoveDown: Bool
    var isLinkedWithNext: Bool = false
    var hasNext: Bool = false
    var onToggleSuperset: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.exerciseName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Text(exercise.muscleGroup)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if exercise.source == .library {
                            Text("Library")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color(hex: "2563EB").opacity(0.15))
                                .foregroundColor(Color(hex: "2563EB"))
                                .clipShape(Capsule())
                        }
                        if exercise.isJointSensitive {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: "B45309"))
                        }
                    }
                }

                Spacer()

                VStack(spacing: 4) {
                    Button(action: onMoveUp) {
                        Image(systemName: "chevron.up")
                            .font(.caption.weight(.bold))
                            .foregroundColor(canMoveUp ? sessionColor : .secondary.opacity(0.3))
                            .frame(width: 28, height: 20)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .disabled(!canMoveUp)
                    .accessibilityLabel("Move exercise up")
                    Button(action: onMoveDown) {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundColor(canMoveDown ? sessionColor : .secondary.opacity(0.3))
                            .frame(width: 28, height: 20)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .disabled(!canMoveDown)
                    .accessibilityLabel("Move exercise down")
                }
            }

            HStack(spacing: 8) {
                ParamPill(icon: "square.stack.3d.up.fill",
                          label: "\(exercise.sets) × \(exercise.repMin)-\(exercise.repMax)")
                ParamPill(icon: "scalemass",
                          label: String(format: "%.1f kg", exercise.startWeightKg))
                ParamPill(icon: "timer",
                          label: "\(exercise.restSeconds)s rest")
            }

            if hasNext {
                Button(action: onToggleSuperset) {
                    HStack(spacing: 6) {
                        Image(systemName: isLinkedWithNext ? "link.circle.fill" : "link")
                        Text(isLinkedWithNext ? "Superset with next — tap to unlink" : "Link with next as superset")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(isLinkedWithNext ? .white : Color(hex: "8B5CF6"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isLinkedWithNext ? Color(hex: "8B5CF6") : Color(hex: "8B5CF6").opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            HStack {
                            Spacer()
                            FormGuideButton(exerciseName: exercise.exerciseName, tint: sessionColor)
                        }

            HStack(spacing: 10) {
                Button(action: onEdit) {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Edit")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(sessionColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(sessionColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Button(action: onDelete) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Remove")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .payaCard(padding: 12)
    }
}

struct ParamPill: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemBackground))
        .clipShape(Capsule())
    }
}

// MARK: - Parameter Editor

struct ExerciseParamEditor: View {

    @Environment(\.dismiss) private var dismiss

    @Bindable var exercise: CustomSessionExercise
    let sessionColor: Color
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            ScrollView {
                VStack(spacing: 14) {

                    Text(exercise.exerciseName)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)

                    // Sets stepper
                    ParamRow(label: "Sets", value: "\(exercise.sets)") {
                        Stepper("", value: $exercise.sets, in: 1...10)
                            .labelsHidden()
                    }

                    // Rep range
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rep range")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            HStack {
                                Text("Min")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Stepper("\(exercise.repMin)", value: $exercise.repMin, in: 1...30)
                                    .labelsHidden()
                                Text("\(exercise.repMin)")
                                    .font(.subheadline.weight(.bold))
                            }
                            .padding(10)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                            HStack {
                                Text("Max")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Stepper("\(exercise.repMax)", value: $exercise.repMax, in: 1...30)
                                    .labelsHidden()
                                Text("\(exercise.repMax)")
                                    .font(.subheadline.weight(.bold))
                            }
                            .padding(10)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .payaCard(padding: 12)

                    // Starting weight
                    ParamRow(
                        label: "Starting weight",
                        value: String(format: "%.1f kg", exercise.startWeightKg)
                    ) {
                        Stepper("", value: $exercise.startWeightKg, in: 0...500, step: 1.25)
                            .labelsHidden()
                    }

                    // Rest
                    ParamRow(label: "Rest between sets", value: "\(exercise.restSeconds)s") {
                        Stepper("", value: $exercise.restSeconds, in: 30...300, step: 15)
                            .labelsHidden()
                    }

                    // Joint-sensitive toggle
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color(hex: "B45309"))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Joint-sensitive")
                                .font(.subheadline.weight(.semibold))
                            Text("Flags for extra caution on flare days")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $exercise.isJointSensitive)
                            .labelsHidden()
                    }
                    .payaCard(padding: 12)

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.secondary)
                        TextField("Form cues, warnings", text: $exercise.notes, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(10)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .payaCard(padding: 12)

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .frame(width: geo.size.width)
            }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct ParamRow<Control: View>: View {
    let label: String
    let value: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color(hex: "2563EB"))
                .frame(minWidth: 60, alignment: .trailing)
            control
        }
        .payaCard(padding: 12)
    }
}

// MARK: - Library Picker Sheet

struct LibraryPickerSheet: View {

    @Environment(\.dismiss) private var dismiss
    var db: ExerciseDatabase = .shared

    let onPick: (Exercise) -> Void

    @State private var filter: ExerciseDatabase.Filter = ExerciseDatabase.Filter()
    @State private var results: [Exercise] = []
    @State private var recomputeTask: Task<Void, Never>? = nil

    func recomputeResults() {
        recomputeTask?.cancel()
        recomputeTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }
            let filtered = db.filtered(filter)
            if Task.isCancelled { return }
            results = filtered
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LibrarySearchBar(text: $filter.query)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                RecommendedToggleRow(db: db)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                LibraryFilterChips(filter: $filter, db: db)
                    .padding(.bottom, 8)

                if results.isEmpty {
                    LibraryEmptyState(
                        filter: filter,
                        hasError: db.loadError != nil,
                        isLoading: db.isLoading
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, exercise in
                                ExerciseRow(exercise: exercise) {
                                    onPick(exercise)
                                    dismiss()
                                }
                                .onAppear {
                                    for offset in 1...10 {
                                        let prefetchIndex = index + offset
                                        guard prefetchIndex < results.count,
                                              let url = results[prefetchIndex].thumbnailURL else {
                                            continue
                                        }
                                        Task.detached(priority: .background) {
                                            _ = await ImageCache.shared.load(
                                                from: url,
                                                targetSize: CGSize(width: 60, height: 60)
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Pick an exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            db.loadIfNeeded()
            recomputeResults()
        }
        .onChange(of: filter) { _, _ in recomputeResults() }
        .onChange(of: db.isLoaded) { _, _ in recomputeResults() }
        .onChange(of: db.showOnlyRecommended) { _, _ in recomputeResults() }
    }
}//
//  SessionComposerView.swift
//  Paya
//
//  Created by Emin Huseynzade on 08.07.26.
//

