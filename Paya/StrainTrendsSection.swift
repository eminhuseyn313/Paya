import SwiftUI
import Charts
import SwiftData

// MARK: - HR Recovery Card

struct HRRecoveryCard: View {
    var sessions: [TrainingSession]

    private var recent: [(date: Date, hrr: Int)] {
        sessions
            .compactMap { s in s.hrRecovery60.map { (s.date, $0) } }
            .sorted { $0.0 < $1.0 }
            .suffix(8)
            .map { $0 }
    }

    private var latest: Int? { recent.last?.hrr }

    /// Cole et al. thresholds (1-min HRR): ≤12 poor, 13–24 average, ≥25 well-trained.
    private func interpretation(_ hrr: Int) -> (label: String, colorHex: String) {
        switch hrr {
        case 25...: return ("Well-trained", "059669")
        case 13..<25: return ("Average", "D97706")
        default: return ("Slow — worth watching", "DC2626")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "arrow.down.heart.fill")
                    .foregroundColor(Pulse.critical)
                Text("HR Recovery")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let latest {
                    let interp = interpretation(latest)
                    Text("\(latest) bpm · \(interp.label)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color(hex: interp.colorHex))
                }
            }

            if recent.isEmpty {
                EmptyChartHint(message: "Train with your HR monitor and linger a minute on the completion screen to capture recovery")
            } else {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(recent.enumerated()), id: \.offset) { _, point in
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: interpretation(point.hrr).colorHex).opacity(0.75))
                                .frame(height: max(6, CGFloat(point.hrr) * 1.6))
                            Text(point.date.formatted(.dateTime.day()))
                                .font(.system(size: 8))
                                .foregroundColor(Pulse.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 72, alignment: .bottom)

                Text("How fast your heart rate falls in the minute after your last effort — a direct read on cardiovascular fitness. Higher is better.")
                    .font(.caption2)
                    .foregroundColor(Pulse.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .payaCard(padding: 8)
    }
}

// MARK: - TRIMP Timeline Card

struct TrimpTimelineCard: View {
    var sessions: [TrainingSession]

    var points: [SessionTrendsCalculator.DailyTrimpPoint] {
        SessionTrendsCalculator.trimpTimeline(sessions: sessions, daysBack: 30)
    }

    func color(for type: String) -> Color {
        switch type {
        case "A": return Pulse.hydration
        case "B": return Pulse.positive
        case "C": return Pulse.warning
        default:  return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(Pulse.ai)
                Text("30-day Load")
                    .font(.subheadline.weight(.semibold))
                CardInfoButton(
                    title: "30-day Load",
                    explanation: "TRIMP (Training Impulse) scores each session's cardiovascular cost from heart-rate zones and duration — a way to compare a short intense session against a long easy one on the same scale. Color = your session type (A/B/C)."
                )
                Spacer()
                Text("\(points.count) sessions")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
            }

            if points.isEmpty {
                EmptyChartHint(message: "Complete a session with your HR monitor to see load trends")
            } else {
                Chart {
                    ForEach(points) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("TRIMP", point.trimp)
                        )
                        .foregroundStyle(color(for: point.sessionType ?? "A"))
                        .cornerRadius(3)
                    }
                }
                .frame(height: 78)
                .accessibilityLabel("30 day training load")
                .accessibilityValue("\(points.count) sessions, latest TRIMP \(Int(points.last?.trimp ?? 0))")
                .chartXAxis {
                    AxisMarks(preset: .aligned, values: .stride(by: .day, count: 7)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(preset: .aligned, position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let trimp = value.as(Double.self) {
                                Text("\(Int(trimp))")
                                    .font(.caption2)
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    LegendDot(color: Pulse.hydration, label: "A")
                    LegendDot(color: Pulse.positive, label: "B")
                    LegendDot(color: Pulse.warning, label: "C")
                    Spacer()
                }
            }
        }
        .payaCard(padding: 8)
    }
}

// MARK: - Weekly Load Card

struct WeeklyLoadCard: View {
    var sessions: [TrainingSession]

    var weeks: [SessionTrendsCalculator.WeeklyLoad] {
        SessionTrendsCalculator.weeklyLoad(sessions: sessions, weeksBack: 6)
    }

    var currentTrimp: Double {
        weeks.last?.totalTrimp ?? 0
    }

    var lastWeekTrimp: Double {
        weeks.count >= 2 ? weeks[weeks.count - 2].totalTrimp : 0
    }

    var trendPercent: Int? {
        guard lastWeekTrimp > 0 else { return nil }
        return Int(((currentTrimp - lastWeekTrimp) / lastWeekTrimp) * 100)
    }

    var weeklyLoadAccessibilitySummary: String {
        var text = "This week's load \(Int(currentTrimp))"
        if let trend = trendPercent {
            text += ", \(trend >= 0 ? "up" : "down") \(abs(trend))% versus last week"
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.day.timeline.left")
                    .foregroundColor(Pulse.positive)
                Text("Weekly Rhythm")
                    .font(.subheadline.weight(.semibold))
                CardInfoButton(
                    title: "Weekly Rhythm",
                    explanation: "Total training load (TRIMP) per week over the last 6 weeks — steady week-to-week load without big spikes tends to build fitness with less injury risk than boom-and-bust weeks (the acute:chronic workload literature)."
                )
                Spacer()
                if let trend = trendPercent {
                    HStack(spacing: 3) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text("\(abs(trend))% vs last week")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundColor(trend >= 0 ? Pulse.positive : Pulse.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        (trend >= 0 ? Pulse.positive : Pulse.warning).opacity(0.12)
                    )
                    .clipShape(Capsule())
                }
            }

            if weeks.allSatisfy({ $0.totalTrimp == 0 && $0.sessionCount == 0 }) {
                EmptyChartHint(message: "No sessions logged yet")
            } else {
                Chart {
                    ForEach(weeks) { week in
                        BarMark(
                            x: .value("Week", week.label),
                            y: .value("TRIMP", week.totalTrimp)
                        )
                        .foregroundStyle(Pulse.positive)
                        .cornerRadius(4)
                        .annotation(position: .top) {
                            if week.sessionCount > 0 {
                                Text("\(week.sessionCount)x")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Pulse.textTertiary)
                            }
                        }
                    }
                }
                .frame(height: 70)
                .accessibilityLabel("Weekly training load")
                .accessibilityValue(weeklyLoadAccessibilitySummary)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let label = value.as(String.self) {
                                Text(label)
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                    }
                }
            }
        }
        .payaCard(padding: 8)
    }
}

// MARK: - Session Baselines Card

struct SessionBaselinesCard: View {
    var sessions: [TrainingSession]

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var dayMap: [String: (name: String, focus: String, colorHex: String)] = [:]

    var baselines: [SessionTrendsCalculator.SessionTypeBaseline] {
        SessionTrendsCalculator.baselines(sessions: sessions)
    }

    // Falls back to a neutral, honest "unknown day" presentation rather than
    // a hardcoded A/B/C guess — this card used to describe the OLD fixed
    // 3-day template ("Push · Front Delt" etc.) regardless of what program
    // was actually installed, which was flatly wrong for anyone on a
    // generated program (different day count, different splits, different
    // focus) and blank for any day past C.
    private func color(for code: String) -> Color {
        dayMap[code].map { Color(hex: $0.colorHex) } ?? .secondary
    }

    private func focus(for code: String) -> String {
        dayMap[code]?.focus ?? "Custom day"
    }

    private func reload() {
        var map: [String: (String, String, String)] = [:]
        for config in TrainingDayStore.all(context: modelContext) {
            map[config.code] = (config.name, config.focus, config.colorHex)
        }
        dayMap = map
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gauge.medium")
                    .foregroundColor(Pulse.hydration)
                Text("Session Baselines")
                    .font(.subheadline.weight(.semibold))
                CardInfoButton(
                    title: "Session Baselines",
                    explanation: "Your typical training load (TRIMP) and duration for each session type, built from your own history. \"Last\" compares your most recent session of that type against your average — a big jump up or down is worth noticing."
                )
                Spacer()
            }

            VStack(spacing: 6) {
                ForEach(baselines) { baseline in
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(color(for: baseline.sessionType).opacity(0.15))
                                .frame(width: 32, height: 32)
                            Text(baseline.sessionType)
                                .font(.subheadline.bold())
                                .foregroundColor(color(for: baseline.sessionType))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(focus(for: baseline.sessionType))
                                .font(.caption.weight(.semibold))
                            if baseline.count == 0 {
                                Text("No data yet")
                                    .font(.caption2)
                                    .foregroundColor(Pulse.textTertiary)
                            } else {
                                HStack(spacing: 6) {
                                    Text("Avg TRIMP \(Int(baseline.avgTrimp))")
                                        .font(.caption2)
                                    Text("·")
                                        .foregroundColor(Pulse.textTertiary)
                                    Text("\(Int(baseline.avgDurationMin))m")
                                        .font(.caption2)
                                    Text("·")
                                        .foregroundColor(Pulse.textTertiary)
                                    Text("\(baseline.count)x")
                                        .font(.caption2)
                                }
                                .foregroundColor(Pulse.textTertiary)
                            }
                        }
                        Spacer()
                        if let last = baseline.lastTrimp, last > 0 {
                            let delta = last - baseline.avgTrimp
                            VStack(alignment: .trailing, spacing: 1) {
                                Text("Last")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(Pulse.textTertiary)
                                Text("\(Int(last))")
                                    .font(.caption.weight(.bold))
                                if abs(delta) >= 5 {
                                    Text(delta > 0 ? "+\(Int(delta))" : "\(Int(delta))")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(delta > 0
                                            ? Pulse.warning
                                            : Pulse.positive)
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(Pulse.surfaceElevatedFallback)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .payaCard(padding: 8)
        .onAppear { reload() }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in reload() }
    }
}

// MARK: - Felt vs Measured Card

struct FeltVsMeasuredCard: View {
    var sessions: [TrainingSession]

    var report: SessionTrendsCalculator.FeltVsMeasured {
        SessionTrendsCalculator.feltVsMeasured(sessions: sessions)
    }

    var perSession: [SessionTrendsCalculator.PerSessionComparison] {
        SessionTrendsCalculator.perSessionFeltVsMeasured(sessions: sessions)
    }

    func color(for type: String) -> Color {
        switch type {
        case "A": return Pulse.hydration
        case "B": return Pulse.positive
        case "C": return Pulse.warning
        default:  return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: report.calibrationHint.icon)
                    .foregroundColor(Color(hex: report.calibrationHint.color))
                Text("Felt vs Measured")
                    .font(.subheadline.weight(.semibold))
                CardInfoButton(
                    title: "Felt vs Measured",
                    explanation: "Compares your self-rated effort (RPE) against what your heart rate actually measured. Consistently rating sessions harder than your HR suggests can mean under-recovery or a mismatch between perceived and actual intensity — either is worth noticing."
                )
                Spacer()
                if report.sessionCount >= 3 {
                    Text("\(report.sessionCount) sessions")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                }
            }

            if let subj = report.avgSubjectiveRPE,
               let obj = report.avgObjectiveIntensity {
                HStack(spacing: 10) {
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", subj))
                            .font(.title3.bold())
                            .foregroundColor(Pulse.ai)
                            .monospacedDigit()
                        Text("Felt")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Pulse.textTertiary)
                        Text("Your RPE")
                            .font(.system(size: 9))
                            .foregroundColor(Pulse.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Pulse.ai.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", obj))
                            .font(.title3.bold())
                            .foregroundColor(Pulse.critical)
                            .monospacedDigit()
                        Text("Measured")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Pulse.textTertiary)
                        Text("HR-derived")
                            .font(.system(size: 9))
                            .foregroundColor(Pulse.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Pulse.critical.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            Text(report.calibrationHint.message)
                .font(.caption)
                .foregroundColor(Pulse.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            if !perSession.isEmpty {
                Divider()
                VStack(spacing: 6) {
                    ForEach(perSession) { comparison in
                        HStack(spacing: 8) {
                            Text(comparison.sessionType)
                                .font(.caption2.weight(.bold))
                                .foregroundColor(color(for: comparison.sessionType))
                                .frame(width: 16)
                            Text(comparison.date.formatted(.dateTime.day().month(.abbreviated)))
                                .font(.caption2)
                                .foregroundColor(Pulse.textTertiary)
                            Spacer()
                            Text("Felt \(comparison.subjectiveRPE)")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(Pulse.ai)
                            Text("·")
                                .foregroundColor(Pulse.textTertiary)
                            Text(String(format: "Measured %.1f", comparison.objectiveIntensity))
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(Pulse.critical)
                        }
                    }
                }
            }
        }
        .payaCard(padding: 8)
    }
}

// MARK: - Helpers

struct LegendDot: View {
    var color: Color
    var label: String

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Pulse.textTertiary)
        }
    }
}

struct EmptyChartHint: View {
    var message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundColor(Pulse.textTertiary)
            Text(message)
                .font(.caption)
                .foregroundColor(Pulse.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
    }
}//
//  StrainTrendsSection.swift
//  Paya
//
//  Created by Emin Huseynzade on 05.07.26.
//  vv

