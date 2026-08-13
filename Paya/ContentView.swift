import SwiftUI
import SwiftData

struct ContentView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var needsOnboarding = false

    var body: some View {
        @Bindable var state = appState
        return Group {
            if needsOnboarding {
                OnboardingView(onComplete: {
                    needsOnboarding = false
                })
            } else {
                mainTabs(state: state)
            }
        }
        .onAppear {
            bootstrapProfiles()
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
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { applyPendingIntentNavigation() }
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
                DashboardView(selectedTab: $selectedTab)
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                TrainView()
                    .tabItem {
                        Label("Train", systemImage: "dumbbell.fill")
                    }
                    .tag(1)

                NutritionView()
                    .tabItem {
                        Label("Nutrition", systemImage: "fork.knife")
                    }
                    .tag(2)

                HealthView()
                    .tabItem {
                        Label("Health", systemImage: "heart.fill")
                    }
                    .tag(3)

                ProgressTabView()
                    .tabItem {
                        Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(4)
            }
            .tint(Color(hex: "2563EB"))
            .onChange(of: selectedTab) { _, _ in
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
