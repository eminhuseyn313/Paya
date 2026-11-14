import SwiftUI
import SwiftData

struct ContentView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var needsOnboarding = false
    @State private var isRestoringFromCloud = false
    @State private var restoreIsSlow = false

    private var client = SupabaseClient.shared

    var body: some View {
        @Bindable var state = appState
        return Group {
            switch client.authState {
            case .unknown:
                // Stored token exists but is expired and being refreshed —
                // an async gap of a few hundred ms on a normal launch.
                // Gating on `isSignedIn` directly (which starts false) used
                // to show the full sign-in screen for that gap, then swap to
                // the home screen the instant the refresh resolved — read as
                // "login page flashes then home opens with no action."
                // Neutral splash instead, so there's no incorrect screen to
                // flash away from.
                launchSplash
            case .signedOut:
                // Auth gate: user must sign in before using the app.
                // Data stays local-first — the account is for cloud backup
                // and identity, not a prerequisite for local storage.
                AuthGateView()
            case .signedIn, .guest:
                // .guest = local-only mode, all features work, no cloud sync.
                // User can create an account later from Settings.
                if isRestoringFromCloud {
                    restoringView
                } else if needsOnboarding {
                    OnboardingView(onComplete: {
                        needsOnboarding = false
                    })
                } else {
                    mainTabs(state: state)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            bootstrapProfiles()
            LostExerciseRepair.repairIfNeeded(context: modelContext)
            ProgramDensityCorrection.correctIfNeeded(context: modelContext)
            RepTargetNormalization.normalizeIfNeeded(context: modelContext)
            PendingExerciseAddition.applyIfNeeded(context: modelContext)
            #if DEBUG
            YesterdayWorkoutSeeder.seedIfNeeded(context: modelContext)
            #endif
            WatchSessionManager.shared.activate()
            WatchSessionManager.shared.onWaterAdded = { ml in
                let total = WaterStore.addWater(ml, context: modelContext)
                WatchSessionManager.shared.pushWaterTotal(total)
            }
            WatchSessionManager.shared.onCheckInReceived = { energy, soreness, hasSymptom in
                let pid = ActiveProfile.id
                let today = Calendar.current.startOfDay(for: .now)
                let desc = FetchDescriptor<DailyCheckIn>(
                    predicate: #Predicate<DailyCheckIn> { $0.profileId == pid && $0.date >= today }
                )
                let existing = (try? modelContext.fetch(desc))?.first
                if existing == nil {
                    let checkIn = DailyCheckIn(
                        date: today,
                        soreness: soreness,
                        energy: energy,
                        symptomTags: hasSymptom ? ["feeling_unwell"] : []
                    )
                    checkIn.profileId = pid
                    modelContext.insert(checkIn)
                    try? modelContext.save()
                    appState.dataRefreshTrigger = UUID()
                }
            }
            WatchSessionManager.shared.onOfflineSessionReceived = { payload in
                TrainViewModel.importOfflineSession(payload, context: modelContext)
                appState.dataRefreshTrigger = UUID()
            }
            WatchSessionManager.shared.onMedTaken = { id in
                WatchHealthPush.handleMedTaken(id: id, context: modelContext)
            }
            WatchSessionManager.shared.onMealRequested = { id in
                WatchHealthPush.handleMealRequested(id: id, context: modelContext)
                WatchHealthPush.pushQuickMeals(context: modelContext)
                appState.dataRefreshTrigger = UUID()
            }
            WatchSessionManager.shared.onWeightRequested = { kg in
                WatchHealthPush.handleWeightRequested(kg: kg, context: modelContext)
                appState.dataRefreshTrigger = UUID()
            }
            WatchHealthPush.pushMeds(context: modelContext)
            WatchHealthPush.pushQuickMeals(context: modelContext)
            refreshWatchPlan()
            WatchSessionManager.shared.pushWaterTotal(WaterStore.todayTotal(context: modelContext))
            Task { await ExternalWorkoutImporter.importRecent(context: modelContext) }
            applyPendingIntentNavigation()

            // If the app was killed with an active session, restore AppState
            // so the FloatingSessionBar appears even before the user opens
            // the Train tab (where full VM restoration happens).
            if let snapshot = ActiveSessionStore.load(),
               Date().timeIntervalSince(snapshot.startTime) < 6 * 3600 {
                appState.isSessionActive = true
                appState.sessionStartTime = snapshot.startTime
                appState.isSessionPaused = snapshot.isPaused
                appState.activeSessionLabel = snapshot.sessionLabel
                let completed = snapshot.exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
                let total = snapshot.exercises.reduce(0) { $0 + $1.sets.count }
                appState.completedSetsInSession = completed
                appState.totalSetsInSession = total
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                applyPendingIntentNavigation()
                // Re-check Pro access on every foreground — catches cases where
                // the developer email check didn't fire during initial launch
                PurchaseManager.shared.checkDeveloperAccess()
                refreshWatchPlan()
                WatchHealthPush.pushMeds(context: modelContext)
                WatchSessionManager.shared.refreshStatus()   // re-check paired / worn state
            case .background:
                // Tell the active session (if any) to persist immediately
                NotificationCenter.default.post(name: .payaWillBackground, object: nil)
            default:
                break
            }
        }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in
            Task { await ExternalWorkoutImporter.importRecent(context: modelContext) }
        }
        .onReceive(NotificationCenter.default.publisher(for: PayaNotificationDelegate.didNavigateNotification)) { _ in
            applyPendingIntentNavigation()
        }
        .onChange(of: client.authState) { oldValue, newValue in
            // One Supabase account per device: wipe local data on every
            // sign-out (including account deletion, which also calls
            // signOut()) so a different account signing in later never
            // inherits the previous person's local health data. Only fires
            // on a real signedIn→signedOut transition, not on launch's
            // unknown→signedOut resolution (nothing to wipe there anyway).
            // Data-loss fix: the cloud has no restore path yet, so wiping on
            // every sign-out destroyed the user's only copy. Now local data is
            // kept on sign-out and wiped only when a DIFFERENT account signs
            // in on this device (the original isolation goal).
            if newValue == .signedIn, let uid = client.userId?.uuidString {
                let key = "paya_last_signed_in_user"
                if let last = UserDefaults.standard.string(forKey: key), last != uid {
                    LocalDataWiper.wipeAll(context: modelContext)
                    // New person on this device: reset in-memory profile and
                    // show onboarding (restore below flips it off if the
                    // account has cloud data).
                    appState.profile = UserProfile()
                    needsOnboarding = true
                }
                UserDefaults.standard.set(uid, forKey: key)
                runCloudRestore()
            }
        }
        .task {
            // Already signed in at launch (no authState transition to observe).
            if client.authState == .signedIn {
                // Users signed in before the different-account check shipped
                // never had this key written — record it now.
                if let uid = client.userId?.uuidString,
                   UserDefaults.standard.string(forKey: "paya_last_signed_in_user") == nil {
                    UserDefaults.standard.set(uid, forKey: "paya_last_signed_in_user")
                }
                runCloudRestore()
            }
        }
    }

    /// Fresh install / new device: pull the user's data from Supabase before
    /// onboarding is shown. No-op when local profiles exist. Failures are
    /// non-fatal and leave local data untouched.
    private func runCloudRestore() {
        guard !isRestoringFromCloud else { return }
        let hasLocal = ((try? modelContext.fetchCount(FetchDescriptor<PersonProfile>())) ?? 0) > 0
        guard !hasLocal else { return }
        isRestoringFromCloud = true
        restoreIsSlow = false
        // Never leave the user staring at a spinner: after 20 s offer a way forward.
        Task {
            try? await Task.sleep(for: .seconds(20))
            if isRestoringFromCloud { restoreIsSlow = true }
        }
        Task {
            let result = await CloudRestore.restoreIfNeeded(context: modelContext)
            // Applies even if the user already chose to continue, as long as they
            // haven't finished onboarding — restored data should win over a blank start.
            if let profile = result.restoredProfile ?? ProfileStore.current(context: modelContext),
               result.profiles > 0, needsOnboarding || isRestoringFromCloud {
                appState.syncFromPersonProfile(profile)
                needsOnboarding = false
            }
            isRestoringFromCloud = false
            restoreIsSlow = false
        }
    }

    private var restoringView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().tint(Pulse.hydration)
                Text("Restoring your data…")
                    .font(.subheadline)
                    .foregroundColor(Pulse.textSecondary)
                if restoreIsSlow {
                    Text("This is taking longer than usual. Check your connection — or continue and set up fresh. Your cloud backup stays safe.")
                        .font(.footnote)
                        .foregroundColor(Pulse.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                    Button("Continue without restoring") {
                        isRestoringFromCloud = false
                        restoreIsSlow = false
                    }
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(Pulse.hydration)
                    .frame(minHeight: 44)
                }
            }
        }
    }

    /// Shown only for the brief `.unknown` auth window on launch (expired
    /// token being refreshed) — deliberately neutral, matching the app's
    /// own dark canvas so it reads as a beat of loading, not as a screen.
    private var launchSplash: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.pulse(size: 48, weight: .medium))
                .foregroundColor(Pulse.hydration)
        }
    }

    @ViewBuilder
    private func mainTabs(state: AppState) -> some View {
        ZStack(alignment: .top) {

            TabView(selection: $selectedTab) {
                PulseDashboardView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                PulseTrainView()
                    .tabItem {
                        Label("Train", systemImage: "dumbbell.fill")
                    }
                    .tag(1)

                PulseNutritionView()
                    .tabItem {
                        Label("Nutrition", systemImage: "leaf.fill")
                    }
                    .tag(2)

                PulseHealthView()
                    .tabItem {
                        Label("Health", systemImage: "heart.fill")
                    }
                    .tag(3)

                PulseProgressView()
                    .tabItem {
                        Label("Progress", systemImage: "chart.bar.fill")
                    }
                    .tag(4)
            }
            .tint(Pulse.hydration)
            .toolbarBackground(Pulse.surfaceElevatedFallback, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .onChange(of: selectedTab) { old, new in
                guard old != new else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                appState.dataRefreshTrigger = UUID()
            }

            // Floating session bar — appears on every tab except Train when session is active
            if appState.isSessionActive && selectedTab != 1 {
                FloatingSessionBar(
                    appState: state,
                    selectedTab: $selectedTab
                )
                .padding(.top, 4)
                .zIndex(100)
                .animation(.spring(response: 0.4), value: appState.isSessionActive)
            }

            MilestoneToastOverlay()
                .zIndex(200)
        }
    }

    /// App Intents (Siri/Shortcuts) run outside the view hierarchy, so
    /// "open today's workout" leaves a UserDefaults flag here instead of
    /// holding a Binding — this reads and clears it whenever the app
    /// becomes active.
    /// Keeps the watch's offline plan current without the Train tab being
    /// opened. Throttled; skipped while a session is running.
    private func refreshWatchPlan() {
        guard !ActiveSessionStore.hasPendingSession else { return }
        let key = "paya_watch_plan_pushed_at"
        let last = UserDefaults.standard.double(forKey: key)
        guard Date().timeIntervalSince1970 - last > 30 * 60 else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
        // Heavy (loads training history on the main thread): wait until the app
        // has finished launching and the first screen is interactive.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(8))
            guard !ActiveSessionStore.hasPendingSession else { return }
            let vm = TrainViewModel(appState: appState)
            vm.configure(context: modelContext)
            WatchSessionManager.shared.pushPlan(dayName: vm.selectedDay.name, colorHex: vm.selectedDay.colorHex, exercises: vm.watchPlanPayload())
        }
    }

    private func applyPendingIntentNavigation() {
        let key = PayaIntentNavigation.requestedTabKey
        guard UserDefaults.standard.object(forKey: key) != nil else { return }
        let tab = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        selectedTab = tab
    }

    private func bootstrapProfiles() {
        let existing = ProfileStore.all(context: modelContext)

        // Fresh device (no profiles, empty legacy name) → onboarding
        if existing.isEmpty && appState.profile.name.isEmpty {
            needsOnboarding = true
            return
        }

        ProfileStore.migrateIfNeeded(context: modelContext, legacy: appState.profile)
        guard let current = ProfileStore.current(context: modelContext) else {
            needsOnboarding = true
            return
        }
        appState.syncFromPersonProfile(current)

        // One-time adoption of pre-Phase-2 data into the migrated profile
        let pid = current.id
        TrainingDayStore.adoptOrphans(to: pid, context: modelContext)
        CustomSessionStore.adoptOrphans(to: pid, context: modelContext)
        UserSupplementStore.adoptOrphans(to: pid, context: modelContext)

        let sessions = FetchDescriptor<TrainingSession>(predicate: #Predicate { $0.profileId == nil })
        for s in (try? modelContext.fetch(sessions)) ?? [] { s.profileId = pid }
        let health = FetchDescriptor<HealthLog>(predicate: #Predicate { $0.profileId == nil })
        for h in (try? modelContext.fetch(health)) ?? [] { h.profileId = pid }
        let nutrition = FetchDescriptor<NutritionLog>(predicate: #Predicate { $0.profileId == nil })
        for n in (try? modelContext.fetch(nutrition)) ?? [] { n.profileId = pid }
        let weights = FetchDescriptor<BodyWeightLog>(predicate: #Predicate { $0.profileId == nil })
        for w in (try? modelContext.fetch(weights)) ?? [] { w.profileId = pid }
        try? modelContext.save()
    }
}
