import SwiftUI
import SwiftData

struct ContentView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var needsOnboarding = false

    private var client = SupabaseClient.shared

    var body: some View {
        @Bindable var state = appState
        return Group {
            if !client.isSignedIn {
                // Auth gate: user must sign in before using the app.
                // Data stays local-first — the account is for cloud backup
                // and identity, not a prerequisite for local storage.
                AuthGateView()
            } else if needsOnboarding {
                OnboardingView(onComplete: {
                    needsOnboarding = false
                })
            } else {
                mainTabs(state: state)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            bootstrapProfiles()
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
