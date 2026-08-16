import SwiftUI
import SwiftData
import Combine

struct TrainView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var vm: TrainViewModel? = nil
    @State private var showDiscardConfirm = false
    @State private var showCompleteSheet = false
    @State private var showReflectionSheet = false
    @State private var showFlareToggle = false
    @State private var showLibrary = false
    @State private var showSessionEditor = false
    @State private var showDaysManager = false
    @State private var showProgramPicker = false
    @State private var sessionDurationTicker: Int = 0
    @State private var showTrainingCoach = false
    @State private var coachProfile: PersonProfile? = nil
    @State private var showAddExerciseForToday = false
    @State private var showMobilityCheckIn = false
    @State private var hasTodaysMobilityCheckIn = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            ScrollViewReader { scrollProxy in
            ScrollView {
                if let vm = vm {
                    VStack(spacing: 14) {

                        // Active session live header
                        if vm.isSessionActive {
                            SessionLiveHeader(vm: vm, ticker: sessionDurationTicker)
                        }

                        // Rest timer — the most critical mid-session feature
                        if RestTimerManager.shared.isActive {
                            RestTimerBar(manager: RestTimerManager.shared)
                                .id("restTimer")
                        }

                        // Live comparison vs last session
                        if vm.isSessionActive {
                            SessionComparisonBanner(vm: vm, ticker: sessionDurationTicker)
                        }

                        // Pre-session context (hidden during active session to reduce noise)
                        if !vm.isSessionActive {
                            // Deload alert — only shows during deload weeks
                            DeloadCard(onChanged: {
                                Task {
                                    await vm.loadRecoveryContext(
                                        context: modelContext,
                                        appState: appState
                                    )
                                }
                            })
                        }

                        DayPickerBar(vm: vm, modelContext: modelContext)

                        if !vm.isSessionActive {
                            // Unified day header with inline recovery + quick-switch
                            DayHeaderCard(
                                vm: vm,
                                adjustment: vm.currentAdjustment,
                                showQuickSwitch: {
                                    if let adj = vm.currentAdjustment {
                                        return (adj.severity == .caution || adj.severity == .deload)
                                            && vm.fullExerciseCountBeforeQuickMode == nil
                                    }
                                    return false
                                }(),
                                onQuickSwitch: { vm.applyQuickSessionMode() },
                                isFlareDay: appState.flareEngineEnabled && appState.isFlareDay,
                                flareText: appState.flareWarningText
                            )

                            // Secondary context — collapsed to keep focus on exercises
                            PreSessionContextSection(
                                vm: vm,
                                hasMobilityCheckIn: hasTodaysMobilityCheckIn,
                                coachProfile: coachProfile,
                                onMobilityOpen: { showMobilityCheckIn = true },
                                onCoachOpen: { showTrainingCoach = true },
                                onRebuilt: { vm.reloadDays(context: modelContext) }
                            )
                        } else if appState.flareEngineEnabled && appState.isFlareDay {
                            FlareNotice(text: appState.flareWarningText)
                        }

                        if vm.orderedExercises.isEmpty {
                            EmptyDayCard(
                                dayName: vm.selectedDay.name,
                                dayColor: vm.selectedDay.color,
                                onCompose: { showSessionEditor = true }
                            )
                        }

                        ForEach(Array(vm.orderedExercises.enumerated()), id: \.element.id) { index, exercise in
                            if let state = vm.exerciseStates[exercise.id] {
                                ExerciseCardView(
                                    vm: vm,
                                    exercise: exercise,
                                    state: state,
                                    exerciseNumber: index + 1,
                                    totalExercises: vm.orderedExercises.count
                                )
                            }
                        }

                        if vm.isSessionActive {
                            Button {
                                showAddExerciseForToday = true
                            } label: {
                                Label("Add exercise for today", systemImage: "plus.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(vm.selectedDay.color)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(vm.selectedDay.color.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(vm.selectedDay.color.opacity(0.25), lineWidth: 1)
                                    )
                            }
                        }

                        Spacer().frame(height: 12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .frame(width: geo.size.width)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                }
            }
            .onChange(of: RestTimerManager.shared.isActive) { _, isActive in
                if isActive {
                    withAnimation(.easeOut(duration: 0.3)) {
                        scrollProxy.scrollTo("restTimer", anchor: .top)
                    }
                }
            }
            }
            }
            .navigationTitle("Train")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                if let vm = vm, !vm.orderedExercises.isEmpty {
                    BottomActionBar(
                        vm: vm,
                        onStart: {
                            vm.isSimpleMode = false
                            vm.startSession(appState: appState)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        },
                        onStartSimple: {
                            vm.isSimpleMode = true
                            vm.startSession(appState: appState)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        },
                        onDiscard: { showDiscardConfirm = true },
                        onComplete: { showCompleteSheet = true }
                    )
                }
            }
            .toolbar {
                // A single labeled "Manage" menu replaces 4 unlabeled icon
                // buttons. Research basis: NN/g finds icons alone rarely
                // communicate meaning ("it's really rare for icons to stand
                // on their own"), and a 179-participant NN/g usability study
                // found icon-only navigation had the lowest usage (44%) and
                // slowest time-to-navigate of all sites tested. Material
                // Design's guidance for several disparate actions with no
                // single obvious entry point is to consolidate them into one
                // labeled menu/list rather than a row of icons. The flare
                // toggle stays separate and icon-only since its two states
                // are already visually distinct (fill + color change), not
                // dependent on glyph recognition alone.
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showProgramPicker = true
                        } label: {
                            Label("Choose a Program", systemImage: "list.clipboard")
                        }
                        .disabled(vm?.isSessionActive == true)

                        Button {
                            showDaysManager = true
                        } label: {
                            Label("Manage Training Days", systemImage: "calendar.badge.plus")
                        }
                        .disabled(vm?.isSessionActive == true)

                        Button {
                            showSessionEditor = true
                        } label: {
                            Label("Customize Today's Exercises", systemImage: "slider.horizontal.3")
                        }
                        .disabled(vm?.isSessionActive == true)

                        Button {
                            showLibrary = true
                        } label: {
                            Label("Exercise Library", systemImage: "books.vertical")
                        }
                    } label: {
                        Label("Manage", systemImage: "ellipsis.circle")
                            .labelStyle(.titleAndIcon)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Manage training")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if appState.flareEngineEnabled {
                        Button {
                            showFlareToggle = true
                        } label: {
                            Image(systemName: appState.isFlareDay
                                  ? "exclamationmark.triangle.fill"
                                  : "exclamationmark.triangle")
                                .foregroundColor(appState.isFlareDay
                                    ? Color(hex: "B45309")
                                    : .secondary)
                        }
                        .accessibilityLabel(appState.isFlareDay ? "Flare day is on" : "Toggle flare day")
                    }
                }
            }
            .alert("Discard this session?", isPresented: $showDiscardConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    vm?.discardSession(appState: appState)
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            } message: {
                Text("All logged sets for this session will be lost.")
            }
            .sheet(isPresented: $showCompleteSheet) {
                if let vm = vm {
                    CompleteSessionSheet(
                        vm: vm,
                        onConfirm: {
                            vm.completeSession(context: modelContext)
                            showCompleteSheet = false
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showReflectionSheet = true
                            }
                        },
                        onCancel: { showCompleteSheet = false }
                    )
                }
            }
            .sheet(isPresented: $showReflectionSheet) {
                if let session = vm?.completedSession {
                    ReflectionSheet(session: session)
                }
            }
            .sheet(isPresented: $showLibrary) {
                ExerciseLibraryView()
            }
            .sheet(isPresented: $showSessionEditor) {
                if let vm = vm {
                    SessionComposerView(
                        dayCode: vm.selectedDay.code,
                        dayName: vm.selectedDay.name,
                        dayColor: vm.selectedDay.color,
                        onSave: {
                            vm.buildExerciseStates(context: modelContext)
                            vm.loadPreviousSession(context: modelContext)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    )
                }
            }
            .sheet(isPresented: $showDaysManager) {
                SessionDaysManagerView(onSave: {
                    vm?.reloadDays(context: modelContext)
                })
            }
            .sheet(isPresented: $showMobilityCheckIn) {
                MobilityCheckInSheet(onSaved: { hasTodaysMobilityCheckIn = true })
            }
            .sheet(isPresented: $showProgramPicker) {
                ProgramTemplatePickerView(onInstalled: {
                    vm?.reloadDays(context: modelContext)
                })
            }
            .sheet(isPresented: $showTrainingCoach) {
                if let coachProfile {
                    TrainingCoachView(profile: coachProfile, onProgramRebuilt: {
                        vm?.reloadDays(context: modelContext)
                    })
                }
            }
            .sheet(isPresented: $showAddExerciseForToday) {
                LibraryPickerSheet { picked in
                    vm?.addExerciseForToday(picked)
                }
            }
            .confirmationDialog(
                "Flare day",
                isPresented: $showFlareToggle,
                titleVisibility: .visible
            ) {
                Button(appState.isFlareDay ? "Turn off flare day" : "Turn on flare day") {
                    appState.isFlareDay.toggle()
                    vm?.updateFlareDay(appState.isFlareDay)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Flare day reduces suggested weights by 25% and marks the session for pattern learning.")
            }
        }
        .onAppear {
            if vm == nil {
                let newVM = TrainViewModel(appState: appState)
                newVM.configure(context: modelContext)
                vm = newVM
            }
            if coachProfile == nil {
                coachProfile = ProfileStore.current(context: modelContext)
            }
            hasTodaysMobilityCheckIn = MobilityStore.todaysCheckIn(context: modelContext) != nil
            WatchSessionManager.shared.onSetLogged = { [weak vm] weightKg, reps in
                vm?.logSetFromWatch(weightKg: weightKg, reps: reps)
            }
            WatchSessionManager.shared.onSkipRestRequested = {
                RestTimerManager.shared.skip()
            }
            WatchSessionManager.shared.onEndSessionRequested = { [weak vm] in
                guard let vm, vm.isSessionActive else { return }
                vm.completeSession(context: modelContext)
            }
            Task {
                await vm?.loadRecoveryContext(
                    context: modelContext,
                    appState: appState
                )
            }
        }
        .onReceive(timer) { _ in
            sessionDurationTicker += 1
        }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in
            vm?.reloadDays(context: modelContext)
            Task {
                await vm?.loadRecoveryContext(
                    context: modelContext,
                    appState: appState
                )
            }
        }
    }
}

// MARK: - Day Picker

struct DayPickerBar: View {
    var vm: TrainViewModel
    var modelContext: ModelContext

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.availableDays, id: \.code) { day in
                    let isSelected = vm.selectedDay.code == day.code
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            vm.switchDay(to: day, context: modelContext)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 3) {
                            Text(day.code)
                                .font(.headline.bold())
                            Text(day.name.split(separator: " ").first.map(String.init) ?? day.name)
                                .font(.system(size: 9, weight: .semibold))
                                .lineLimit(1)
                        }
                        .frame(width: 60, height: 50)
                        .background(isSelected ? day.color : Color(.secondarySystemBackground))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }
}

// MARK: - Day Header Card

struct DayHeaderCard: View {
    var vm: TrainViewModel
    var adjustment: RecoveryAdjuster.Adjustment? = nil
    var showQuickSwitch: Bool = false
    var onQuickSwitch: (() -> Void)? = nil
    var isFlareDay: Bool = false
    var flareText: String = ""

    private var focusMode: FocusModeManager { .shared }

    @State private var recoveryExpanded = false

    var estimatedMinutes: Int {
        let totalSets = vm.orderedExercises.reduce(0) { $0 + $1.sets }
        return Int(Double(totalSets) * 2.5)
    }

    private var totalSets: Int {
        vm.orderedExercises.reduce(0) { $0 + $1.sets }
    }

    private var muscleGroups: [String] {
        let groups = vm.orderedExercises.map(\.muscleGroup)
        var seen = Set<String>()
        return groups.filter { seen.insert($0).inserted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title + stats row
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(vm.selectedDay.color)
                    .frame(width: 5, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(vm.selectedDay.name)
                        .font(.title3.bold())
                    Text(vm.selectedDay.focus)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(vm.selectedDay.color)
                }

                Spacer()

                if !vm.orderedExercises.isEmpty {
                    HStack(spacing: 12) {
                        VStack(spacing: 1) {
                            Text("\(vm.orderedExercises.count)")
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                            Text("exercises")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        VStack(spacing: 1) {
                            Text("\(totalSets)")
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                            Text("sets")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        VStack(spacing: 1) {
                            Text("~\(estimatedMinutes)m")
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                            Text("est. time")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Muscle group chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(muscleGroups, id: \.self) { group in
                        Text(group)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(vm.selectedDay.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(vm.selectedDay.color.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    if focusMode.isEnabled {
                        HStack(spacing: 4) {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 8))
                            Text("Focus")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "8B5CF6"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "8B5CF6").opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }

            // Flare day warning — inline
            if isFlareDay && !flareText.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "B45309"))
                    Text(flareText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "B45309"))
                        .lineLimit(1)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "B45309").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Recovery adjustment — inline, expandable
            if let adjustment {
                VStack(spacing: 0) {
                    Button {
                        withAnimation(.spring(response: 0.25)) { recoveryExpanded.toggle() }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: adjustment.severity.icon)
                                .font(.system(size: 12))
                                .foregroundColor(adjustment.severity.color)
                            Text(adjustment.multiplier > 1.0 ? "Primed" : adjustment.severity.label)
                                .font(.system(size: 12, weight: .bold))
                            Text(adjustment.signedPercentLabel)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(adjustment.severity.color)
                            Spacer()
                            Text("\(adjustment.reasons.count) signal\(adjustment.reasons.count == 1 ? "" : "s")")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Image(systemName: recoveryExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if recoveryExpanded {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(adjustment.reasons) { reason in
                                HStack(spacing: 8) {
                                    Image(systemName: reason.icon)
                                        .font(.system(size: 10))
                                        .foregroundColor(adjustment.severity.color)
                                        .frame(width: 16)
                                    Text(reason.text)
                                        .font(.system(size: 11))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(10)
                .background(adjustment.severity.color.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(adjustment.severity.color.opacity(0.2), lineWidth: 1)
                )

                // Quick session switch — compact inline
                if showQuickSwitch, let onQuickSwitch {
                    Button(action: onQuickSwitch) {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "8B5CF6"))
                            Text("Switch to 20-min compounds-only session")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "8B5CF6"))
                            Spacer()
                            Text("Switch")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(hex: "8B5CF6"))
                                .clipShape(Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    .background(Color(hex: "8B5CF6").opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Session Live Header (during active session)

struct SessionLiveHeader: View {
    @Environment(AppState.self) private var appState
    var vm: TrainViewModel
    var ticker: Int

    private var totalSets: Int {
        vm.orderedExercises.reduce(0) { $0 + $1.sets }
    }

    private var progress: Double {
        guard totalSets > 0 else { return 0 }
        return Double(vm.totalCompletedSets) / Double(totalSets)
    }

    private var totalVolumeKg: Double {
        vm.orderedExercises.reduce(0.0) { total, ex in
            guard let state = vm.exerciseStates[ex.id] else { return total }
            return total + state.sets.filter { $0.isCompleted }.reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
        }
    }

    private var totalVolume: Double {
        appState.profile.prefersLbs ? totalVolumeKg * 2.20462 : totalVolumeKg
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                // Duration + pause
                HStack(spacing: 8) {
                    if vm.isSessionPaused {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "F59E0B"))
                    } else {
                        Circle()
                            .fill(Color(hex: "059669"))
                            .frame(width: 8, height: 8)
                            .modifier(PulseModifier())
                    }
                    let _ = ticker
                    Text(vm.sessionDurationFormatted)
                        .font(.system(size: 24, weight: .bold).monospacedDigit())
                        .foregroundColor(vm.isSessionPaused ? .secondary : .primary)

                    Button {
                        if vm.isSessionPaused {
                            vm.resumeSession()
                        } else {
                            vm.pauseSession()
                        }
                    } label: {
                        Image(systemName: vm.isSessionPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(vm.isSessionPaused ? Color(hex: "059669") : .secondary)
                            .frame(width: 30, height: 30)
                            .background(
                                (vm.isSessionPaused ? Color(hex: "059669") : Color.secondary)
                                    .opacity(0.12)
                            )
                            .clipShape(Circle())
                    }
                }

                Spacer()

                // Stats row
                HStack(spacing: 16) {
                    SessionLiveStat(
                        icon: "checkmark.circle.fill",
                        value: "\(vm.totalCompletedSets)/\(totalSets)",
                        label: "sets",
                        color: Color(hex: "059669")
                    )
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 4) {
                            Image(systemName: "scalemass.fill")
                                .font(.system(size: 11))
                                .foregroundColor(vm.selectedDayColor)
                            Text(String(format: "%.0f", totalVolume))
                                .font(.system(size: 14, weight: .bold).monospacedDigit())
                        }
                        if vm.previousSessionVolume > 0 {
                            let delta = totalVolume - vm.previousSessionVolume
                            let pct = (delta / vm.previousSessionVolume) * 100
                            Text(delta >= 0
                                 ? String(format: "+%.0f%%", pct)
                                 : String(format: "%.0f%%", pct))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(delta >= 0 ? Color(hex: "059669") : Color(hex: "DC2626"))
                        } else {
                            Text(appState.profile.prefersLbs ? "lbs" : "kg")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                LiveHRPill()
            }

            // ETA + progress bar
            HStack {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(vm.selectedDay.color.opacity(0.12))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [vm.selectedDay.color, Color(hex: "059669")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress)
                            .animation(.spring(response: 0.4), value: progress)
                    }
                }
                .frame(height: 6)

                if let eta = vm.estimatedTimeRemaining {
                    let _ = ticker
                    Text(eta)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .fixedSize()
                }
            }
        }
        .padding(14)
        .background(vm.selectedDay.color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(vm.selectedDay.color.opacity(0.15), lineWidth: 1)
        )
    }
}

private struct SessionLiveStat: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 14, weight: .bold).monospacedDigit())
                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Sticky Bottom Action Bar

struct BottomActionBar: View {
    var vm: TrainViewModel
    var onStart: () -> Void
    var onStartSimple: () -> Void
    var onDiscard: () -> Void
    var onComplete: () -> Void

    var totalSets: Int {
        vm.orderedExercises.reduce(0) { $0 + $1.sets }
    }

    var progress: Double {
        guard totalSets > 0 else { return 0 }
        return Double(vm.totalCompletedSets) / Double(totalSets)
    }

    private var totalVolume: Double {
        vm.orderedExercises.reduce(0.0) { total, ex in
            guard let state = vm.exerciseStates[ex.id] else { return total }
            return total + state.sets.filter { $0.isCompleted }.reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if vm.isSessionActive {
                GeometryReader { geo in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [vm.selectedDay.color, Color(hex: "059669")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress)
                        .animation(.spring(response: 0.4), value: progress)
                }
                .frame(height: 3)
                .background(Color(hex: "059669").opacity(0.1))
            }

            HStack(spacing: 12) {
                if vm.isSessionActive {

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: "059669"))
                            .frame(width: 7, height: 7)
                            .modifier(PulseModifier())
                        Text("\(vm.totalCompletedSets)/\(totalSets) sets")
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                        if vm.isSimpleMode {
                            Text("· Simple")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(hex: "8B5CF6"))
                        }
                    }

                    Spacer()

                    Button(action: onDiscard) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.red)
                            .frame(width: 40, height: 40)
                            .background(Color.red.opacity(0.08))
                            .clipShape(Circle())
                    }

                    Button(action: onComplete) {
                        HStack(spacing: 6) {
                            Image(systemName: vm.allExercisesComplete ? "checkmark.circle.fill" : "flag.checkered")
                                .font(.system(size: 13))
                            Text(vm.allExercisesComplete ? "Complete" : "Finish")
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 44)
                        .background(Color(hex: "059669"))
                        .clipShape(Capsule())
                        .shadow(
                            color: vm.allExercisesComplete ? Color(hex: "059669").opacity(0.5) : .clear,
                            radius: vm.allExercisesComplete ? 8 : 0,
                            y: 2
                        )
                    }

                } else {

                    VStack(spacing: 8) {
                        Button(action: onStart) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text("Start \(vm.selectedDay.name)")
                                    .font(.headline.weight(.bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(vm.selectedDay.color)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: vm.selectedDay.color.opacity(0.35), radius: 8, y: 3)
                        }

                        Button(action: onStartSimple) {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                    .font(.caption)
                                Text("Simple mode — just check off exercises")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundColor(Color(hex: "8B5CF6"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Color(hex: "8B5CF6").opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .background(.ultraThinMaterial)
    }
}

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}

// MARK: - Empty Day Card

struct EmptyDayCard: View {
    let dayName: String
    let dayColor: Color
    let onCompose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("\(dayName) has no exercises yet")
                .font(.headline)
            Text("Add exercises from the library to build this day.")
                .font(.caption)
                .foregroundColor(.secondary)
            Button(action: onCompose) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Build this day")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(dayColor)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Complete Session Sheet

struct CompleteSessionSheet: View {
    @Environment(AppState.self) private var appState
    var vm: TrainViewModel
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var hr: LiveHRManager = .shared

    var strainReport: SessionStrainCalculator.StrainReport {
            SessionStrainCalculator.computeStrain(
                hrSamples: HRSampleBuffer.shared.sessionSamples,
                intervalSeconds: HRSampleBuffer.shared.sessionSamplingIntervalSeconds,
                maxHR: hr.maxHR,
                restingHR: vm.recoveryContext.restingHR ?? 60
            )
        }
    var hasHRData: Bool {
        !HRSampleBuffer.shared.sessionSamples.isEmpty
    }

    private var prCount: Int {
        vm.orderedExercises.reduce(0) { count, ex in
            guard let state = vm.exerciseStates[ex.id],
                  ex.measurement.showsWeightField,
                  let prev = vm.previousSessionData[ex.id] else { return count }
            let prevE1RM = prev.weightKg * (1 + Double(prev.reps) / 30.0)
            return count + state.sets.filter { s in
                guard s.isCompleted, s.weightKg > 0 else { return false }
                let e1rm = s.weightKg * (1 + Double(s.reps) / 30.0)
                return e1rm > prevE1RM
            }.count
        }
    }

    private var volumeDelta: Double? {
        guard vm.previousSessionVolume > 0 else { return nil }
        return ((vm.totalSessionVolume - vm.previousSessionVolume) / vm.previousSessionVolume) * 100
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Pulse.canvasFallback.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {

                        // Hero celebration
                        PulseSuccessCheck(
                            size: 100,
                            color: Pulse.positive,
                            showBurst: prCount > 0
                        )
                        .padding(.top, 20)

                        VStack(spacing: 4) {
                            Text("Session Complete")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(Pulse.textPrimary)
                            Text(vm.selectedDay.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(vm.selectedDay.color)
                        }

                        // Stats row
                        HStack(spacing: 10) {
                            SummaryStatPill(
                                icon: "timer",
                                value: vm.sessionDurationFormatted,
                                label: "Duration",
                                color: Pulse.hydration
                            )
                            SummaryStatPill(
                                icon: "checkmark.circle.fill",
                                value: "\(vm.totalCompletedSets)",
                                label: "Sets done",
                                color: Pulse.positive
                            )
                            SummaryStatPill(
                                icon: "scalemass.fill",
                                value: String(format: "%.0f", appState.profile.prefersLbs ? vm.totalSessionVolume * 2.20462 : vm.totalSessionVolume),
                                label: "\(appState.profile.prefersLbs ? "lbs" : "kg") volume",
                                color: vm.selectedDay.color
                            )
                        }
                        .padding(.horizontal, 16)

                        // PR + volume delta badges
                        if prCount > 0 || volumeDelta != nil {
                            HStack(spacing: 12) {
                                if prCount > 0 {
                                    PulsePRBadge(count: prCount)
                                }
                                if let delta = volumeDelta {
                                    PulseVolumeDelta(delta: delta)
                                }
                            }
                        }

                        if hasHRData {
                            SessionStrainCard(report: strainReport)
                                .padding(.horizontal, 16)

                            HRTimelineChart(
                                samples: HRSampleBuffer.shared.sessionSamples,
                                intervalSeconds: HRSampleBuffer.shared.sessionSamplingIntervalSeconds,
                                maxHR: hr.maxHR
                            )
                            .padding(.horizontal, 16)
                        }

                        // Per-exercise summary
                        ExerciseSummaryList(vm: vm)
                            .padding(.horizontal, 16)

                        VStack(spacing: 10) {
                            Button(action: onConfirm) {
                                Text("Complete & Save")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Pulse.positive)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(PulsePrimaryPress())

                            Button(action: onCancel) {
                                Text("Not yet — keep training")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Pulse.textTertiary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        Spacer().frame(height: 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }
}

struct SummaryStatPill: View {
    var icon: String
    var value: String
    var label: String
    var color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(Pulse.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Pulse.Radius.md)
                .fill(Pulse.surfaceFallback)
                .overlay(
                    RoundedRectangle(cornerRadius: Pulse.Radius.md)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Exercise Summary (Completion Sheet)

struct ExerciseSummaryList: View {

    @Environment(AppState.self) private var appState
    var vm: TrainViewModel

    private var useLbs: Bool { appState.profile.prefersLbs }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EXERCISE BREAKDOWN")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Pulse.textTertiary)
                .tracking(1.2)

            ForEach(vm.orderedExercises, id: \.id) { exercise in
                if let state = vm.exerciseStates[exercise.id] {
                    let completedSets = state.sets.filter(\.isCompleted)
                    if !completedSets.isEmpty {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    Text("\(completedSets.count) sets")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)

                                    let vol = completedSets.reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
                                    if vol > 0 {
                                        let displayVol = useLbs ? vol * 2.20462 : vol
                                        Text(String(format: "%.0f %@", displayVol, useLbs ? "lbs" : "kg"))
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(vm.selectedDayColor)
                                    }

                                    let rpes = completedSets.filter { $0.rpe > 0 }.map(\.rpe)
                                    if !rpes.isEmpty {
                                        let avgRPE = Double(rpes.reduce(0, +)) / Double(rpes.count)
                                        Text(String(format: "RPE %.1f", avgRPE))
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(avgRPE >= 9 ? Color(hex: "DC2626") : avgRPE >= 7 ? Color(hex: "F59E0B") : Color(hex: "059669"))
                                    }

                                    let drops = completedSets.filter { $0.setType == .dropSet }.count
                                    if drops > 0 {
                                        Text("\(drops) drop")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(Color(hex: "DC2626"))
                                    }

                                    let amraps = completedSets.filter { $0.setType == .amrap }.count
                                    if amraps > 0 {
                                        Text("\(amraps) AMRAP")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(Color(hex: "8B5CF6"))
                                    }
                                }
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "059669"))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }
}

// MARK: - Flare Notice

struct FlareNotice: View {
    var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "B45309"))
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundColor(Color(hex: "B45309"))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: "B45309").opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct PreSessionContextSection: View {
    var vm: TrainViewModel
    var hasMobilityCheckIn: Bool
    var coachProfile: PersonProfile?
    var onMobilityOpen: () -> Void
    var onCoachOpen: () -> Void
    var onRebuilt: () -> Void

    @State private var expanded = false

    private var contextCount: Int {
        var count = 0
        if !hasMobilityCheckIn { count += 1 }
        if coachProfile != nil { count += 1 }
        count += 1 // warmup
        count += 1 // effort budget
        return count
    }

    var body: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checklist")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Prep & warmup")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text("\(contextCount) items")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            if expanded {
                if !hasMobilityCheckIn {
                    MobilityCheckInBanner(onOpen: onMobilityOpen)
                }

                if let coachProfile {
                    TrainingCoachCard(profile: coachProfile, onOpen: onCoachOpen)
                    TrainingBlockCard(profile: coachProfile, onRebuilt: onRebuilt)
                }

                EffortBudgetBar(vm: vm)

                WarmupCard(
                    routine: DynamicWarmup.routine(
                        dayName: vm.selectedDay.name,
                        exercises: vm.orderedExercises
                    ),
                    sessionColor: vm.selectedDay.color
                )
            }
        }
    }
}
