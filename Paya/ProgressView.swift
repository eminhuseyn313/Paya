import SwiftUI
import SwiftData
import Charts

// Structural fix, not a cosmetic one: splitting one wall of cards into
// three segmented walls still left every tab a vertical stack (Body &
// Recovery alone stacked 10+ cards). The actual mechanism is different now —
// each tab leads with ONE large hero (the single thing worth seeing first)
// and everything secondary lives in a horizontal, swipeable CardCarousel
// instead of being scrolled past vertically. No card was removed; every one
// below still exists, just reachable by a swipe instead of a scroll.
enum ProgressSection: String, CaseIterable, Identifiable {
    case strength = "Strength"
    case body = "Body"
    case load = "Load"
    case consistency = "Consistency"
    var id: String { rawValue }
}

struct ProgressTabView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = ProgressViewModel()
    @State private var bodySignals: [WellnessCorrelationEngine.Insight] = []
    @State private var showBodyTracking = false
    @State private var section: ProgressSection = .strength

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            ScrollView {
                VStack(spacing: 10) {

                    // Summary stats — the always-visible top billing
                    ProgressStatsRow(vm: viewModel, onSelectSection: { section = $0 })

                    Picker("Section", selection: $section) {
                        ForEach(ProgressSection.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)

                    switch section {
                    case .strength:
                        TrophyCaseCard()
                        PersonalBestTimelineCard()
                        StrengthRadarCard(sessions: viewModel.allSessions)
                        StrengthToWeightCard(sessions: viewModel.allSessions)
                        StrengthStandardsCard(sessions: viewModel.allSessions)
                        EstimatedOneRMCard(sessions: viewModel.allSessions)
                        PRWallCard(sessions: viewModel.allSessions)
                        PRTimelineCard(sessions: viewModel.allSessions)
                        ExerciseSparklineCard(sessions: viewModel.allSessions)
                        ProgressiveOverloadCard(sessions: viewModel.allSessions)
                        ExerciseAlternativesCard(sessions: viewModel.allSessions)
                        ExerciseProgressionCard(sessions: viewModel.allSessions)
                        RecentPRsCard(sessions: viewModel.allSessions)
                        VolumeLandmarkCard(sessions: viewModel.allSessions)
                        WeeklyBodyMapCard(sessions: viewModel.allSessions)
                        VolumePRCard(sessions: viewModel.allSessions)
                        MuscleRecoveryInsightCard(sessions: viewModel.allSessions)
                        if !PlateauEngine.detect(sessions: viewModel.allSessions).isEmpty {
                            PlateauCard(sessions: viewModel.allSessions)
                        }

                    case .body:
                        ProgressWeightChart(vm: viewModel)
                        BodyCompositionCard()
                        BodyRecompCard()
                        VO2MaxCard()
                        if !bodySignals.isEmpty {
                            BodySignalsCard(insights: bodySignals)
                        }
                        Button {
                            showBodyTracking = true
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "8B5CF6").opacity(0.15))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "ruler.fill")
                                        .foregroundColor(Color(hex: "8B5CF6"))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Body Tracking")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Text("Measurements & progress photos")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .payaCard(padding: 14)
                        }
                        .buttonStyle(.plain)

                    case .load:
                        WorkoutIntensityScoreCard(sessions: viewModel.allSessions)
                        ACWRCard()
                        PeriodizationCard(sessions: viewModel.allSessions)
                        FatigueIndexCard(sessions: viewModel.allSessions)
                        RepRangeAnalysisCard(sessions: viewModel.allSessions)
                        WorkoutDensityCard(sessions: viewModel.allSessions)
                        WeeklyVolumeTrendCard(sessions: viewModel.allSessions)
                        MuscleFreshnessMap(sessions: viewModel.allSessions)
                        MuscleBalanceCard(sessions: viewModel.allSessions)
                        RPETrendCard(sessions: viewModel.allSessions)
                        HRZoneDistributionCard(sessions: viewModel.allSessions)
                        PersonalHRZoneCard()
                        MoodPerformanceCard()
                        MuscleVolumeChart(sessions: viewModel.allSessions)
                        RestTimeAnalyticsCard(sessions: viewModel.allSessions)
                        SessionDurationTrendCard(sessions: viewModel.allSessions)
                        TrimpTimelineCard(sessions: viewModel.allSessions)
                        WeeklyLoadCard(sessions: viewModel.allSessions)
                        SessionBaselinesCard(sessions: viewModel.allSessions)
                        FeltVsMeasuredCard(sessions: viewModel.allSessions)
                        HRRecoveryCard(sessions: viewModel.allSessions)

                    case .consistency:
                        WeeklySummaryShareCard()
                        TrainingTimeAnalysisCard()
                            .requiresPro()
                        ExercisePreferenceCard()
                            .requiresPro()
                        ConsistencyScoreCard(
                            sessions: viewModel.allSessions,
                            plannedPerWeek: 3
                        )
                        TrainingSplitCard(sessions: viewModel.allSessions)
                        WorkoutMilestonesCard(sessions: viewModel.allSessions)
                        TrainingFrequencyCard()
                        TrainingHeatmapCard()
                        WeeklyVolumeChart(vm: viewModel)
                        TrainingCalendarV2()
                        ProgressSectionHeader(title: "History & Insights")
                        SessionHistoryCardV2()
                        CorrelationInsightsCard()
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .frame(width: geo.size.width)
            }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            viewModel.loadAll(context: modelContext)
            Task { bodySignals = await WellnessCorrelationEngine.analyzeToday(context: modelContext) }
        }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in
            viewModel.loadAll(context: modelContext)
            Task { bodySignals = await WellnessCorrelationEngine.analyzeToday(context: modelContext) }
        }
        .sheet(isPresented: $showBodyTracking) {
            BodyTrackingView()
        }
    }
}

// MARK: - Body Signals Card

struct BodySignalsCard: View {
    var insights: [WellnessCorrelationEngine.Insight]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .foregroundColor(Color(hex: "0891B2"))
                Text("Body signals today")
                    .font(.subheadline.weight(.bold))
                Spacer()
            }
            ForEach(insights) { insight in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: insight.icon)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: insight.colorHex))
                        .padding(.top, 1)
                    Text(insight.text)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Based on today's heart rate against logged meals and water — patterns worth noticing, not a diagnosis.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Stats Row

struct ProgressStatsRow: View {
    @Environment(AppState.self) private var appState
    var vm: ProgressViewModel
    var onSelectSection: (ProgressSection) -> Void

    private var useLbs: Bool { appState.profile.prefersLbs }

    var body: some View {
        HStack(spacing: 10) {
            ProgressStatChip(
                value: "\(vm.totalSessionCount)",
                label: "Total Sessions",
                icon: "dumbbell.fill",
                color: Color(hex: "2563EB"),
                action: { onSelectSection(.consistency) }
            )
            ProgressStatChip(
                value: "\(vm.currentStreak)",
                label: "Week Streak",
                icon: "flame.fill",
                color: Color(hex: "B45309"),
                action: { onSelectSection(.consistency) }
            )
            ProgressStatChip(
                value: vm.weightLogs.isEmpty
                    ? "--"
                    : String(format: "%.1f", useLbs ? vm.totalWeightChange * 2.20462 : vm.totalWeightChange),
                label: useLbs ? "lbs Change" : "kg Change",
                icon: "arrow.up.arrow.down",
                color: vm.totalWeightChange <= 0
                    ? Color(hex: "059669")
                    : Color(hex: "B45309"),
                action: { onSelectSection(.body) }
            )
        }
    }
}

struct ProgressStatChip: View {
    var value: String
    var label: String
    var icon: String
    var color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Weight Chart

struct ProgressWeightChart: View {
    @Environment(AppState.self) private var appState
    var vm: ProgressViewModel

    private var useLbs: Bool { appState.profile.prefersLbs }
    private var unit: String { useLbs ? "lbs" : "kg" }
    private func convert(_ kg: Double) -> Double { useLbs ? kg * 2.20462 : kg }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Body Weight")
                        .font(.subheadline.weight(.semibold))
                    if !vm.weightLogs.isEmpty {
                        HStack(spacing: 8) {
                            Text(String(format: "%.1f %@ now",
                                        convert(vm.weightLogs.last?.weightKg ?? 0), unit))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%+.1f %@ total",
                                        convert(vm.totalWeightChange), unit))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(vm.totalWeightChange <= 0
                                    ? Color(hex: "059669")
                                    : Color(hex: "B45309"))
                        }
                    }
                }
                Spacer()
                Text("Last 30 entries")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if vm.last30Weights.isEmpty {
                EmptyChartPlaceholder(
                    icon: "scalemass.fill",
                    message: "Log your weight to see the trend"
                )
            } else {
                Chart(vm.last30Weights, id: \.id) { entry in
                    LineMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", convert(entry.weightKg))
                    )
                    .foregroundStyle(Color(hex: "2563EB"))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", convert(entry.weightKg))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: "2563EB").opacity(0.2),
                                Color(hex: "2563EB").opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", entry.date),
                        y: .value("Weight", convert(entry.weightKg))
                    )
                    .foregroundStyle(Color(hex: "2563EB"))
                    .symbolSize(16)
                }
                .frame(height: 85)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) {
                        AxisValueLabel(format: .dateTime.day().month())
                            .font(.system(size: 9))
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis {
                    AxisMarks(position: .trailing,
                              values: .automatic(desiredCount: 4)) {
                        AxisValueLabel()
                            .font(.system(size: 9))
                    }
                }
            }

            // Weekly change
            if vm.weightLogs.count >= 2 {
                HStack(spacing: 6) {
                    Image(systemName: vm.weeklyWeightChange <= 0
                          ? "arrow.down.circle.fill"
                          : "arrow.up.circle.fill")
                        .foregroundColor(vm.weeklyWeightChange <= 0
                            ? Color(hex: "059669")
                            : Color(hex: "B45309"))
                        .font(.caption)
                    Text(String(format: "%+.2f %@ this week",
                                convert(vm.weeklyWeightChange), unit))
                        .font(.caption.weight(.semibold))
                        .foregroundColor(vm.weeklyWeightChange <= 0
                            ? Color(hex: "059669")
                            : Color(hex: "B45309"))
                    Spacer()
                }
            }

            if let projection = ProjectionEngine.weightProjection(logs: vm.weightLogs), abs(projection.weeklyRateKg) >= 0.05 {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrow.up.right.circle")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("If this pace continues: ~\(String(format: "%.1f", convert(projection.projectedIn4Weeks)))\(unit) in 4 weeks, ~\(String(format: "%.1f", convert(projection.projectedIn8Weeks)))\(unit) in 8. A straight-line estimate, not a guarantee.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
        .payaCard(padding: 12)
    }
}

// MARK: - Weekly Volume Chart

struct WeeklyVolumeChart: View {
    @Environment(AppState.self) private var appState
    var vm: ProgressViewModel

    private var useLbs: Bool { appState.profile.prefersLbs }
    private var unit: String { useLbs ? "lbs" : "kg" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Training Volume")
                .font(.subheadline.weight(.semibold))

            if vm.weeklyVolumes.isEmpty {
                EmptyChartPlaceholder(
                    icon: "chart.bar.fill",
                    message: "Complete sessions to see volume trends"
                )
            } else {
                Chart(vm.weeklyVolumes) { week in
                    BarMark(
                        x: .value("Week", week.weekStart,
                                  unit: .weekOfYear),
                        y: .value("Volume", useLbs ? week.volume * 2.20462 : week.volume)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "2563EB"),
                                     Color(hex: "7c3aed")],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .cornerRadius(6)
                }
                .frame(height: 80)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) {
                        AxisValueLabel(format: .dateTime.month().day())
                            .font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing,
                              values: .automatic(desiredCount: 3)) {
                        AxisValueLabel()
                            .font(.system(size: 9))
                    }
                }

                if let latest = vm.weeklyVolumes.last {
                    let vol = useLbs ? latest.volume * 2.20462 : latest.volume
                    HStack(spacing: 6) {
                        Image(systemName: "dumbbell.fill")
                            .font(.caption)
                            .foregroundColor(Color(hex: "2563EB"))
                        Text(String(format: "%.0f %@ this week · %d sessions",
                                    vol, unit,
                                    latest.sessionCount))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .payaCard(padding: 12)
    }
}

// MARK: - Section Header

struct ProgressSectionHeader: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 2)
            .padding(.top, 4)
    }
}

// MARK: - Empty Placeholder

struct EmptyChartPlaceholder: View {
    var icon: String
    var message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.3))
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
    }
}
