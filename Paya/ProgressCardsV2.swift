import SwiftUI
import SwiftData
import Charts

// MARK: - Exercise Progression Card

struct ExerciseProgressionCard: View {

    var sessions: [TrainingSession]

    @State private var selectedExerciseId: String? = nil

    var loggedExercises: [ProgressAnalytics.LoggedExercise] {
        ProgressAnalytics.loggedExercises(sessions: sessions)
    }

    var selectedExercise: ProgressAnalytics.LoggedExercise? {
        loggedExercises.first { $0.exerciseId == selectedExerciseId }
            ?? loggedExercises.first
    }

    var points: [ProgressAnalytics.ProgressionPoint] {
        guard let ex = selectedExercise else { return [] }
        return ProgressAnalytics.progression(exerciseId: ex.exerciseId, sessions: sessions)
    }

    var pr: ProgressAnalytics.ExercisePR? {
        guard let ex = selectedExercise else { return nil }
        return ProgressAnalytics.personalRecord(exerciseId: ex.exerciseId, sessions: sessions)
    }

    var trendDelta: Double? {
        guard points.count >= 2 else { return nil }
        guard let last = points.last, let first = points.first else { return nil }
        return last.bestE1RM - first.bestE1RM
    }

    var projection: ProjectionEngine.StrengthProjection? {
        guard let ex = selectedExercise else { return nil }
        return ProjectionEngine.strengthProjection(exerciseId: ex.exerciseId, exerciseName: ex.name, sessions: sessions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(Pulse.hydration)
                Text("Strength Progression")
                    .font(.subheadline.weight(.bold))
                CardInfoButton(
                    title: "Strength Progression",
                    explanation: "Tracks estimated 1-rep max (e1RM) per exercise over time, using the Epley formula: weight × (1 + reps/30) — so a heavier set of 5 and a lighter set of 12 can be compared on the same scale even though neither is an actual 1-rep attempt."
                )
                Spacer()
            }

            if loggedExercises.isEmpty {
                Text("Complete sessions to see per-exercise strength trends.")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
                    .padding(.vertical, 10)
            } else {
                // Exercise switcher as quick-tap chips, not a dropdown Menu —
                // switching exercises is the single most common interaction
                // on this card, so it should be a one-tap horizontal scroll
                // (matching how Whoop/Oura switch between metric tabs)
                // rather than opening-then-choosing from a hidden list.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(loggedExercises) { ex in
                            let isSelected = ex.exerciseId == (selectedExerciseId ?? loggedExercises.first?.exerciseId)
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedExerciseId = ex.exerciseId
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text(ex.name)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? Pulse.hydration : Pulse.surfaceElevatedFallback)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(PulsePress())
                        }
                    }
                    .padding(.horizontal, 1)
                }

                // Hero stat — the current e1RM front and center, with the
                // exercise name as a small eyebrow label above it rather
                // than repeated in the chip row.
                if let pr {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedExercise?.name.uppercased() ?? "")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Pulse.textTertiary)
                            .tracking(0.5)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(String(format: "%.1f", pr.bestE1RM))
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(Pulse.textPrimary)
                                .contentTransition(.numericText())
                            Text("kg e1RM")
                                .font(.subheadline)
                                .foregroundColor(Pulse.textTertiary)
                            Spacer()
                            if let delta = trendDelta {
                                HStack(spacing: 3) {
                                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                        .font(.caption.weight(.bold))
                                    Text(String(format: "%+.1fkg", delta))
                                        .font(.subheadline.weight(.bold))
                                }
                                .foregroundColor(delta >= 0 ? Pulse.positive : Pulse.critical)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background((delta >= 0 ? Pulse.positive : Pulse.critical).opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: selectedExerciseId)
                }

                if points.count >= 2 {
                    Chart {
                        ForEach(points) { point in
                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("e1RM", point.bestE1RM)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Pulse.hydration.opacity(0.25), Pulse.hydration.opacity(0.0)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)

                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("e1RM", point.bestE1RM)
                            )
                            .foregroundStyle(Pulse.hydration)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            .interpolationMethod(.catmullRom)
                        }
                        if let last = points.last {
                            PointMark(
                                x: .value("Date", last.date),
                                y: .value("e1RM", last.bestE1RM)
                            )
                            .foregroundStyle(Pulse.hydration)
                            .symbolSize(70)
                        }
                    }
                    .frame(height: 150)
                    .accessibilityLabel("\(selectedExercise?.name ?? "Exercise") progression")
                    .accessibilityValue("Estimated one rep max \(Int(points.last?.bestE1RM ?? 0)) kilograms, \(points.count) sessions tracked")
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text("\(Int(v))")
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date.formatted(.dateTime.day().month(.abbreviated)))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                } else {
                    Text("Log this exercise in at least 2 sessions to see the trend.")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                        .padding(.vertical, 10)
                }

                // PR strip
                if let pr {
                    HStack(spacing: 8) {
                        PRStat(
                            icon: "scalemass.fill",
                            label: "Best Set",
                            value: String(format: "%.1fkg × %d", pr.bestWeight, pr.bestWeightReps),
                            color: Pulse.hydration
                        )
                        PRStat(
                            icon: "bolt.fill",
                            label: "Est. 1RM",
                            value: String(format: "%.1fkg", pr.bestE1RM),
                            color: Pulse.warning
                        )
                        PRStat(
                            icon: "square.stack.3d.up.fill",
                            label: "Best Volume",
                            value: String(format: "%.0fkg", pr.bestSessionVolume),
                            color: Pulse.positive
                        )
                    }
                }

                if let projection, abs(projection.weeklyRateKg) >= 0.1 {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "arrow.up.right.circle")
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                        Text("If this pace continues: ~\(String(format: "%.0f", projection.projectedIn4Weeks))kg e1RM in 4 weeks, ~\(String(format: "%.0f", projection.projectedIn8Weeks))kg in 8. A straight-line estimate, not a guarantee.")
                            .font(.caption2)
                            .foregroundColor(Pulse.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .payaCard(padding: 16)
    }
}

struct PRStat: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundColor(Pulse.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Pulse.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Recent PRs Feed

struct RecentPRsCard: View {

    var sessions: [TrainingSession]

    var events: [ProgressAnalytics.PREvent] {
        Array(ProgressAnalytics.recentPRs(sessions: sessions, daysBack: 30).prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(Pulse.warning)
                Text("Recent Records")
                    .font(.subheadline.weight(.semibold))
                CardInfoButton(
                    title: "Recent Records",
                    explanation: "New personal bests from the last 30 days — heaviest weight, best estimated 1-rep max (Epley formula: weight × (1 + reps/30)), or most reps at a given weight for each exercise."
                )
                Spacer()
                Text("Last 30 days")
                    .font(.caption2)
                    .foregroundColor(Pulse.textTertiary)
            }

            if events.isEmpty {
                Text("Beat a previous best to land a record here. 🏆")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 6) {
                    ForEach(events) { event in
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: event.kind.colorHex).opacity(0.15))
                                    .frame(width: 28, height: 28)
                                Image(systemName: event.kind.icon)
                                    .font(.caption2)
                                    .foregroundColor(Color(hex: event.kind.colorHex))
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.exerciseName)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Text(event.kind.label)
                                    .font(.system(size: 9))
                                    .foregroundColor(Pulse.textTertiary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                if let reps = event.reps {
                                    Text(String(format: "%.1fkg × %d", event.value, reps))
                                        .font(.caption.weight(.bold))
                                        .monospacedDigit()
                                } else {
                                    Text(String(format: "%.1fkg", event.value))
                                        .font(.caption.weight(.bold))
                                        .monospacedDigit()
                                }
                                Text(event.date.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(.system(size: 9))
                                    .foregroundColor(Pulse.textTertiary)
                            }
                        }
                    }
                }
            }
        }
        .payaCard(padding: 10)
    }
}

// MARK: - Volume Landmarks

struct VolumeLandmarkCard: View {
    var sessions: [TrainingSession]

    var volumes: [VolumeLandmarkEngine.MuscleVolume] {
        VolumeLandmarkEngine.weeklyVolume(sessions: sessions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(Pulse.hydration)
                Text("Weekly Volume vs. Landmarks")
                    .font(.subheadline.weight(.semibold))
                CardInfoButton(
                    title: "Weekly Volume vs. Landmarks",
                    explanation: "Hard sets per muscle this week, plotted against published volume landmarks (MEV = minimum effective volume, MAV = maximum adaptive volume, MRV = maximum recoverable volume — from Schoenfeld's volume-response meta-analyses and Israetel/RP's landmark framework). Under MEV won't grow the muscle much; past MRV adds fatigue without more gain."
                )
                Spacer()
                Text("Last 7 days")
                    .font(.caption2)
                    .foregroundColor(Pulse.textTertiary)
            }

            if volumes.isEmpty {
                Text("Log a week of training and this fills in — hard sets per muscle against published volume landmarks (MEV/MAV/MRV).")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 10) {
                    ForEach(volumes) { mv in
                        VolumeLandmarkRow(mv: mv)
                    }
                }

                HStack(spacing: 12) {
                    legendDot(color: "9CA3AF", label: "Under MEV")
                    legendDot(color: "059669", label: "Growing")
                    legendDot(color: "D97706", label: "High")
                    legendDot(color: "DC2626", label: "Excessive")
                }
                .padding(.top, 2)
            }
        }
        .payaCard(padding: 12)
    }

    private func legendDot(color: String, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(Color(hex: color)).frame(width: 6, height: 6)
            Text(label).font(.system(size: 8)).foregroundColor(Pulse.textTertiary)
        }
    }
}

private struct VolumeLandmarkRow: View {
    let mv: VolumeLandmarkEngine.MuscleVolume

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(mv.muscleGroup)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(mv.sets) sets · \(mv.zone.rawValue)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: mv.zone.colorHex))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Pulse.surfaceElevatedFallback)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: mv.zone.colorHex))
                        .frame(width: geo.size.width * mv.fillFraction, height: 6)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 1, height: 10)
                        .offset(x: geo.size.width * mv.mavLowFraction)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 1, height: 10)
                        .offset(x: geo.size.width * mv.mrvFraction)
                }
            }
            .frame(height: 10)
        }
    }
}

// MARK: - Plateau Flags

struct PlateauCard: View {
    var sessions: [TrainingSession]

    var flags: [PlateauEngine.Flag] {
        Array(PlateauEngine.detect(sessions: sessions).prefix(3))
    }

    var body: some View {
        if !flags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.trianglehead.2.clockwise")
                        .foregroundColor(Pulse.warning)
                    Text("Stalled Lifts")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }

                VStack(spacing: 6) {
                    ForEach(flags) { flag in
                        HStack(alignment: .top, spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(flag.exerciseName)
                                    .font(.caption.weight(.semibold))
                                Text(flag.suggestion)
                                    .font(.system(size: 10))
                                    .foregroundColor(Pulse.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .payaCard(padding: 10)
        }
    }
}//
//  ProgressCardsV2.swift
//  Paya
//
//  Created by Emin Huseynzade on 11.07.26.
//

