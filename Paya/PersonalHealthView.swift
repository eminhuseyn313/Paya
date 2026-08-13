import SwiftUI
import SwiftData
import CoreLocation
import Charts

struct PersonalHealthView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var overview: DayOverview?
    @State private var isLoading = true
    @State private var calendarService = CalendarService.shared
    @State private var weatherService = WeatherService.shared
    @State private var showFullDay = false
    @State private var selectedDate = Date()
    @State private var weekSummaries: [WeekDaySummary] = []
    @State private var isLoadingWeek = true
    @State private var readiness: ReadinessEngine.Report?
    @State private var showReadinessDetail = false
    @State private var dayProgress = LoadProgress(total: 6)
    @State private var weekProgress = LoadProgress(total: 7)

    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    DayNavigator(selectedDate: $selectedDate, isToday: isToday) {
                        Task { await load() }
                    }

                    if !calendarService.isAuthorized || permissionNeedsWeather {
                        PermissionBanner(
                            calendarService: calendarService,
                            weatherService: weatherService,
                            onGranted: { Task { await load() } }
                        )
                    }

                    if isLoading {
                        RealProgressBar(
                            progress: dayProgress,
                            title: isToday ? "Building today's picture…" : "Loading that day…"
                        )
                        .padding(.top, 60)
                    } else if let overview {

                        // Readiness card (today only)
                        if isToday, let readiness {
                            Button { showReadinessDetail = true } label: {
                                ReadinessMiniCard(report: readiness)
                            }
                            .buttonStyle(.plain)
                        }

                        // Walk nudge
                        if isToday, let nudge = PersonalHealthTimelineEngine.suggestedWalkWindow(blocks: overview.hours) {
                            NudgeCard(text: nudge)
                        }

                        // Symptom log — quick entry + today's logged symptoms
                        if isToday {
                            SymptomTimelineCard(symptomLogs: overview.symptomLogs, onLogged: { Task { await load() } })
                        }

                        // Quick stats — 2x2 grid
                        SummaryStatsGrid(overview: overview)

                        // Today's connections
                        if !overview.insights.isEmpty {
                            InsightsCard(insights: overview.insights)
                        }

                        // BODY section — biometrics grouped (always shown; includes sleep-missing hint)
                        BodySection(overview: overview)

                        // ACTIVITY section — steps + calories
                        ActivitySection(overview: overview)

                        // ENVIRONMENT section — weather + noise
                        if hasEnvironmentData(overview) {
                            EnvironmentSection(overview: overview)
                        }

                        // Timeline — hour by hour
                        TimelineSection(hours: displayedHours(overview), showFullDay: $showFullDay)

                        // Weekly patterns
                        if isLoadingWeek {
                            RealProgressBar(progress: weekProgress, title: "Building this week's picture…")
                                .padding(.top, 8)
                        } else if !weekSummaries.isEmpty {
                            WeeklyPatternsCard(summaries: weekSummaries)
                        }
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .navigationTitle("Personal Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .task { await load() }
            .task { await loadWeek() }
            .sheet(isPresented: $showReadinessDetail) {
                if let readiness {
                    ReadinessDetailView(report: readiness)
                }
            }
        }
    }

    private func loadWeek() async {
        isLoadingWeek = true
        weekProgress.reset(total: 7)
        weekSummaries = await PersonalHealthTimelineEngine.buildWeekSummary(context: modelContext, progress: weekProgress)
        isLoadingWeek = false
    }

    private var permissionNeedsWeather: Bool {
        weatherService.authorizationStatus != .authorizedWhenInUse && weatherService.authorizationStatus != .authorizedAlways
    }

    private func displayedHours(_ overview: DayOverview) -> [HourBlock] {
        showFullDay ? overview.hours : overview.hours.filter { $0.hasAnyData || (6...23).contains($0.hour) }
    }

    private func load() async {
        isLoading = true
        dayProgress.reset(total: 6)
        overview = await PersonalHealthTimelineEngine.build(for: selectedDate, context: modelContext, progress: dayProgress)
        if isToday {
            readiness = ReadinessEngine.compute(store: BiometricStore.shared, context: modelContext)
        }
        isLoading = false
    }

    private func hasBodyData(_ o: DayOverview) -> Bool {
        o.hours.contains { $0.avgHR != nil } || o.sleepHours != nil
    }

    private func hasEnvironmentData(_ o: DayOverview) -> Bool {
        o.hours.contains { $0.weather != nil || $0.noiseDb != nil }
    }
}

// MARK: - Day Navigator

struct DayNavigator: View {
    @Binding var selectedDate: Date
    let isToday: Bool
    var onChange: () -> Void

    private var label: String {
        if isToday { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        return selectedDate.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                onChange()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Previous day")

            Spacer()

            Text(label)
                .font(.subheadline.weight(.bold))

            Spacer()

            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                onChange()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .background(isToday ? Color.clear : Color(.secondarySystemBackground))
                    .clipShape(Circle())
                    .opacity(isToday ? 0.3 : 1)
            }
            .disabled(isToday)
            .accessibilityLabel("Next day")
        }
    }
}

// MARK: - Permission Banner

struct PermissionBanner: View {
    var calendarService: CalendarService
    var weatherService: WeatherService
    var onGranted: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(Color(hex: "8B5CF6"))
                Text("Connect the full picture")
                    .font(.subheadline.weight(.bold))
            }
            Text("Add your calendar and location to see events and weather alongside your health data.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                if !calendarService.isAuthorized {
                    Button {
                        Task {
                            _ = await calendarService.requestAccess()
                            onGranted()
                        }
                    } label: {
                        Label("Calendar", systemImage: "calendar")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: "8B5CF6").opacity(0.12))
                            .foregroundColor(Color(hex: "8B5CF6"))
                            .clipShape(Capsule())
                    }
                }
                if weatherService.authorizationStatus != .authorizedWhenInUse && weatherService.authorizationStatus != .authorizedAlways {
                    Button {
                        weatherService.requestAccess()
                    } label: {
                        Label("Weather", systemImage: "location.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: "8B5CF6").opacity(0.12))
                            .foregroundColor(Color(hex: "8B5CF6"))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(14)
        .background(Color(hex: "8B5CF6").opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "8B5CF6").opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Readiness Mini Card

struct ReadinessMiniCard: View {
    let report: ReadinessEngine.Report
    private var color: Color { Color(hex: report.band.colorHex) }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 6)
                    .frame(width: 54, height: 54)
                Circle()
                    .trim(from: 0, to: Double(report.score) / 100.0)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(-90))
                    .animation(PayaAnimation.dataChange, value: report.score)
                HeroNumberText(value: "\(report.score)", size: 17, color: color)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Readiness \(report.score) of 100, \(report.band.rawValue)")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Readiness")
                        .font(.subheadline.weight(.bold))
                    Text(report.band.rawValue)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                }
                if let note = report.journeyNotes.first {
                    Text(note)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Nudge Card

struct NudgeCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "figure.walk.circle.fill")
                .font(.title3)
                .foregroundColor(Color(hex: "B45309"))
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(12)
        .background(Color(hex: "B45309").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "B45309").opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Summary Stats Grid

struct SummaryStatsGrid: View {
    let overview: DayOverview

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatTile(icon: "figure.walk", value: "\(overview.totalSteps)", label: "Steps today", color: "059669")
            StatTile(icon: "moon.fill", value: overview.sleepHours.map { String(format: "%.1fh", $0) } ?? "—", label: "Sleep", color: "8B5CF6")
            StatTile(icon: "fork.knife", value: "\(overview.mealCount)", label: "Meals logged", color: "D97706")
            StatTile(icon: "drop.fill", value: "\(overview.totalWaterMl)ml", label: "Water", color: "0891B2")
        }
    }
}

struct StatTile: View {
    let icon: String
    let value: String
    let label: String
    let color: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(Color(hex: color))
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .payaCard(padding: 12)
    }
}

// MARK: - Insights Card

struct InsightsCard: View {
    let insights: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .foregroundColor(Color(hex: "2563EB"))
                Text("Today's connections")
                    .font(.subheadline.weight(.bold))
            }
            ForEach(insights, id: \.self) { insight in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Color(hex: "2563EB"))
                        .frame(width: 4, height: 4)
                        .padding(.top, 6)
                    Text(insight)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Body Section (HR + Sleep)

struct BodySection: View {
    let overview: DayOverview

    private var hrData: [(hour: Int, hr: Double)] {
        overview.hours.compactMap { block in
            guard let hr = block.avgHR else { return nil }
            return (block.hour, hr)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(icon: "heart.text.clipboard", title: "Body", color: "DC2626")

            if !hrData.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Heart Rate")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        if let min = hrData.map(\.hr).min(), let max = hrData.map(\.hr).max() {
                            Text("\(Int(min))–\(Int(max)) bpm")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Chart(hrData, id: \.hour) { point in
                        LineMark(
                            x: .value("Hour", point.hour),
                            y: .value("BPM", point.hr)
                        )
                        .foregroundStyle(Color(hex: "DC2626"))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Hour", point.hour),
                            y: .value("BPM", point.hr)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "DC2626").opacity(0.15), Color.clear],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis {
                        AxisMarks(values: [0, 6, 12, 18]) { val in
                            AxisValueLabel {
                                if let h = val.as(Int.self) {
                                    Text(h == 0 ? "12A" : h == 12 ? "12P" : h < 12 ? "\(h)A" : "\(h-12)P")
                                        .font(.system(size: 9))
                                }
                            }
                        }
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 80)
                }
                .payaCard(padding: 12)
            }

            if let sleep = overview.sleepHours {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "8B5CF6").opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "moon.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "8B5CF6"))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.1f hours", sleep))
                            .font(.subheadline.weight(.bold))
                        let quality = sleep >= 7 ? "Within recommended range" : sleep >= 6 ? "Slightly below optimal" : "Below recommended 7-9h"
                        Text(quality)
                            .font(.caption2)
                            .foregroundColor(sleep >= 7 ? Color(hex: "059669") : Color(hex: "F59E0B"))
                    }
                    Spacer()
                    if let onset = overview.sleepOnsetHour {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Bedtime")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            let hr = Int(onset) % 24
                            let mn = Int((onset - Double(Int(onset))) * 60)
                            let h12 = hr % 12 == 0 ? 12 : hr % 12
                            Text(String(format: "%d:%02d%@", h12, mn, hr < 12 || hr == 24 ? "am" : "pm"))
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
                .payaCard(padding: 12)
            } else {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "8B5CF6").opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "moon.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: "8B5CF6"))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sleep")
                            .font(.subheadline.weight(.bold))
                        Text("No sleep data — wear your Apple Watch to bed, or check Health app permissions for Sleep.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .payaCard(padding: 12)
            }
        }
    }
}

// MARK: - Activity Section (Steps chart)

struct ActivitySection: View {
    let overview: DayOverview

    private var stepData: [(hour: Int, steps: Int)] {
        overview.hours.filter { $0.steps > 0 }.map { ($0.hour, $0.steps) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(icon: "figure.walk", title: "Activity", color: "059669")

            if !stepData.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Steps by Hour")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("\(overview.totalSteps) total")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Chart(stepData, id: \.hour) { point in
                        BarMark(
                            x: .value("Hour", point.hour),
                            y: .value("Steps", point.steps)
                        )
                        .foregroundStyle(Color(hex: "059669").opacity(0.7))
                        .cornerRadius(3)
                    }
                    .chartXAxis {
                        AxisMarks(values: [0, 6, 12, 18]) { val in
                            AxisValueLabel {
                                if let h = val.as(Int.self) {
                                    Text(h == 0 ? "12A" : h == 12 ? "12P" : h < 12 ? "\(h)A" : "\(h-12)P")
                                        .font(.system(size: 9))
                                }
                            }
                        }
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 70)
                }
                .payaCard(padding: 12)
            }

            if overview.sunnyHoursWalked > 0 || overview.timeInDaylightMin > 0 {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "B45309").opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "B45309"))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        if overview.timeInDaylightMin > 0 {
                            Text("\(overview.timeInDaylightMin) min in daylight")
                                .font(.caption.weight(.semibold))
                        }
                        if overview.sunnyHoursWalked > 0 {
                            Text("\(overview.sunnyHoursWalked) sunny hour\(overview.sunnyHoursWalked == 1 ? "" : "s") with steps")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .payaCard(padding: 12)
            }
        }
    }
}

// MARK: - Environment Section (Weather + Noise)

struct EnvironmentSection: View {
    let overview: DayOverview

    private var weatherHours: [(hour: Int, temp: Double, icon: String, sunny: Bool)] {
        overview.hours.compactMap { block in
            guard let w = block.weather else { return nil }
            return (block.hour, w.temperatureC, w.systemImage, w.isSunny)
        }
    }

    private var noiseHours: [(hour: Int, db: Double)] {
        overview.hours.compactMap { block in
            guard let n = block.noiseDb else { return nil }
            return (block.hour, n)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(icon: "cloud.sun", title: "Environment", color: "0891B2")

            if !weatherHours.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Temperature")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        if let min = weatherHours.map(\.temp).min(), let max = weatherHours.map(\.temp).max() {
                            Text("\(Int(min))°–\(Int(max))°C")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Chart(weatherHours, id: \.hour) { point in
                        LineMark(
                            x: .value("Hour", point.hour),
                            y: .value("Temp", point.temp)
                        )
                        .foregroundStyle(Color(hex: "0891B2"))
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis {
                        AxisMarks(values: [0, 6, 12, 18]) { val in
                            AxisValueLabel {
                                if let h = val.as(Int.self) {
                                    Text(h == 0 ? "12A" : h == 12 ? "12P" : h < 12 ? "\(h)A" : "\(h-12)P")
                                        .font(.system(size: 9))
                                }
                            }
                        }
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 60)

                    // Weather condition icons row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(weatherHours.filter { [6,8,10,12,14,16,18,20].contains($0.hour) }, id: \.hour) { w in
                                VStack(spacing: 2) {
                                    Image(systemName: w.icon)
                                        .font(.system(size: 11))
                                        .foregroundColor(w.sunny ? Color(hex: "B45309") : .secondary)
                                    Text("\(Int(w.temp))°")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                    Text(hourLabel(w.hour))
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 36)
                            }
                        }
                    }
                }
                .payaCard(padding: 12)
            }

            if !noiseHours.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Ambient Noise")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        let loud = noiseHours.filter { $0.db >= 70 }.count
                        if loud > 0 {
                            Text("\(loud) hour\(loud == 1 ? "" : "s") above 70dB")
                                .font(.caption2)
                                .foregroundColor(Color(hex: "DC2626"))
                        }
                    }

                    Chart(noiseHours, id: \.hour) { point in
                        BarMark(
                            x: .value("Hour", point.hour),
                            y: .value("dB", point.db)
                        )
                        .foregroundStyle(point.db >= 70 ? Color(hex: "DC2626").opacity(0.7) : Color(hex: "0891B2").opacity(0.5))
                        .cornerRadius(3)
                    }
                    .chartXAxis {
                        AxisMarks(values: [0, 6, 12, 18]) { val in
                            AxisValueLabel {
                                if let h = val.as(Int.self) {
                                    Text(h == 0 ? "12A" : h == 12 ? "12P" : h < 12 ? "\(h)A" : "\(h-12)P")
                                        .font(.system(size: 9))
                                }
                            }
                        }
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 60)
                }
                .payaCard(padding: 12)
            }
        }
    }

    private func hourLabel(_ h: Int) -> String {
        let h12 = h % 12 == 0 ? 12 : h % 12
        return "\(h12)\(h < 12 ? "a" : "p")"
    }
}

// MARK: - Section Label

struct SectionLabel: View {
    let icon: String
    let title: String
    let color: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(Color(hex: color))
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }
}

// MARK: - Weekly Patterns

struct WeeklyPatternsCard: View {
    let summaries: [WeekDaySummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.day.timeline.left")
                    .foregroundColor(Color(hex: "059669"))
                Text("This week's pattern")
                    .font(.subheadline.weight(.bold))
            }

            Chart(summaries) { day in
                BarMark(
                    x: .value("Day", day.weekdayLabel),
                    y: .value("Steps", day.totalSteps)
                )
                .foregroundStyle(Color(hex: "059669").opacity(0.8))
                .cornerRadius(4)
            }
            .frame(height: 110)
            .chartYAxis(.hidden)

            HStack(spacing: 0) {
                ForEach(summaries) { day in
                    VStack(spacing: 3) {
                        if let sleep = day.sleepHours {
                            Text(String(format: "%.1fh", sleep))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Color(hex: "8B5CF6"))
                        } else {
                            Text("—")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        if let energy = day.checkInEnergy {
                            Image(systemName: energy >= 3 ? "bolt.fill" : "bolt.slash")
                                .font(.system(size: 8))
                                .foregroundColor(energy >= 3 ? Color(hex: "B45309") : .secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(PersonalHealthTimelineEngine.buildWeekInsights(summaries), id: \.self) { insight in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(Color(hex: "059669"))
                            .frame(width: 4, height: 4)
                            .padding(.top, 6)
                        Text(insight)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .payaCard(padding: 14)
    }
}

// MARK: - Timeline (Hour by Hour)

struct TimelineSection: View {
    let hours: [HourBlock]
    @Binding var showFullDay: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(icon: "clock", title: "Timeline", color: "6B7280")
                Spacer()
                Button(showFullDay ? "Waking hours" : "Full 24h") {
                    withAnimation { showFullDay.toggle() }
                }
                .font(.caption.weight(.semibold))
            }

            VStack(spacing: 0) {
                ForEach(hours) { hour in
                    HourRow(block: hour)
                    if hour.id != hours.last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: PayaRadius.card))
        }
    }
}

struct HourRow: View {
    let block: HourBlock

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(block.label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(width: 42, alignment: .leading)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 4) {
                // Primary data chips
                HStack(spacing: 6) {
                    if block.isAsleep {
                        DataChip(icon: "moon.fill", text: "Sleep", color: "8B5CF6")
                    }
                    if block.steps > 0 {
                        DataChip(icon: "figure.walk", text: "\(block.steps)", color: "059669")
                    }
                    if let hr = block.avgHR {
                        DataChip(icon: "heart.fill", text: "\(Int(hr))", color: "DC2626")
                    }
                    if !block.meals.isEmpty {
                        DataChip(icon: "fork.knife", text: "\(block.meals.count)", color: "D97706")
                    }
                    if block.waterMl > 0 {
                        DataChip(icon: "drop.fill", text: "\(block.waterMl)ml", color: "0891B2")
                    }
                    Spacer()
                }

                // Events
                ForEach(block.events) { event in
                    Text(event.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(Color(hex: event.calendarColorHex))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(hex: event.calendarColorHex).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }

                // Meals
                ForEach(block.meals, id: \.id) { meal in
                    Text("\(meal.name): \(meal.food)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 8)

            Spacer()
        }
        .padding(.horizontal, 12)
        .background(block.isAsleep ? Color(hex: "8B5CF6").opacity(0.05) : Color.clear)
        .opacity(block.hasAnyData ? 1.0 : 0.45)
    }
}

// MARK: - Data Chip

struct DataChip: View {
    let icon: String
    let text: String
    let color: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(Color(hex: color))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color(hex: color).opacity(0.08))
        .clipShape(Capsule())
    }
}
