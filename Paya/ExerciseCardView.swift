import SwiftUI
import SwiftData

// MARK: - Exercise Info Sheet

struct ExerciseInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var exercise: ExerciseDefinition
    var sessionColor: Color

    @State private var hasAppeared = false
    @State private var prWeight: Double? = nil
    @State private var prReps: Int? = nil
    @State private var prDate: Date? = nil
    @State private var sessionCount: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Pulse.canvasFallback.ignoresSafeArea()
                BreathingOrb(color: sessionColor, size: 200)
                    .offset(y: -300)
                    .opacity(0.3)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // Hero demo area
                    VStack(alignment: .leading, spacing: 10) {
                        ExerciseDemoView(
                            exerciseName: exercise.name,
                            urlString: exercise.gifURL,
                            muscleGroup: exercise.muscleGroup,
                            sessionColor: sessionColor,
                            height: 240
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Pulse.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Pulse.Radius.md)
                                .stroke(sessionColor.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: sessionColor.opacity(0.1), radius: 20, y: 8)
                        .padding(.horizontal)
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .scaleEffect(hasAppeared ? 1 : 0.95)

                    // Title + tags
                    VStack(alignment: .leading, spacing: 10) {
                        Text(exercise.name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(Pulse.textPrimary)
                            .padding(.horizontal)
                        HStack(spacing: 8) {
                            TagBadge(text: exercise.type.rawValue, color: sessionColor)
                            TagBadge(text: exercise.muscleGroup, color: Pulse.textTertiary)
                            if exercise.isJointSensitive {
                                TagBadge(text: "JOINT SENSITIVE", color: Pulse.warning)
                            }
                        }
                        .padding(.horizontal)
                    }

                    InfoSection(title: "Prescription") {
                        VStack(spacing: 8) {
                            InfoRow(label: "Sets", value: "\(exercise.sets)")
                            InfoRow(
                                label: exercise.measurement == .timed ? "Duration" : "Rep Range",
                                value: exercise.measurement == .timed
                                    ? "\(exercise.repRange.display)s per set"
                                    : exercise.repRange.display
                            )
                            if exercise.measurement.showsWeightField {
                                InfoRow(label: "Starting Weight", value: String(format: "%.1f kg", exercise.startWeightKg))
                            } else {
                                InfoRow(label: "Load", value: exercise.measurement == .timed ? "Bodyweight — hold for time" : "Bodyweight — no added load")
                            }
                            InfoRow(label: "Target RPE", value: "8 (2 reps left in tank)")
                            InfoRow(label: "Rest", value: "\(RestTimerManager.defaultRest(for: exercise))s")
                        }
                        .payaCard(padding: 12)
                    }

                    // Personal record (loaded from session history)
                    if let prW = prWeight, let prR = prReps, let prD = prDate {
                        InfoSection(title: "Your Record") {
                            HStack(spacing: 12) {
                                Image(systemName: "trophy.fill")
                                    .font(.title2)
                                    .foregroundColor(Pulse.warning)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(prW.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", prW) : String(format: "%.1f", prW))kg × \(prR) reps")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(Pulse.textPrimary)
                                        .monospacedDigit()
                                    HStack(spacing: 4) {
                                        Text("Personal best")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(Pulse.warning)
                                        Text("·")
                                            .foregroundColor(Pulse.textTertiary)
                                        Text(prD.formatted(.dateTime.month(.abbreviated).day()))
                                            .font(.system(size: 11))
                                            .foregroundColor(Pulse.textTertiary)
                                        Text("·")
                                            .foregroundColor(Pulse.textTertiary)
                                        Text("\(sessionCount) session\(sessionCount == 1 ? "" : "s") total")
                                            .font(.system(size: 11))
                                            .foregroundColor(Pulse.textTertiary)
                                    }
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(Pulse.warning.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    InfoSection(title: "Progression Rule") {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "arrow.up.circle.fill")
                                .foregroundColor(sessionColor)
                                .font(.title3)
                            Text(exercise.progressionNote)
                                .font(.subheadline)
                                .foregroundColor(Pulse.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                        .padding(12)
                        .background(sessionColor.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    if let rule = exercise.specialProgressionRule {
                        InfoSection(title: "Coaching Note") {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: exercise.isJointSensitive
                                    ? "exclamationmark.triangle.fill"
                                    : "lightbulb.fill")
                                    .foregroundColor(exercise.isJointSensitive
                                        ? Pulse.warning
                                        : Pulse.hydration)
                                    .font(.title3)
                                Text(rule)
                                    .font(.subheadline)
                                    .foregroundColor(Pulse.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                            .padding(12)
                            .background(
                                (exercise.isJointSensitive
                                    ? Pulse.warning
                                    : Pulse.hydration).opacity(0.07)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    if exercise.isJointSensitive {
                        InfoSection(title: "Joint Safety") {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "bolt.heart.fill")
                                    .foregroundColor(Pulse.warning)
                                    .font(.title3)
                                Text("This exercise loads the \(Self.jointRegion(for: exercise.muscleGroup)). Never chase heavy weight — technique and pain-free range of motion first.")
                                    .font(.subheadline)
                                    .foregroundColor(Pulse.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                            .padding(12)
                            .background(Pulse.warning.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    if !exercise.alternatives.isEmpty {
                        InfoSection(title: "Alternatives") {
                            VStack(spacing: 8) {
                                ForEach(exercise.alternatives, id: \.self) { alt in
                                    HStack(spacing: 10) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.caption)
                                            .foregroundColor(sessionColor)
                                        Text(alt)
                                            .font(.subheadline.weight(.semibold))
                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(sessionColor.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                Text("Same muscle group, same movement pattern — swap when equipment is busy or to vary stimulus across weeks.")
                                    .font(.caption2)
                                    .foregroundColor(Pulse.textTertiary)
                                    .padding(.top, 2)
                            }
                            .payaCard(padding: 12)
                        }
                    } else if let alt = exercise.alternativeExercise {
                        InfoSection(title: "Alternative Exercise") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundColor(Pulse.textTertiary)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(alt)
                                            .font(.subheadline.weight(.semibold))
                                        Text("Use if equipment is busy or to vary stimulus")
                                            .font(.caption)
                                            .foregroundColor(Pulse.textTertiary)
                                    }
                                    Spacer()
                                }

                                ExerciseDemoView(
                                    exerciseName: alt,
                                    urlString: exercise.alternativeGifURL,
                                    muscleGroup: exercise.muscleGroup,
                                    sessionColor: sessionColor,
                                    height: 180
                                )
                            }
                            .payaCard(padding: 12)
                        }
                    }

                    Spacer().frame(height: 30)
                }
                .padding(.top, 12)
            }
            }
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Exercise Info")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Pulse.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) { hasAppeared = true }
            loadExercisePR()
        }
    }

    private func loadExercisePR() {
        let name = exercise.name
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.isCompleted },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let sessions = try? modelContext.fetch(descriptor) else { return }

        var bestWeight = 0.0
        var bestReps = 0
        var bestDate = Date.distantPast
        var count = 0

        for session in sessions {
            for log in session.exercises where log.exerciseName == name {
                count += 1
                for set in log.sets where set.isCompleted {
                    if set.weightKg > bestWeight || (set.weightKg == bestWeight && set.reps > bestReps) {
                        bestWeight = set.weightKg
                        bestReps = set.reps
                        bestDate = session.date
                    }
                }
            }
        }

        sessionCount = count
        if bestWeight > 0 || bestReps > 0 {
            prWeight = bestWeight
            prReps = bestReps
            prDate = bestDate
        }
    }

    /// isJointSensitive is a broad flag used across ~80 exercises spanning
    /// every pattern (squats, presses, curls, rows) — it used to always
    /// render as "This exercise loads the AC joint," which was simply wrong
    /// for anything that isn't a shoulder-pressing movement (a squat's
    /// joint stress is at the knee/hip, not the AC joint). Naming the
    /// actual region from the exercise's own muscle group keeps the warning
    /// both generically safe and factually correct instead of one person's
    /// specific joint issue applied to every lift in the library.
    static func jointRegion(for muscleGroup: String) -> String {
        switch muscleGroup {
        case "Chest", "Shoulders", "Side Delts", "Rear Delts":
            return "shoulder joint"
        case "Back":
            return "shoulder and spine"
        case "Biceps", "Triceps":
            return "elbow joint"
        case "Quads", "Hamstrings", "Glutes":
            return "knee and hip"
        case "Calves":
            return "ankle joint"
        default:
            return "joint"
        }
    }
}

// MARK: - Info Sheet Helpers

struct InfoSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Pulse.textTertiary)
                .padding(.horizontal)
            content()
                .padding(.horizontal)
        }
    }
}

struct InfoRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Pulse.textTertiary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 4)
    }
}

struct TagBadge: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Exercise Card

struct ExerciseCardView: View {

    @Environment(AppState.self) private var appState
    var vm: TrainViewModel
    var exercise: ExerciseDefinition
    var state: TrainViewModel.ExerciseState
    var exerciseNumber: Int = 0
    var totalExercises: Int = 0

    @State private var showInfoSheet = false

    // Text-only rows with a repeated generic C/I badge were the single
    // biggest "boring/hard to tell exercises apart at a glance" complaint —
    // reuses the same library-matching + illustration fallback already
    // built for the exercise library and form-guide views, so no new
    // matching logic, just surfacing what already exists here too.
    private var thumbnailExercise: Exercise? {
        ExerciseLibraryMatcher.match(name: exercise.name)
    }

    var body: some View {
        if vm.isSimpleMode {
            simpleBody
        } else {
            fullBody
        }
    }

    private var simpleBody: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topLeading) {
                CachedAsyncImage(
                    url: thumbnailExercise?.thumbnailURL,
                    contentMode: .fill,
                    targetSize: CGSize(width: 44, height: 44),
                    localAssetName: thumbnailExercise?.localIllustrationAssetName
                )
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if exerciseNumber > 0 {
                    Text("\(exerciseNumber)")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(state.allSetsCompleted ? Pulse.positive : vm.selectedDayColor)
                        .clipShape(Circle())
                        .offset(x: -4, y: -4)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(state.allSetsCompleted ? .secondary : .primary)
                    .strikethrough(state.allSetsCompleted)
                HStack(spacing: 6) {
                    Text(exercise.muscleGroup)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Pulse.ai)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Pulse.ai.opacity(0.1))
                        .clipShape(Capsule())
                    Text("\(exercise.sets) sets")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)

                    // Progressive overload in simple mode too
                    if let prev = vm.previousSessionData[exercise.id] {
                        progressiveOverloadBadge(prev: prev)
                    }
                }
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.25)) {
                    vm.completeAllSets(exerciseId: exercise.id)
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(state.allSetsCompleted
                            ? Pulse.positive
                            : Pulse.surfaceElevatedFallback)
                        .frame(width: 56, height: 48)
                    Image(systemName: state.allSetsCompleted ? "checkmark" : "circle")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(state.allSetsCompleted ? .white : .secondary)
                }
            }
            .buttonStyle(PulsePress())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            state.allSetsCompleted
                ? Pulse.positive.opacity(0.06)
                : Pulse.surfaceFallback
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    state.allSetsCompleted
                        ? Pulse.positive.opacity(0.4)
                        : Color.clear,
                    lineWidth: 2
                )
        )
    }

    private var fullBody: some View {
        VStack(spacing: 0) {

            // MARK: Header
            HStack(alignment: .center, spacing: 10) {

                // Thumbnail
                ZStack(alignment: .topLeading) {
                    CachedAsyncImage(
                        url: thumbnailExercise?.thumbnailURL,
                        contentMode: .fill,
                        targetSize: CGSize(width: 44, height: 44),
                        localAssetName: thumbnailExercise?.localIllustrationAssetName
                    )
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                state.allSetsCompleted
                                    ? Pulse.positive.opacity(0.5)
                                    : vm.selectedDayColor.opacity(0.15),
                                lineWidth: 1.5
                            )
                    )

                    if exerciseNumber > 0 {
                        Text("\(exerciseNumber)")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(state.allSetsCompleted ? Pulse.positive : vm.selectedDayColor)
                            .clipShape(Circle())
                            .offset(x: -4, y: -4)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(exercise.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(state.allSetsCompleted ? .secondary : .primary)
                            .lineLimit(2)
                        if exercise.supersetGroup != nil {
                            Text("SS")
                                .font(.system(size: 8, weight: .black))
                                .foregroundColor(Pulse.ai)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Pulse.ai.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    HStack(spacing: 6) {
                        Text(exercise.muscleGroup)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(vm.selectedDayColor)
                        Text("·")
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("\(exercise.sets)×\(exercise.repRange.display)")
                            .font(.system(size: 10))
                            .foregroundColor(Pulse.textTertiary)
                        if !state.isExpanded && state.completedSetsCount > 0 {
                            Text("·")
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("\(state.completedSetsCount)/\(exercise.sets)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(state.allSetsCompleted ? Pulse.positive : vm.selectedDayColor)
                        }
                    }

                    // Progressive overload indicator (visible in collapsed state)
                    if let prev = vm.previousSessionData[exercise.id] {
                        progressiveOverloadBadge(prev: prev)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Three-dot menu (competitor standard)
                Menu {
                    if !exercise.alternatives.isEmpty {
                        Section("Swap exercise") {
                            ForEach(exercise.alternatives, id: \.self) { alt in
                                Button(alt) {
                                    vm.swapExerciseForToday(exerciseId: exercise.id, to: alt)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                        }
                    }
                    if vm.isSessionActive {
                        Section {
                            if exerciseNumber > 1 {
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        vm.moveExercise(from: exerciseNumber - 1, by: -1)
                                    }
                                } label: {
                                    Label("Move up", systemImage: "arrow.up")
                                }
                            }
                            if exerciseNumber < totalExercises {
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        vm.moveExercise(from: exerciseNumber - 1, by: 1)
                                    }
                                } label: {
                                    Label("Move down", systemImage: "arrow.down")
                                }
                            }
                        }
                    }
                    Button {
                        showInfoSheet = true
                    } label: {
                        Label("Exercise info", systemImage: "info.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Pulse.textTertiary)
                        .frame(width: 32, height: 32)
                }

                Image(systemName: state.isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Pulse.textTertiary)
                    .frame(width: 20)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    vm.toggleExpanded(exerciseId: exercise.id)
                }
            }

            // MARK: Expanded Content
            if state.isExpanded {
                VStack(spacing: 0) {

                    Divider().padding(.horizontal, 14)

                    if exercise.isJointSensitive && appState.isFlareDay {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Pulse.warning)
                                .font(.caption)
                            Text("Joint sensitive — load reduced for flare day")
                                .font(.caption)
                                .foregroundColor(Pulse.warning)
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                    }

                    if let prev = vm.previousSessionData[exercise.id] {
                        // Previous cable variant
                        if prev.cableAttachment != nil || prev.cablePosition != nil {
                            HStack(spacing: 6) {
                                Image(systemName: "cable.connector")
                                    .font(.system(size: 9))
                                let parts = [
                                    prev.cableAttachment?.displayName,
                                    prev.cablePosition.map { "\($0.displayName) cable" }
                                ].compactMap { $0 }
                                Text("Last: \(parts.joined(separator: " · "))")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(vm.selectedDayColor.opacity(0.7))
                            .padding(.horizontal, 14)
                            .padding(.top, 6)
                        }
                        // Previous note
                        if !prev.note.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 9))
                                Text("Last: \(prev.note)")
                                    .font(.system(size: 11))
                                    .lineLimit(2)
                            }
                            .foregroundColor(Pulse.textTertiary)
                            .padding(.horizontal, 14)
                            .padding(.top, prev.cableAttachment != nil || prev.cablePosition != nil ? 2 : 6)
                        }
                    }

                    // Cable variant picker (attachment + position)
                    if CableExerciseDetector.isCableExercise(name: exercise.name) {
                        CableVariantPicker(
                            exerciseId: exercise.id,
                            attachment: state.cableAttachment,
                            position: state.cablePosition,
                            accentColor: vm.selectedDayColor,
                            onAttachmentChanged: { vm.updateCableAttachment(exerciseId: exercise.id, attachment: $0) },
                            onPositionChanged: { vm.updateCablePosition(exerciseId: exercise.id, position: $0) }
                        )
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                    }

                    // Column headers (Hevy/Strong style)
                    HStack(spacing: 0) {
                        Text("SET")
                            .frame(width: 36, alignment: .center)
                        if exercise.measurement.showsWeightField {
                            Text("PREVIOUS")
                                .frame(maxWidth: .infinity)
                            Text(AssistedExerciseDetector.isAssisted(name: exercise.name)
                                 ? "ASSIST"
                                 : (appState.profile.prefersLbs ? "LBS" : "KG"))
                                .frame(maxWidth: .infinity)
                            Text("REPS")
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("PREVIOUS")
                                .frame(maxWidth: .infinity)
                            Text(exercise.measurement == .timed ? "SEC" : "REPS")
                                .frame(maxWidth: .infinity)
                        }
                        Color.clear.frame(width: 44)
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 4)

                    ForEach(state.sets.indices, id: \.self) { i in
                        HStack(spacing: 0) {
                            SetRowView(
                                vm: vm,
                                exercise: exercise,
                                setIndex: i,
                                setState: state.sets[i],
                                sessionColor: vm.selectedDayColor,
                                previousWeight: vm.previousSessionData[exercise.id]?.weightKg,
                                previousReps: vm.previousSessionData[exercise.id]?.reps
                            )
                            if state.sets.count > 1 {
                                Button {
                                    withAnimation(.spring(response: 0.25)) {
                                        vm.removeSet(from: exercise.id, setIndex: i)
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.secondary.opacity(0.4))
                                        .frame(width: 20, height: 20)
                                }
                                .buttonStyle(PulsePress())
                            }
                        }
                        .padding(.horizontal, 14)
                    }

                    // Actions row
                    HStack(spacing: 10) {
                        Button {
                            vm.addSet(to: exercise.id)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Set")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(vm.selectedDayColor)
                        }
                        .buttonStyle(PulsePress())

                        if vm.isSessionActive && exercise.measurement.showsWeightField {
                            Button {
                                vm.addDropSet(to: exercise.id)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.down.right")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("Drop")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(Pulse.critical)
                            }
                            .buttonStyle(PulsePress())

                            Button {
                                vm.addAMRAPSet(to: exercise.id)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "flame")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("AMRAP")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(Pulse.ai)
                            }
                            .buttonStyle(PulsePress())
                        }

                        if state.sets.count > 1 {
                            Button {
                                if let w = state.sets.first?.weightKg {
                                    vm.applyWeightToAllSets(exerciseId: exercise.id, weight: w)
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.down.to.line")
                                        .font(.system(size: 9))
                                    Text("Copy")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(Pulse.textTertiary)
                            }
                            .buttonStyle(PulsePress())
                        }

                        Spacer()

                        FormGuideButton(
                            exerciseName: exercise.name,
                            tint: vm.selectedDayColor
                        )
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 4)

                    if vm.isSessionActive {
                        HStack(spacing: 6) {
                            Image(systemName: "note.text")
                                .font(.system(size: 10))
                                .foregroundColor(Pulse.textTertiary)
                            TextField("Add a note…", text: Binding(
                                get: { state.note },
                                set: { vm.updateNote(exerciseId: exercise.id, note: $0) }
                            ))
                            .font(.system(size: 12))
                            .foregroundColor(Pulse.textPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                    } else {
                        Spacer().frame(height: 8)
                    }
                }
            }
        }
        .background(Pulse.surfaceFallback)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    state.allSetsCompleted
                        ? Pulse.positive.opacity(0.4)
                        : Color.clear,
                    lineWidth: 2
                )
        )
        .sheet(isPresented: $showInfoSheet) {
            ExerciseInfoSheet(
                exercise: exercise,
                sessionColor: vm.selectedDay.color
            )
        }
    }

    // MARK: - Progressive Overload Badge
    /// Shows last session weight × reps and progression direction in the collapsed card header.
    /// Benchmarked against Strong (shows "Previous" column) and Hevy (shows PR badges).
    /// Making this visible without expanding solves the user complaint that progressive
    /// overload data is buried too deep.
    @ViewBuilder
    private func progressiveOverloadBadge(prev: TrainViewModel.PreviousExerciseData) -> some View {
        let useLbs = appState.profile.prefersLbs
        let displayWeight = useLbs ? prev.rawWeightKg * 2.20462 : prev.rawWeightKg
        let weightUnit = useLbs ? "lbs" : "kg"
        let hasProgression = prev.incrementKg > 0

        HStack(spacing: 4) {
            Image(systemName: hasProgression ? "arrow.up.right" : "arrow.right")
                .font(.system(size: 7, weight: .black))
                .foregroundColor(hasProgression ? Pulse.positive : Pulse.textTertiary)

            if prev.rawWeightKg > 0 {
                Text("\(formatWeight(displayWeight))\(weightUnit) × \(prev.reps)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(hasProgression ? Pulse.positive : Pulse.textSecondary)
                    .monospacedDigit()
            } else {
                // Bodyweight / timed exercises — show reps only
                Text("\(prev.reps) reps")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(hasProgression ? Pulse.positive : Pulse.textSecondary)
            }

            if hasProgression {
                Text("↑")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(Pulse.positive)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            (hasProgression ? Pulse.positive : Pulse.textTertiary)
                .opacity(0.08)
        )
        .clipShape(Capsule())
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", w)
            : String(format: "%.1f", w)
    }
}

// MARK: - Set Row (Hevy/Strong-style flat table)

struct SetRowView: View {

    @Environment(AppState.self) private var appState
    var vm: TrainViewModel
    var exercise: ExerciseDefinition
    var setIndex: Int
    var setState: TrainViewModel.SetState
    var sessionColor: Color
    var previousWeight: Double?
    var previousReps: Int?

    @State private var showPad = false
    @State private var padWeight: Double = 0
    @State private var padReps: Int = 0
    @State private var swipeOffset: CGFloat = 0

    private var useLbs: Bool {
        appState.profile.prefersLbs
    }

    private func displayWeight(_ kg: Double) -> Double {
        useLbs ? kg * 2.20462 : kg
    }

    private var setTypeLabel: String {
        switch setState.setType {
        case .working: return "\(setState.setNumber)"
        case .warmup: return "W"
        case .dropSet: return "DROP"
        case .amrap: return "MAX"
        }
    }

    private var setTypeColor: Color {
        switch setState.setType {
        case .working: return setState.isCompleted ? sessionColor : .secondary
        case .warmup: return Pulse.nutrition
        case .dropSet: return Pulse.critical
        case .amrap: return Pulse.ai
        }
    }

    private var previousText: String? {
        guard let pw = previousWeight, let pr = previousReps else { return nil }
        if exercise.measurement.showsWeightField {
            return "\(formatWeight(displayWeight(pw))) × \(pr)"
        }
        return "\(pr)"
    }

    /// True when there's a source to copy from — either the set above
    /// is completed, or there's previous session data for set 0.
    private var canRepeat: Bool {
        if setIndex > 0 {
            guard let state = vm.exerciseStates[exercise.id] else { return false }
            return state.sets[setIndex - 1].isCompleted
        }
        return vm.previousSessionData[exercise.id] != nil
    }

    private var isPR: Bool {
        guard setState.isCompleted,
              exercise.measurement.showsWeightField,
              setState.weightKg > 0,
              let pw = previousWeight else { return false }
        let currentE1RM = setState.weightKg * (1 + Double(setState.reps) / 30.0)
        let prevE1RM = pw * (1 + Double(previousReps ?? 1) / 30.0)
        return currentE1RM > prevE1RM
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {

                // Set number — tap to cycle type (working/warmup/drop/amrap)
                Button {
                    vm.cycleSetType(exerciseId: exercise.id, setIndex: setIndex)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(spacing: 1) {
                        Text(setTypeLabel)
                            .font(.system(size: setState.setType == .working ? 14 : 10, weight: .bold))
                            .monospacedDigit()
                            .foregroundColor(setTypeColor)
                    }
                    .frame(width: 36, alignment: .center)
                }
                .buttonStyle(PulsePress())

                // Previous column — tap to auto-fill
                if let prevText = previousText {
                    Button {
                        if let pw = previousWeight { vm.updateWeight(exerciseId: exercise.id, setIndex: setIndex, weight: pw) }
                        if let pr = previousReps { vm.updateReps(exerciseId: exercise.id, setIndex: setIndex, reps: pr) }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(prevText)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.6))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PulsePress())
                } else {
                    Text("—")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.3))
                        .frame(maxWidth: .infinity)
                }

                // Weight + Reps — tap to open number pad
                Button {
                    padWeight = setState.weightKg
                    padReps = setState.reps
                    showPad = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 6) {
                        if exercise.measurement.showsWeightField {
                            Text(formatWeight(displayWeight(setState.weightKg)))
                                .font(.system(size: 15, weight: .semibold))
                                .monospacedDigit()
                                .foregroundColor(setState.isCompleted ? .secondary : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    setState.isCompleted
                                        ? sessionColor.opacity(0.06)
                                        : Pulse.surfaceElevatedFallback
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        Text("\(setState.reps)")
                            .font(.system(size: 15, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(setState.isCompleted ? .secondary : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                setState.isCompleted
                                    ? sessionColor.opacity(0.06)
                                    : Pulse.surfaceElevatedFallback
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .buttonStyle(PulsePress())

                // Quick repeat: one-tap "same as above & done"
                if vm.isSessionActive && !setState.isCompleted && canRepeat {
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            vm.repeatAndComplete(
                                exerciseId: exercise.id,
                                setIndex: setIndex,
                                exercise: exercise,
                                sessionColor: sessionColor,
                                profile: appState.profile
                            )
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        vm.pushWatchSnapshot()
                    } label: {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(sessionColor.opacity(0.5))
                            .frame(width: 28, height: 44)
                    }
                    .buttonStyle(PulsePress())
                    .accessibilityLabel("Repeat and complete")
                }

                // Checkmark
                Button {
                    withAnimation(.spring(response: 0.25)) {
                        vm.toggleSet(exerciseId: exercise.id, setIndex: setIndex)
                    }
                    UIImpactFeedbackGenerator(
                        style: setState.isCompleted ? .light : .medium
                    ).impactOccurred()
                    if !setState.isCompleted, !vm.skipsRestTimer(afterExerciseId: exercise.id) {
                        let smartRest = RestTimerManager.smartRest(
                            for: exercise,
                            history: RestTimerManager.shared.restHistory[exercise.id],
                            currentHR: LiveHRManager.shared.currentBPM,
                            peakHR: RestTimerManager.shared.peakBPM,
                            lastSetRPE: setState.rpe,
                            lastSetWeightKg: setState.weightKg
                        )
                        RestTimerManager.shared.start(
                            seconds: smartRest,
                            exerciseName: exercise.name,
                            sessionColor: sessionColor,
                            profile: appState.profile,
                            exerciseId: exercise.id
                        )
                        vm.pushWatchSnapshot()
                    }
                } label: {
                    Image(systemName: setState.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(setState.isCompleted ? sessionColor : .secondary.opacity(0.4))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(PulsePress())
            }

            // HR + 1RM + PR + RPE shown inline below the row when completed
            if setState.isCompleted {
                HStack(spacing: 8) {
                    if isPR {
                        Text("PR")
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Pulse.positive)
                            .clipShape(Capsule())
                    }
                    if exercise.measurement.showsWeightField,
                       setState.weightKg > 0,
                       setState.reps > 1 && setState.reps <= 12 {
                        let oneRM = setState.weightKg * (1 + Double(setState.reps) / 30.0)
                        let displayRM = displayWeight(oneRM)
                        Text("e1RM \(String(format: "%.0f", displayRM)) \(useLbs ? "lbs" : "kg")")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(Pulse.hydration)
                    }
                    if setState.peakHR != nil || setState.avgHR != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 7))
                                .foregroundColor(.red)
                            if let peak = setState.peakHR {
                                Text("\(peak)")
                                    .font(.system(size: 9, weight: .bold))
                                    .monospacedDigit()
                            }
                            if let avg = setState.avgHR {
                                Text("avg \(avg)")
                                    .font(.system(size: 8))
                                    .foregroundColor(Pulse.textTertiary)
                            }
                        }
                    }

                    // Inline RPE selector
                    RPEChipSelector(
                        rpe: Binding(
                            get: { setState.rpe },
                            set: { vm.updateRPE(exerciseId: exercise.id, setIndex: setIndex, rpe: $0) }
                        )
                    )

                    Spacer()
                }
                .padding(.leading, 36)
                .padding(.top, 1)
                .padding(.bottom, 2)
            }
        }
        .padding(.vertical, 2)
        .background(
            ZStack(alignment: .leading) {
                // Swipe-to-complete reveal layer
                if vm.isSessionActive && !setState.isCompleted && swipeOffset > 0 {
                    Pulse.positive
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Done")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.leading, 12)
                }

                // Normal background
                Rectangle()
                    .fill(
                        setState.setType == .warmup
                            ? Pulse.nutrition.opacity(0.04)
                            : setState.setType == .dropSet
                                ? Pulse.critical.opacity(0.04)
                                : setState.setType == .amrap
                                    ? Pulse.ai.opacity(0.04)
                                    : setState.isCompleted
                                        ? sessionColor.opacity(0.04)
                                        : Pulse.surfaceFallback
                    )
                    .offset(x: swipeOffset)
            }
        )
        .offset(x: swipeOffset)
        .gesture(
            vm.isSessionActive && !setState.isCompleted
            ? DragGesture(minimumDistance: 20)
                .onChanged { value in
                    if value.translation.width > 0 {
                        swipeOffset = min(value.translation.width, 100)
                    }
                }
                .onEnded { value in
                    if value.translation.width > 80 {
                        // Complete the set via swipe
                        withAnimation(.spring(response: 0.25)) {
                            swipeOffset = 0
                            vm.toggleSet(exerciseId: exercise.id, setIndex: setIndex)
                        }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        if !vm.skipsRestTimer(afterExerciseId: exercise.id) {
                            RestTimerManager.shared.start(
                                seconds: RestTimerManager.defaultRest(for: exercise),
                                exerciseName: exercise.name,
                                sessionColor: sessionColor,
                                profile: appState.profile
                            )
                            vm.pushWatchSnapshot()
                        }
                    } else {
                        withAnimation(.spring(response: 0.3)) {
                            swipeOffset = 0
                        }
                    }
                }
            : nil
        )
        .clipped()
        .sheet(isPresented: $showPad, onDismiss: {
            vm.updateWeight(exerciseId: exercise.id, setIndex: setIndex, weight: padWeight)
            vm.updateReps(exerciseId: exercise.id, setIndex: setIndex, reps: padReps)
        }) {
            NumberPadSheet(
                isPresented: $showPad,
                weight: $padWeight,
                reps: $padReps,
                setNumber: setState.setNumber,
                totalSets: exercise.sets,
                exerciseName: exercise.name,
                sessionColor: sessionColor,
                measurement: exercise.measurement,
                previousWeight: previousWeight,
                previousReps: previousReps,
                onComplete: {
                    vm.updateWeight(exerciseId: exercise.id, setIndex: setIndex, weight: padWeight)
                    vm.updateReps(exerciseId: exercise.id, setIndex: setIndex, reps: padReps)
                    withAnimation(.spring(response: 0.25)) {
                        if !setState.isCompleted {
                            vm.toggleSet(exerciseId: exercise.id, setIndex: setIndex)
                            if !vm.skipsRestTimer(afterExerciseId: exercise.id) {
                                RestTimerManager.shared.start(
                                    seconds: RestTimerManager.defaultRest(for: exercise),
                                    exerciseName: exercise.name,
                                    sessionColor: sessionColor,
                                    profile: appState.profile
                                )
                                vm.pushWatchSnapshot()
                            }
                        }
                    }
                }
            )
        }
    }

    private func formatWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        // Show one decimal for .5 increments, two for .25/.75
        let oneDecimal = (value * 10).rounded() / 10
        if abs(value - oneDecimal) < 0.01 {
            return String(format: "%.1f", value)
        }
        return String(format: "%.2f", value)
    }
}

// MARK: - RPE Chip Selector

struct RPEChipSelector: View {

    @Binding var rpe: Int

    private let options = [6, 7, 8, 9, 10]

    var body: some View {
        HStack(spacing: 3) {
            Text("RPE")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Pulse.textTertiary)

            ForEach(options, id: \.self) { value in
                Button {
                    rpe = rpe == value ? 0 : value
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text("\(value)")
                        .font(.system(size: 9, weight: rpe == value ? .black : .medium))
                        .foregroundColor(rpe == value ? .white : rpeColor(value))
                        .frame(width: 18, height: 16)
                        .background(
                            rpe == value
                                ? rpeColor(value)
                                : rpeColor(value).opacity(0.1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(PulsePress())
            }
        }
    }

    private func rpeColor(_ value: Int) -> Color {
        switch value {
        case 6: return Pulse.positive
        case 7: return Pulse.positive
        case 8: return Pulse.nutrition
        case 9: return Pulse.critical
        case 10: return Pulse.critical
        default: return .secondary
        }
    }
}

// MARK: - Cable Variant Picker
//
// Compact inline picker for cable attachment and pulley position.
// Shows only for cable exercises (detected by CableExerciseDetector).

struct CableVariantPicker: View {
    let exerciseId: String
    let attachment: CableAttachment?
    let position: CablePosition?
    let accentColor: Color
    let onAttachmentChanged: (CableAttachment?) -> Void
    let onPositionChanged: (CablePosition?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Attachment row
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 9))
                    .foregroundColor(Pulse.textTertiary)
                Text("ATTACH")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Pulse.textTertiary)
                    .tracking(0.5)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(CableAttachment.allCases) { att in
                            cableChip(
                                label: att.displayName,
                                icon: att.icon,
                                isSelected: attachment == att,
                                color: accentColor
                            ) {
                                onAttachmentChanged(attachment == att ? nil : att)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                    }
                }
            }

            // Position row
            HStack(spacing: 6) {
                Image(systemName: "slider.vertical.3")
                    .font(.system(size: 9))
                    .foregroundColor(Pulse.textTertiary)
                Text("HEIGHT")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Pulse.textTertiary)
                    .tracking(0.5)

                HStack(spacing: 4) {
                    ForEach(CablePosition.allCases) { pos in
                        cableChip(
                            label: pos.displayName,
                            icon: pos.icon,
                            isSelected: position == pos,
                            color: accentColor
                        ) {
                            onPositionChanged(position == pos ? nil : pos)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(accentColor.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func cableChip(label: String, icon: String, isSelected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
            }
            .foregroundColor(isSelected ? .white : Pulse.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isSelected ? color : Pulse.surfaceFallback)
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
