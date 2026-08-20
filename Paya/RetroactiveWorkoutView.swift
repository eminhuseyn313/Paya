import SwiftUI
import SwiftData

// MARK: - Retroactive Workout Logger
// Lets users log a full workout session for a past date — exercises, sets, weights, reps, and notes.

struct RetroactiveWorkoutView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var selectedDate: Date = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
    @State private var exercises: [RetroExerciseEntry] = []
    @State private var sessionType: String = "Manual"
    @State private var durationMinutes: Int = 60
    @State private var sessionNotes: String = ""
    @State private var showExercisePicker = false
    @State private var hasAppeared = false
    @State private var showSavedConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Pulse.canvasFallback.ignoresSafeArea()
                BreathingOrb(color: Pulse.energy, size: 220)
                    .offset(y: -280)
                    .opacity(0.3)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Date picker
                        dateSection
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 12)

                        // Session info
                        sessionInfoSection

                        // Exercises
                        exercisesSection

                        // Add exercise button
                        addExerciseButton

                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Log Past Workout")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.textPrimary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Pulse.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveSession() }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(exercises.isEmpty ? Pulse.textTertiary : Pulse.energy)
                        .disabled(exercises.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !exercises.isEmpty {
                    saveBar
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                RetroExercisePickerView { name, muscle in
                    exercises.append(RetroExerciseEntry(name: name, muscleGroup: muscle))
                }
            }
            .overlay {
                if showSavedConfirmation {
                    savedOverlay
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) { hasAppeared = true }
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                    .foregroundColor(Pulse.energy)
                Text("DATE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Pulse.textTertiary)
            }

            DatePicker(
                "Workout date",
                selection: $selectedDate,
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .tint(Pulse.energy)
            .labelsHidden()

            Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Pulse.textPrimary)
        }
        .payaCard(padding: 14)
    }

    // MARK: - Session Info

    private var sessionInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Pulse.recovery)
                Text("SESSION")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Pulse.textTertiary)
            }

            HStack {
                Text("Duration")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Pulse.textPrimary)
                Spacer()
                Stepper(value: $durationMinutes, in: 10...240, step: 5) {
                    Text("\(durationMinutes) min")
                        .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(Pulse.textPrimary)
                }
                .tint(Pulse.energy)
                .frame(width: 180)
            }

            HStack {
                Text("Notes")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Pulse.textPrimary)
                Spacer()
            }
            TextField("Optional session notes", text: $sessionNotes)
                .font(.system(size: 13))
                .foregroundColor(Pulse.textPrimary)
                .padding(10)
                .background(Pulse.surfaceElevatedFallback)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .payaCard(padding: 14)
    }

    // MARK: - Exercises

    private var exercisesSection: some View {
        VStack(spacing: 10) {
            if !exercises.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Pulse.energy)
                    Text("EXERCISES (\(exercises.count))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }

            ForEach($exercises) { $exercise in
                RetroExerciseCard(exercise: $exercise, onDelete: {
                    exercises.removeAll { $0.id == exercise.id }
                })
            }
        }
    }

    // MARK: - Add Exercise

    private var addExerciseButton: some View {
        Button { showExercisePicker = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("Add Exercise")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(Pulse.energy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Pulse.energy.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PulsePress())
    }

    // MARK: - Save Bar

    private var saveBar: some View {
        Button { saveSession() } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                Text("Save \(exercises.count) Exercise\(exercises.count == 1 ? "" : "s")")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Pulse.energy)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Pulse.energy.opacity(0.3), radius: 12, y: 4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [Pulse.canvasFallback, Pulse.canvasFallback.opacity(0.95)],
                startPoint: .bottom,
                endPoint: .top
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Saved Overlay

    private var savedOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(Pulse.positive)
                .shadow(color: Pulse.positive.opacity(0.3), radius: 16)

            Text("Workout Saved!")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(Pulse.textPrimary)

            Text(selectedDate.formatted(.dateTime.month(.wide).day().year()))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Pulse.textSecondary)
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Save

    private func saveSession() {
        guard !exercises.isEmpty else { return }

        // Set the date to midday of the selected date to avoid timezone edge issues
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDate) ?? selectedDate

        let session = TrainingSession(
            sessionType: sessionType,
            date: noon,
            durationMinutes: durationMinutes,
            isCompleted: true,
            notes: sessionNotes
        )
        session.sourceRaw = "manual"
        modelContext.insert(session)

        for (orderIdx, entry) in exercises.enumerated() {
            let exerciseLog = ExerciseLog(
                exerciseId: entry.name.lowercased().replacingOccurrences(of: " ", with: "_"),
                exerciseName: entry.name,
                orderIndex: orderIdx,
                muscleGroup: entry.muscleGroup
            )
            exerciseLog.note = entry.note
            modelContext.insert(exerciseLog)
            exerciseLog.session = session

            for setEntry in entry.sets {
                let setLog = SetLog(
                    setNumber: setEntry.setNumber,
                    weightKg: setEntry.weightKg,
                    reps: setEntry.reps,
                    isCompleted: true,
                    rpe: 0
                )
                modelContext.insert(setLog)
                setLog.exercise = exerciseLog
            }
        }

        try? modelContext.save()
        appState.dataRefreshTrigger = UUID()

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.spring(response: 0.5)) {
            showSavedConfirmation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
}

// MARK: - Data Models

struct RetroExerciseEntry: Identifiable {
    let id = UUID()
    var name: String
    var muscleGroup: String = ""
    var note: String = ""
    var sets: [RetroSetEntry] = [
        RetroSetEntry(setNumber: 1),
        RetroSetEntry(setNumber: 2),
        RetroSetEntry(setNumber: 3)
    ]
}

struct RetroSetEntry: Identifiable {
    let id = UUID()
    var setNumber: Int
    var weightKg: Double = 0
    var reps: Int = 10
}

// MARK: - Exercise Card

struct RetroExerciseCard: View {

    @Binding var exercise: RetroExerciseEntry
    var onDelete: () -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            Button { withAnimation(Pulse.Motion.standard) { isExpanded.toggle() } } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exercise.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Pulse.textPrimary)
                        if !exercise.muscleGroup.isEmpty {
                            Text(exercise.muscleGroup)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Pulse.textTertiary)
                        }
                    }
                    Spacer()

                    Text("\(exercise.sets.count) sets")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Pulse.energy)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Pulse.energy.opacity(0.1))
                        .clipShape(Capsule())

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Pulse.textTertiary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                // Sets
                VStack(spacing: 6) {
                    // Header row
                    HStack {
                        Text("SET")
                            .frame(width: 30, alignment: .leading)
                        Text("WEIGHT (kg)")
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text("REPS")
                            .frame(width: 60, alignment: .center)
                    }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Pulse.textTertiary)

                    ForEach($exercise.sets) { $set in
                        RetroSetRow(set: $set)
                    }
                }

                // Note field
                TextField("Note (optional)", text: $exercise.note)
                    .font(.system(size: 12))
                    .foregroundColor(Pulse.textSecondary)
                    .padding(8)
                    .background(Pulse.surfaceElevatedFallback)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                // Actions
                HStack(spacing: 10) {
                    Button {
                        let newSet = RetroSetEntry(
                            setNumber: exercise.sets.count + 1,
                            weightKg: exercise.sets.last?.weightKg ?? 0,
                            reps: exercise.sets.last?.reps ?? 10
                        )
                        exercise.sets.append(newSet)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("Add Set")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(Pulse.energy)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Pulse.energy.opacity(0.1))
                        .clipShape(Capsule())
                    }

                    Spacer()

                    Button(action: onDelete) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                            Text("Remove")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(Pulse.critical)
                    }
                }
            }
        }
        .payaCard(padding: 12)
    }
}

// MARK: - Set Row

struct RetroSetRow: View {
    @Binding var set: RetroSetEntry

    var body: some View {
        HStack {
            Text("\(set.setNumber)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Pulse.textTertiary)
                .frame(width: 30, alignment: .leading)

            TextField("0", value: $set.weightKg, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(Pulse.textPrimary)
                .padding(.vertical, 8)
                .background(Pulse.surfaceElevatedFallback)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            TextField("0", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(Pulse.textPrimary)
                .frame(width: 60)
                .padding(.vertical, 8)
                .background(Pulse.surfaceElevatedFallback)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - Exercise Picker

struct RetroExercisePickerView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var customName = ""
    @State private var customMuscle = ""

    var onSelect: (String, String) -> Void

    private var filteredExercises: [PoolExercise] {
        let pool = ExercisePool.all
        if searchText.isEmpty { return pool }
        let query = searchText.lowercased()
        return pool.filter {
            $0.name.lowercased().contains(query) ||
            $0.muscleGroup.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Pulse.canvasFallback.ignoresSafeArea()

                List {
                    // Custom exercise section
                    Section {
                        HStack(spacing: 10) {
                            VStack(spacing: 8) {
                                TextField("Exercise name", text: $customName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Pulse.textPrimary)
                                TextField("Muscle group", text: $customMuscle)
                                    .font(.system(size: 12))
                                    .foregroundColor(Pulse.textSecondary)
                            }
                            Button {
                                guard !customName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                                onSelect(customName.trimmingCharacters(in: .whitespaces), customMuscle)
                                dismiss()
                            } label: {
                                Text("Add")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Pulse.energy)
                                    .clipShape(Capsule())
                            }
                        }
                    } header: {
                        Text("Custom Exercise")
                    }
                    .listRowBackground(Pulse.surfaceFallback)

                    // Pool exercises
                    Section {
                        ForEach(filteredExercises, id: \.name) { exercise in
                            Button {
                                onSelect(exercise.name, exercise.muscleGroup)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exercise.name)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Pulse.textPrimary)
                                        Text(exercise.muscleGroup)
                                            .font(.system(size: 11))
                                            .foregroundColor(Pulse.textTertiary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(Pulse.energy)
                                }
                            }
                            .listRowBackground(Pulse.surfaceFallback)
                        }
                    } header: {
                        Text("Exercise Library (\(filteredExercises.count))")
                    }
                }
                .searchable(text: $searchText, prompt: "Search exercises…")
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Pulse.textSecondary)
                }
            }
        }
    }
}
