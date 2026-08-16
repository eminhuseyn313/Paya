import SwiftUI
import SwiftData

// MARK: - Insights Hub
//
// All deep-dive analytics cards that previously lived in the dashboard's
// collapsible "Insights & analytics" section. Moved here as a dedicated
// screen to keep the dashboard decision-first and scannable. Nothing was
// removed — every card is reachable, just one tap deeper.
//
// Design: grouped into thematic sections with section headers instead of
// a single vertical dump. Each section is collapsible so users can skip
// domains they don't use.

struct InsightsHubView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = DashboardViewModel()
    @State private var todaysPicture: DayOverview? = nil
    @State private var showPersonalHealth = false
    @State private var showLibrary = false

    // Section expansion state — default all open on first visit
    @State private var showTraining = true
    @State private var showNutrition = true
    @State private var showRecovery = true
    @State private var showAI = true

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: - Training Analytics
                insightSection(
                    title: "Training",
                    icon: "dumbbell.fill",
                    color: "8B5CF6",
                    isExpanded: $showTraining
                ) {
                    if let lastSession = viewModel.lastSession {
                        SessionScoreCard(session: lastSession)
                    }
                    SmartProgramCard()
                    OptimalTrainingWindowCard()
                    if !viewModel.allCompletedSessions.isEmpty {
                        MuscleRecoveryStatusCard(sessions: viewModel.allCompletedSessions)
                        TrainingInsightsCard(sessions: viewModel.allCompletedSessions)
                    }
                    WeeklyEffortCard()
                }

                // MARK: - Nutrition Analytics
                insightSection(
                    title: "Nutrition",
                    icon: "fork.knife",
                    color: "2563EB",
                    isExpanded: $showNutrition
                ) {
                    NutrientTimingCard()
                    PostWorkoutWindowCard()
                    PerformanceNutritionCard()
                }

                // MARK: - Recovery & Body
                insightSection(
                    title: "Recovery & Body",
                    icon: "heart.fill",
                    color: "059669",
                    isExpanded: $showRecovery
                ) {
                    ReadinessTrendCard()
                    CircadianCard()
                    BiologicalAgeCard()
                    BodyRecompCard()
                    GLP1CompanionCard()
                }

                // MARK: - AI & Reports
                insightSection(
                    title: "AI & Reports",
                    icon: "sparkles",
                    color: "F59E0B",
                    isExpanded: $showAI
                ) {
                    WeeklyReportCard()
                    WeeklyInsightCard(
                        vm: viewModel,
                        context: modelContext,
                        apiKey: appState.anthropicAPIKey,
                        profile: appState.profile
                    )
                    .requiresPro()
                    PersonalHealthNarrativeCard()
                        .requiresPro()
                    DailyRoutineCard()
                        .requiresPro()
                    TodaysPictureCard(overview: todaysPicture, onOpen: { showPersonalHealth = true })
                        .buttonStyle(PulsePress())
                }

                // MARK: - Utilities
                LibraryCard(showLibrary: $showLibrary)
                PrivacyBadgeCard()

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPersonalHealth) {
            PersonalHealthView()
        }
        .sheet(isPresented: $showLibrary) {
            ExerciseLibraryView()
        }
        .onAppear {
            viewModel.load(context: modelContext)
            Task {
                todaysPicture = await PersonalHealthTimelineEngine.build(for: .now, context: modelContext)
                await viewModel.loadAppleHealthData(context: modelContext, profile: appState.profile)
            }
        }
    }

    // MARK: - Collapsible Section

    @ViewBuilder
    private func insightSection(
        title: String,
        icon: String,
        color: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.wrappedValue.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: color))
                        .frame(width: 28, height: 28)
                        .background(Color(hex: color).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Pulse.textPrimary)
                    Spacer()
                    Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Pulse.textTertiary)
                }
            }
            .buttonStyle(PulsePress())

            if isExpanded.wrappedValue {
                content()
            }
        }
    }

    // MARK: - Library Card (inline — avoids referencing Dashboard nested type)

    struct LibraryCard: View {
        @Binding var showLibrary: Bool

        var body: some View {
            Button { showLibrary = true } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Pulse.hydration.opacity(0.15))
                            .frame(width: 50, height: 50)
                        Image(systemName: "books.vertical.fill")
                            .font(.title2)
                            .foregroundColor(Pulse.hydration)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Exercise Library")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Pulse.textPrimary)
                        Text("800+ exercises with images and instructions")
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                }
                .payaCard(padding: 14)
            }
            .buttonStyle(PulsePress())
        }
    }

    // MARK: - Weekly Insight Card (duplicate to avoid Dashboard dependency)

    struct WeeklyInsightCard: View {
        var vm: DashboardViewModel
        var context: ModelContext
        var apiKey: String
        var profile: UserProfile

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: AIService.shared.providerIcon)
                        .foregroundColor(Pulse.ai)
                    Text("Weekly Insight")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(AIService.shared.providerName)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Pulse.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Pulse.surfaceElevatedFallback)
                        .clipShape(Capsule())
                }
                if let insight = vm.weeklyInsight {
                    Text(insight)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("AI analysis of your week so far.")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                }
                Button {
                    Task { await vm.fetchWeeklyInsight(context: context, apiKey: apiKey, profile: profile) }
                } label: {
                    HStack {
                        if vm.isFetchingInsight {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                            Text(vm.weeklyInsight == nil ? "Get insight" : "New insight")
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Pulse.ai)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(vm.isFetchingInsight)
            }
            .payaCard(padding: 14)
        }
    }
}
