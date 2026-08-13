import SwiftUI
import SwiftData
import Charts

// MARK: - Acute:Chronic Workload Ratio (ACWR) Card
// A transparent, science-backed alternative to Whoop's opaque $30/mo
// recovery score. Shows the user exactly WHY their fatigue is what it
// is, using Banister's fitness-fatigue model (1975) refined by
// Hulin et al. (2014, 2016) for the ACWR framework.
//
// ACWR = Acute Load (7-day) / Chronic Load (28-day rolling average)
//
// Sweet spot: 0.8–1.3 (Gabbett 2016 "training-injury prevention
// paradox"). Below 0.8 = undertrained/detraining. Above 1.5 = spike
// = injury risk zone.
//
// Paya uses the uncoupled ACWR variant (Windt & Gabbett 2019) which
// excludes the current week from the chronic calculation to avoid
// mathematical coupling.
//
// This card shows:
// 1. Current ACWR ratio with color-coded zone
// 2. 8-week ACWR trend chart
// 3. Breakdown: acute load, chronic load, ratio
// 4. Transparent explanation of each component
// 5. Actionable recommendation based on current zone

struct ACWRCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var acwr: Double = 0
    @State private var acuteLoad: Double = 0
    @State private var chronicLoad: Double = 0
    @State private var zone: WorkloadZone = .optimal
    @State private var weeklyHistory: [(weekStart: Date, acwr: Double)] = []
    @State private var hasData = false
    @State private var sleepFactor: String?
    @State private var sessionCountThisWeek = 0

    var body: some View {
        Group {
            if hasData {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(zone.color)
                        Text("Training load ratio")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(zone.label)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(zone.color)
                            .clipShape(Capsule())
                    }

                    // Main ACWR display
                    HStack(spacing: 16) {
                        // Gauge
                        ZStack {
                            Circle()
                                .stroke(zone.color.opacity(0.15), lineWidth: 7)
                                .frame(width: 64, height: 64)
                            Circle()
                                .trim(from: 0, to: min(1, acwr / 2.0))
                                .stroke(zone.color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                                .frame(width: 64, height: 64)
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 0) {
                                Text(String(format: "%.2f", acwr))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                Text("ACWR")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Breakdown
                        VStack(alignment: .leading, spacing: 6) {
                            loadRow(
                                label: "Acute (7d)",
                                value: acuteLoad,
                                icon: "bolt.fill",
                                color: Color(hex: "F59E0B")
                            )
                            loadRow(
                                label: "Chronic (28d avg)",
                                value: chronicLoad,
                                icon: "chart.line.uptrend.xyaxis",
                                color: Color(hex: "2563EB")
                            )
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                Text("\(sessionCountThisWeek) sessions this week")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // ACWR trend chart
                    if weeklyHistory.count >= 3 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("8-week trend")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)

                            Chart {
                                // Sweet spot zone band
                                RectangleMark(
                                    xStart: .value("", weeklyHistory.first?.weekStart ?? Date()),
                                    xEnd: .value("", weeklyHistory.last?.weekStart ?? Date()),
                                    yStart: .value("Low", 0.8),
                                    yEnd: .value("High", 1.3)
                                )
                                .foregroundStyle(Color(hex: "059669").opacity(0.08))

                                ForEach(weeklyHistory, id: \.weekStart) { entry in
                                    LineMark(
                                        x: .value("Week", entry.weekStart),
                                        y: .value("ACWR", entry.acwr)
                                    )
                                    .foregroundStyle(zone.color)
                                    .interpolationMethod(.catmullRom)

                                    PointMark(
                                        x: .value("Week", entry.weekStart),
                                        y: .value("ACWR", entry.acwr)
                                    )
                                    .foregroundStyle(colorForACWR(entry.acwr))
                                    .symbolSize(16)
                                }
                            }
                            .frame(height: 70)
                            .chartYScale(domain: 0...2)
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) {
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                        .font(.system(size: 8))
                                }
                            }
                            .chartYAxis {
                                AxisMarks(values: [0.5, 0.8, 1.0, 1.3, 1.5, 2.0]) {
                                    AxisValueLabel()
                                        .font(.system(size: 8))
                                    AxisGridLine()
                                }
                            }

                            HStack(spacing: 12) {
                                legendDot(color: Color(hex: "059669"), label: "0.8–1.3 sweet spot")
                                legendDot(color: Color(hex: "F59E0B"), label: ">1.3 spike risk")
                                legendDot(color: Color(hex: "DC2626"), label: ">1.5 danger")
                            }
                        }
                    }

                    // Recommendation
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10))
                            .foregroundColor(zone.color)
                            .padding(.top, 1)
                        Text(zone.recommendation(acwr: acwr, sessionsThisWeek: sessionCountThisWeek))
                            .font(.system(size: 10))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Sleep modifier
                    if let sleepNote = sleepFactor {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "8B5CF6"))
                                .padding(.top, 1)
                            Text(sleepNote)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Text("Gabbett (2016) ACWR framework. Uncoupled variant per Windt & Gabbett (2019). Sweet spot 0.8–1.3 minimizes injury risk while maintaining fitness gains.")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func loadRow(label: String, value: Double, icon: String, color: Color) -> some View {
        let useLbs = appState.profile.prefersLbs
        let display = useLbs ? value * 2.20462 : value
        let unit = useLbs ? "lbs" : "kg"
        return HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.0f %@", display, unit))
                .font(.system(size: 10, weight: .bold))
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label).font(.system(size: 7)).foregroundColor(.secondary)
        }
    }

    private func colorForACWR(_ value: Double) -> Color {
        if value >= 0.8 && value <= 1.3 { return Color(hex: "059669") }
        if value > 1.5 || value < 0.5 { return Color(hex: "DC2626") }
        return Color(hex: "F59E0B")
    }

    // MARK: - Compute ACWR

    private func compute() {
        let calendar = Calendar.current
        let pid = ActiveProfile.id
        let today = calendar.startOfDay(for: Date())

        // Fetch 8 weeks of sessions
        guard let eightWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -8, to: today) else { return }

        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> {
                $0.profileId == pid && $0.isCompleted && $0.date >= eightWeeksAgo
            },
            sortBy: [SortDescriptor(\.date)]
        )
        guard let sessions = try? modelContext.fetch(descriptor), !sessions.isEmpty else { return }

        // Compute volume for each session
        func sessionVolume(_ session: TrainingSession) -> Double {
            session.exercises.reduce(0.0) { t, ex in
                t + ex.sets.filter(\.isCompleted).reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
            }
        }

        // Weekly volumes
        var weeklyVolumes: [Date: Double] = [:]
        for session in sessions {
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.date))!
            weeklyVolumes[weekStart, default: 0] += sessionVolume(session)
        }

        let sortedWeeks = weeklyVolumes.keys.sorted()
        guard sortedWeeks.count >= 2 else { return }

        // Current week (acute)
        let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let acuteSessions = sessions.filter { $0.date >= sevenDaysAgo }
        let acute = acuteSessions.reduce(0.0) { $0 + sessionVolume($1) }

        // Chronic: previous 4 weeks (uncoupled — excludes current week)
        var chronicWeeks: [Double] = []
        for weekOffset in 1...4 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: currentWeekStart) else { continue }
            chronicWeeks.append(weeklyVolumes[weekStart] ?? 0)
        }

        let chronic = chronicWeeks.isEmpty ? 0 : chronicWeeks.reduce(0, +) / Double(chronicWeeks.count)

        guard chronic > 0 else {
            // First month — no chronic baseline
            acuteLoad = acute
            chronicLoad = 0
            acwr = 0
            hasData = false
            return
        }

        acuteLoad = acute
        chronicLoad = chronic
        acwr = acute / chronic
        sessionCountThisWeek = acuteSessions.count
        zone = WorkloadZone.from(acwr)
        hasData = true

        // Build weekly ACWR history
        var history: [(weekStart: Date, acwr: Double)] = []
        for i in 0..<sortedWeeks.count {
            let weekStart = sortedWeeks[i]
            let weekAcute = weeklyVolumes[weekStart] ?? 0
            // Chronic for this week = avg of previous 4 weeks
            var prevWeeks: [Double] = []
            for j in 1...4 {
                guard let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: -j, to: weekStart) else { continue }
                prevWeeks.append(weeklyVolumes[prevWeekStart] ?? 0)
            }
            let weekChronic = prevWeeks.isEmpty ? 0 : prevWeeks.reduce(0, +) / Double(prevWeeks.count)
            if weekChronic > 0 {
                history.append((weekStart, weekAcute / weekChronic))
            }
        }
        weeklyHistory = history.suffix(8).map { $0 }

        // Sleep modifier
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let healthDesc = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> {
                $0.profileId == pid && $0.date >= yesterday && $0.date < today
            }
        )
        if let healthLog = (try? modelContext.fetch(healthDesc))?.first {
            if healthLog.sleepHours < 6 {
                sleepFactor = String(format: "Sleep was %.1fh — your effective recovery capacity is reduced. The ACWR number may understate actual fatigue.", healthLog.sleepHours)
            } else if healthLog.sleepHours >= 8 {
                sleepFactor = String(format: "Sleep was %.1fh — strong recovery support. Your body is better positioned to handle the current load.", healthLog.sleepHours)
            }
        }
    }
}

// MARK: - Workload Zone

private enum WorkloadZone {
    case undertrained
    case optimal
    case caution
    case danger

    var label: String {
        switch self {
        case .undertrained: return "Undertrained"
        case .optimal:      return "Sweet spot"
        case .caution:      return "Spike risk"
        case .danger:       return "Danger zone"
        }
    }

    var color: Color {
        switch self {
        case .undertrained: return Color(hex: "2563EB")
        case .optimal:      return Color(hex: "059669")
        case .caution:      return Color(hex: "F59E0B")
        case .danger:       return Color(hex: "DC2626")
        }
    }

    static func from(_ acwr: Double) -> WorkloadZone {
        if acwr < 0.8 { return .undertrained }
        if acwr <= 1.3 { return .optimal }
        if acwr <= 1.5 { return .caution }
        return .danger
    }

    func recommendation(acwr: Double, sessionsThisWeek: Int) -> String {
        switch self {
        case .undertrained:
            return "Your acute load is below your chronic baseline. If intentional (deload week), this is fine. Otherwise, you're losing fitness — ramp volume back up by ~10% per week."
        case .optimal:
            return "Training load is in the sweet spot. Your body is adapting well to the current stress. Maintain this level and focus on progressive overload within exercises."
        case .caution:
            return "Training load is spiking vs your baseline. Drop \(sessionsThisWeek > 4 ? "1 session" : "2-3 sets per exercise") this week to stay in the adaptation zone. A spike above 1.5 sharply increases injury risk."
        case .danger:
            return "Load spike detected — ACWR \(String(format: "%.2f", acwr)) is well above the safe zone. Reduce this week's volume by 30-40% immediately. The injury risk at this ratio is 2-4× baseline (Gabbett 2016)."
        }
    }
}
