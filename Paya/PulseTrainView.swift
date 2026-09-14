import SwiftUI
import SwiftData
import Combine

// MARK: - Pulse Train View
//
// Design personality: ACTIVE · ENERGETIC · IMMERSIVE
//
// This is the war room. When you're here, you're either preparing to train
// or mid-session. Every element serves the training moment.
//
// Pre-session: Hero day card with session preview, exercise list with visual numbering
// Active session: Full immersion — timer dominates, exercises become the world
//
// Benchmark: Nike Training Club (immersive workout), WHOOP (strain tracking),
// Strava (live activity), Peloton (session progress)
//
// Key differences from old TrainView:
// 1. Dark atmospheric canvas (Pulse system)
// 2. Hero day card replaces separated day picker + header
// 3. Exercise cards get glow accents matching day color
// 4. Active session uses full-width immersive header with ambient energy
// 5. Bottom bar gets Pulse styling
// 6. Pre-session context collapses into ambient info, not card dump

struct PulseTrainView: View {

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
    @State private var hasAppeared = false
    @State private var showRetroactiveLog = false
    @State private var showProgramCheckup = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                // Atmospheric background
                trainBackground

                if let vm = vm {
                    ScrollViewReader { scrollProxy in
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 16) {

                                // ━━━ Active Session: Immersive Header ━━━
                                if vm.isSessionActive {
                                    pulseSessionHeader(vm: vm)
                                }

                                // ━━━ Rest Timer ━━━
                                if RestTimerManager.shared.isActive {
                                    RestTimerBar(manager: RestTimerManager.shared)
                                        .id("restTimer")
                                }

                                // ━━━ Session Comparison ━━━
                                if vm.isSessionActive {
                                    SessionComparisonBanner(vm: vm, ticker: sessionDurationTicker)
                                }

                                // ━━━ Pre-Session: Day Hero ━━━
                                if !vm.isSessionActive {
                                    // Deload alert
                                    DeloadCard(onChanged: {
                                        Task { await vm.loadRecoveryContext(context: modelContext, appState: appState) }
                                    })

                                    // Day selector — pill-style
                                    pulseDayPicker(vm: vm)

                                    // Hero day card
                                    pulseDayHero(vm: vm)

                                    // Volume-landmark gap for THIS day, if any —
                                    // shown before the collapsed prep checklist since
                                    // it's an actionable recommendation, not reference info
                                    ProgramGapCard(
                                        dayCode: vm.selectedDay.code,
                                        onAdded: { vm.buildExerciseStates(context: modelContext) }
                                    )

                                    // Pre-session context (collapsed by default)
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

                                // ━━━ Exercise Overview ━━━
                                if vm.orderedExercises.isEmpty {
                                    pulseEmptyDay(vm: vm)
                                } else {
                                    exerciseOverview(vm: vm, scrollProxy: scrollProxy)
                                }

                                // ━━━ Add Exercise (during session) ━━━
                                if vm.isSessionActive {
                                    Button { showAddExerciseForToday = true } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 16))
                                            Text("Add exercise")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        .foregroundColor(Pulse.energy)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Pulse.energy.opacity(0.08))
                                        .clipShape(RoundedRectangle(cornerRadius: Pulse.Radius.md))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Pulse.Radius.md)
                                                .stroke(Pulse.energy.opacity(0.2), lineWidth: 0.5)
                                        )
                                    }
                                }

                                Spacer().frame(height: 100)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        }
                        .onChange(of: RestTimerManager.shared.isActive) { _, isActive in
                            if isActive {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    scrollProxy.scrollTo("restTimer", anchor: .top)
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        Spacer()
                        PulseSkeletonOrb(size: 80)
                        PulseSkeletonRow(lineCount: 2)
                            .padding(.horizontal, 16)
                        PulseSkeletonRow(lineCount: 3)
                            .padding(.horizontal, 16)
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Train")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showProgramCheckup = true } label: {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 16))
                            .foregroundColor(Pulse.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Pulse.surfaceFallback)
                            .clipShape(Circle())
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showProgramPicker = true } label: {
                            Label("Choose a Program", systemImage: "list.clipboard")
                        }
                        .disabled(vm?.isSessionActive == true)
                        Button { showDaysManager = true } label: {
                            Label("Manage Training Days", systemImage: "calendar.badge.plus")
                        }
                        .disabled(vm?.isSessionActive == true)
                        Button { showSessionEditor = true } label: {
                            Label("Customize Exercises", systemImage: "slider.horizontal.3")
                        }
                        .disabled(vm?.isSessionActive == true)
                        Button { showLibrary = true } label: {
                            Label("Exercise Library", systemImage: "books.vertical")
                        }
                        Divider()
                        Button { showRetroactiveLog = true } label: {
                            Label("Log Past Workout", systemImage: "clock.arrow.circlepath")
                        }
                        .disabled(vm?.isSessionActive == true)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16))
                            .foregroundColor(Pulse.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Pulse.surfaceFallback)
                            .clipShape(Circle())
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if appState.flareEngineEnabled {
                        Button { showFlareToggle = true } label: {
                            Image(systemName: appState.isFlareDay ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                                .foregroundColor(appState.isFlareDay ? Pulse.warning : Pulse.textTertiary)
                                .font(.system(size: 14))
                                .frame(width: 36, height: 36)
                                .background(Pulse.surfaceFallback)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let vm = vm, !vm.orderedExercises.isEmpty {
                    pulseBottomBar(vm: vm)
                }
            }
            // ━━━ All sheets — identical to original ━━━
            .alert("Discard this session?", isPresented: $showDiscardConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    vm?.discardSession(appState: appState)
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                }
            } message: { Text("All logged sets for this session will be lost.") }
            .sheet(isPresented: $showCompleteSheet) {
                if let vm = vm {
                    CompleteSessionSheet(
                        vm: vm,
                        onConfirm: {
                            vm.completeSession(context: modelContext)
                            showCompleteSheet = false
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showReflectionSheet = true }
                        },
                        onCancel: { showCompleteSheet = false }
                    )
                }
            }
            .sheet(isPresented: $showReflectionSheet) {
                if let session = vm?.completedSession { ReflectionSheet(session: session) }
            }
            .sheet(isPresented: $showLibrary) { ExerciseLibraryView() }
            .sheet(isPresented: $showProgramCheckup) { ProgramCheckupView() }
            .sheet(isPresented: $showSessionEditor) {
                if let vm = vm {
                    SessionComposerView(
                        dayCode: vm.selectedDay.code,
                        dayName: vm.selectedDay.name,
                        dayColor: vm.selectedDay.color,
                        onSave: {
                            vm.buildExerciseStates(context: modelContext)
                            vm.loadPreviousSession(context: modelContext)
                        }
                    )
                }
            }
            .sheet(isPresented: $showDaysManager) {
                SessionDaysManagerView(onSave: { vm?.reloadDays(context: modelContext) })
            }
            .sheet(isPresented: $showMobilityCheckIn) {
                MobilityCheckInSheet(onSaved: { hasTodaysMobilityCheckIn = true })
            }
            .sheet(isPresented: $showProgramPicker) {
                ProgramTemplatePickerView(onInstalled: { vm?.reloadDays(context: modelContext) })
            }
            .sheet(isPresented: $showTrainingCoach) {
                if let coachProfile {
                    TrainingCoachView(profile: coachProfile, onProgramRebuilt: { vm?.reloadDays(context: modelContext) })
                }
            }
            .sheet(isPresented: $showAddExerciseForToday) {
                // Was missing `context:` — addExerciseForToday's DB-persist
                // block is entirely gated on that parameter being non-nil,
                // so every exercise added from the live Train tab was only
                // ever kept in memory for that view session, never actually
                // saved. Looked fine during the workout, gone the next time
                // the app opened or that day's program was viewed.
                LibraryPickerSheet { picked in vm?.addExerciseForToday(picked, context: modelContext) }
            }
            .sheet(isPresented: $showRetroactiveLog) {
                RetroactiveWorkoutView()
            }
            .confirmationDialog("Flare day", isPresented: $showFlareToggle, titleVisibility: .visible) {
                Button(appState.isFlareDay ? "Turn off flare day" : "Turn on flare day") {
                    appState.isFlareDay.toggle()
                    vm?.updateFlareDay(appState.isFlareDay)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Flare day reduces suggested weights by 25%.") }
        }
        .onReceive(NotificationCenter.default.publisher(for: .payaWillBackground)) { _ in
            vm?.persistSession()
        }
        .onAppear {
            if vm == nil {
                let newVM = TrainViewModel(appState: appState)
                newVM.configure(context: modelContext)
                // Restore an active session if one was persisted (app was killed mid-workout)
                if ActiveSessionStore.hasPendingSession {
                    newVM.restoreSession(appState: appState, context: modelContext)
                }
                vm = newVM
            }
            if coachProfile == nil { coachProfile = ProfileStore.current(context: modelContext) }
            hasTodaysMobilityCheckIn = MobilityStore.todaysCheckIn(context: modelContext) != nil
            WatchSessionManager.shared.onSetLogged = { [weak vm] w, r in vm?.logSetFromWatch(weightKg: w, reps: r) }
            WatchSessionManager.shared.onSkipRestRequested = { RestTimerManager.shared.skip() }
            WatchSessionManager.shared.onEndSessionRequested = { [weak vm] in
                guard let vm, vm.isSessionActive else { return }
                vm.completeSession(context: modelContext)
            }
            Task { await vm?.loadRecoveryContext(context: modelContext, appState: appState) }
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) { hasAppeared = true }
        }
        .onReceive(timer) { _ in sessionDurationTicker += 1 }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in
            vm?.reloadDays(context: modelContext)
            Task { await vm?.loadRecoveryContext(context: modelContext, appState: appState) }
        }
    }

    // MARK: - Atmospheric Background

    private var trainBackground: some View {
        ZStack {
            Pulse.canvasFallback.ignoresSafeArea()

            if let vm = vm, vm.isSessionActive {
                // Active session: energy gradient pulses
                BreathingOrb(color: vm.selectedDay.color, size: 350)
                    .offset(y: -150)
                    .opacity(0.5)
            } else {
                // Pre-session: subtle warm glow
                Circle()
                    .fill(Pulse.energy.opacity(0.04))
                    .frame(width: 400, height: 400)
                    .blur(radius: 80)
                    .offset(x: -100, y: -200)
            }
        }
    }

    // MARK: - Day Picker (pill-style)

    private func pulseDayPicker(vm: TrainViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.availableDays, id: \.code) { day in
                    let isSelected = vm.selectedDay.code == day.code
                    Button {
                        withAnimation(Pulse.Motion.standard) {
                            vm.switchDay(to: day, context: modelContext)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        VStack(spacing: 3) {
                            Text(day.code)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text(day.name.split(separator: " ").first.map(String.init) ?? day.name)
                                .font(.system(size: 9, weight: .semibold))
                                .lineLimit(1)
                        }
                        .frame(width: 60, height: 52)
                        .background(isSelected ? day.color : Pulse.surfaceFallback)
                        .foregroundColor(isSelected ? .white : Pulse.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Pulse.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: Pulse.Radius.sm)
                                .stroke(isSelected ? Color.clear : Color.white.opacity(0.06), lineWidth: 0.5)
                        )
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Day Hero Card

    private func pulseDayHero(vm: TrainViewModel) -> some View {
        let exercises = vm.orderedExercises
        let totalSets = exercises.reduce(0) { $0 + $1.sets }
        let estimatedMin = Int(Double(totalSets) * 2.5)
        let muscleGroups: [String] = {
            var seen = Set<String>()
            return exercises.map(\.muscleGroup).filter { seen.insert($0).inserted }
        }()

        return VStack(alignment: .leading, spacing: 14) {
            // Day name + color accent
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(vm.selectedDay.color)
                    .frame(width: 4, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.selectedDay.name)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.textPrimary)
                    Text(vm.selectedDay.focus)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(vm.selectedDay.color)
                }

                Spacer()

                // Stats
                if !exercises.isEmpty {
                    HStack(spacing: 14) {
                        trainStat("\(exercises.count)", "exercises")
                        trainStat("\(totalSets)", "sets")
                        trainStat("~\(estimatedMin)m", "est.")
                    }
                }
            }

            // Muscle chips
            if !muscleGroups.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(muscleGroups, id: \.self) { group in
                            Text(group)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(vm.selectedDay.color)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(vm.selectedDay.color.opacity(0.1))
                                .clipShape(Capsule())
                        }

                        if FocusModeManager.shared.isEnabled {
                            HStack(spacing: 4) {
                                Image(systemName: "moon.fill").font(.system(size: 8))
                                Text("Focus").font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(Pulse.ai)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Pulse.ai.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // Flare warning
            if appState.flareEngineEnabled && appState.isFlareDay && !appState.flareWarningText.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Pulse.warning)
                    Text(appState.flareWarningText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Pulse.warning)
                        .lineLimit(1)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Pulse.warning.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Pre-workout glucose alert (diabetic users with CGM)
            if let glucoseAlert = vm.preWorkoutGlucoseAlert, glucoseAlert.level != .optimal {
                HStack(spacing: 10) {
                    Image(systemName: glucoseAlert.level == .low ? "exclamationmark.triangle.fill" : "bolt.trianglebadge.exclamationmark.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(glucoseAlert.level == .low ? Pulse.warning : Pulse.critical)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(glucoseAlert.level == .low ? "Low glucose" : "High glucose")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Pulse.textPrimary)
                        Text(glucoseAlert.message)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Pulse.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(12)
                .background((glucoseAlert.level == .low ? Pulse.warning : Pulse.critical).opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke((glucoseAlert.level == .low ? Pulse.warning : Pulse.critical).opacity(0.2), lineWidth: 0.5)
                )
            }

            // Recovery adjustment
            if let adjustment = vm.currentAdjustment {
                PulseRecoveryBadge(adjustment: adjustment)

                if (adjustment.severity == .caution || adjustment.severity == .deload) && vm.fullExerciseCountBeforeQuickMode == nil {
                    Button { vm.applyQuickSessionMode() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.fill").font(.system(size: 11)).foregroundColor(Pulse.ai)
                            Text("Switch to 20-min compounds-only").font(.system(size: 11, weight: .semibold)).foregroundColor(Pulse.ai)
                            Spacer()
                            Text("Switch").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Pulse.ai).clipShape(Capsule())
                        }
                    }
                    .buttonStyle(PulsePress())
                    .padding(10)
                    .background(Pulse.ai.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .pulseSurfaceGlow(color: vm.selectedDay.color, padding: 16)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
    }

    private func trainStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Pulse.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
        }
    }

    // MARK: - Session Live Header (Immersive)

    private func pulseSessionHeader(vm: TrainViewModel) -> some View {
        let totalSets = vm.orderedExercises.reduce(0) { $0 + $1.sets }
        let progress = totalSets > 0 ? Double(vm.totalCompletedSets) / Double(totalSets) : 0.0
        let totalVolumeKg = vm.orderedExercises.reduce(0.0) { total, ex in
            guard let state = vm.exerciseStates[ex.id] else { return total }
            return total + state.sets.filter { $0.isCompleted }.reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
        }
        let totalVolume = appState.profile.prefersLbs ? totalVolumeKg * 2.20462 : totalVolumeKg

        return VStack(spacing: 14) {
            // Timer + controls
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    if vm.isSessionPaused {
                        Image(systemName: "pause.fill").font(.system(size: 10)).foregroundColor(Pulse.warning)
                    } else {
                        Circle().fill(Pulse.positive).frame(width: 8, height: 8).modifier(PulseModifier())
                    }
                    let _ = sessionDurationTicker
                    Text(vm.sessionDurationFormatted)
                        .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundColor(vm.isSessionPaused ? Pulse.textSecondary : Pulse.textPrimary)

                    Button {
                        vm.isSessionPaused ? vm.resumeSession() : vm.pauseSession()
                    } label: {
                        Image(systemName: vm.isSessionPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(vm.isSessionPaused ? Pulse.positive : Pulse.textSecondary)
                            .frame(width: 34, height: 34)
                            .background((vm.isSessionPaused ? Pulse.positive : Color.white).opacity(0.12))
                            .clipShape(Circle())
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 11)).foregroundColor(Pulse.positive)
                        Text("\(vm.totalCompletedSets)/\(totalSets)")
                            .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundColor(Pulse.textPrimary)
                    }
                    Text(String(format: "%.0f %@", totalVolume, appState.profile.prefersLbs ? "lbs" : "kg"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Pulse.textTertiary)
                }

                LiveHRPill()
            }

            // Progress wave
            WaveProgressBar(progress: progress, color: vm.selectedDay.color, height: 6)

            if let eta = vm.estimatedTimeRemaining {
                let _ = sessionDurationTicker
                Text("~\(eta) remaining")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Pulse.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .pulseSurfaceGlow(color: vm.selectedDay.color, padding: 16)
    }

    // MARK: - Exercise Overview
    //
    // A day with 7-8 restored exercises stacked as full-width rows — even
    // collapsed ones — was still a long scroll, and letting several rows
    // expand independently made it worse. This replaces the flat list with
    // the pattern gym apps at this density actually use: a compact 2-column
    // grid as the map of the whole session (roughly half the vertical
    // space of one row per exercise), plus a single "now training" card
    // for whichever exercise is active — never more than one exercise's
    // set-logging rows on screen at a time, and every other exercise is
    // one tap away instead of a scroll away.
    private func exerciseOverview(vm: TrainViewModel, scrollProxy: ScrollViewProxy) -> some View {
        let exercises = vm.orderedExercises
        let activeId = vm.focusedExerciseId
            ?? exercises.first(where: { vm.exerciseStates[$0.id]?.allSetsCompleted != true })?.id
            ?? exercises.first?.id

        return VStack(spacing: 14) {
            exerciseGrid(vm: vm, exercises: exercises, activeId: activeId)

            if let activeId,
               let index = exercises.firstIndex(where: { $0.id == activeId }),
               let state = vm.exerciseStates[activeId] {
                let displayState = { var s = state; s.isExpanded = true; return s }()
                ExerciseCardView(
                    vm: vm,
                    exercise: exercises[index],
                    state: displayState,
                    exerciseNumber: index + 1,
                    totalExercises: exercises.count
                )
                .id(activeId)
            }
        }
        // Whenever the active exercise changes — tapping a grid tile, or
        // auto-advancing to the next exercise after finishing a set —
        // scroll its logging card into view. Without this the card renders
        // below the grid and the user has to manually scroll down every
        // time just to reach the weight/rep inputs they're about to use.
        .onChange(of: activeId) { _, newId in
            guard let newId else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollProxy.scrollTo(newId, anchor: .top)
            }
        }
    }

    private func exerciseGrid(vm: TrainViewModel, exercises: [ExerciseDefinition], activeId: String?) -> some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                let state = vm.exerciseStates[exercise.id]
                let done = state?.allSetsCompleted == true
                let active = exercise.id == activeId

                Button {
                    vm.focusExercise(exerciseId: exercise.id)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(done ? Pulse.positive : (active ? vm.selectedDayColor : Pulse.surfaceElevatedFallback))
                                    .frame(width: 20, height: 20)
                                if done {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                } else {
                                    Text("\(index + 1)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(active ? .white : Pulse.textSecondary)
                                }
                            }
                            Spacer()
                            if let state, state.completedSetsCount > 0, !done {
                                Text("\(state.completedSetsCount)/\(exercise.sets)")
                                    .font(.system(size: 9, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundColor(vm.selectedDayColor)
                            }
                        }
                        Text(exercise.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(done ? Pulse.textSecondary : Pulse.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(exercise.muscleGroup)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(vm.selectedDayColor)
                            .lineLimit(1)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
                    .background(active ? vm.selectedDayColor.opacity(0.1) : Pulse.surfaceFallback)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(active ? vm.selectedDayColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(PulsePress())
            }
        }
    }

    // MARK: - Empty Day

    private func pulseEmptyDay(vm: TrainViewModel) -> some View {
        PulseEmptyState(
            icon: "figure.strengthtraining.traditional",
            title: "No exercises yet",
            message: "Build your \(vm.selectedDay.name) session — pick exercises from the library or let the composer do it for you.",
            ctaLabel: "Compose session",
            ctaIcon: "plus.circle.fill",
            accentColor: vm.selectedDay.color,
            action: { showSessionEditor = true }
        )
    }

    // MARK: - Bottom Action Bar

    private func pulseBottomBar(vm: TrainViewModel) -> some View {
        let totalSets = vm.orderedExercises.reduce(0) { $0 + $1.sets }
        let progress = totalSets > 0 ? Double(vm.totalCompletedSets) / Double(totalSets) : 0.0

        return VStack(spacing: 0) {
            if vm.isSessionActive {
                // Progress line
                GeometryReader { geo in
                    Rectangle()
                        .fill(LinearGradient(colors: [vm.selectedDay.color, Pulse.positive], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress)
                        .animation(.spring(response: 0.4), value: progress)
                }
                .frame(height: 3)
                .background(Pulse.positive.opacity(0.1))
            }

            HStack(spacing: 12) {
                if vm.isSessionActive {
                    HStack(spacing: 6) {
                        Circle().fill(Pulse.positive).frame(width: 7, height: 7).modifier(PulseModifier())
                        Text("\(vm.totalCompletedSets)/\(totalSets) sets")
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(Pulse.textSecondary)
                        if vm.isSimpleMode {
                            Text("· Simple")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Pulse.ai)
                        }
                    }
                    Spacer()
                    Button(action: { showDiscardConfirm = true }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Pulse.critical)
                            .frame(width: 40, height: 40)
                            .background(Pulse.critical.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Button(action: { showCompleteSheet = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: vm.allExercisesComplete ? "checkmark.circle.fill" : "flag.checkered")
                                .font(.system(size: 13))
                            Text(vm.allExercisesComplete ? "Complete" : "Finish")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(vm.allExercisesComplete ? Pulse.positive : vm.selectedDay.color)
                        .clipShape(Capsule())
                    }
                } else {
                    // Pre-session: Start buttons
                    Button {
                        vm.isSimpleMode = false
                        vm.startSession(appState: appState)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill").font(.system(size: 14))
                            Text("Start \(vm.selectedDay.code)")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(vm.selectedDay.color)
                        .clipShape(RoundedRectangle(cornerRadius: Pulse.Radius.md))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Pulse.surfaceFallback
                    .overlay(Color.white.opacity(0.02))
            )
        }
    }
}

// MARK: - Recovery Badge (Pulse-styled)

struct PulseRecoveryBadge: View {
    let adjustment: RecoveryAdjuster.Adjustment
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(Pulse.Motion.standard) { expanded.toggle() }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: adjustment.severity.icon)
                        .font(.system(size: 12))
                        .foregroundColor(adjustment.severity.color)
                    Text(adjustment.multiplier > 1.0 ? "Primed" : adjustment.severity.label)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Pulse.textPrimary)
                    Text(adjustment.signedPercentLabel)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(adjustment.severity.color)
                    Spacer()
                    Text("\(adjustment.reasons.count) signal\(adjustment.reasons.count == 1 ? "" : "s")")
                        .font(.system(size: 10)).foregroundColor(Pulse.textTertiary)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold)).foregroundColor(Pulse.textTertiary)
                }
            }
            .buttonStyle(PulsePress())

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(adjustment.reasons) { reason in
                        HStack(spacing: 8) {
                            Image(systemName: reason.icon).font(.system(size: 10))
                                .foregroundColor(adjustment.severity.color).frame(width: 16)
                            Text(reason.text).font(.system(size: 11)).foregroundColor(Pulse.textSecondary)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(12)
        .background(adjustment.severity.color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: Pulse.Radius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: Pulse.Radius.sm)
                .stroke(adjustment.severity.color.opacity(0.15), lineWidth: 0.5)
        )
    }
}
