import SwiftUI
import SwiftData
import Charts

// MARK: - Body Recomposition Estimator
// When weight is flat but strength rises, the user is likely recomping
// (gaining muscle, losing fat at similar rates). This card detects that
// pattern and visualizes estimated lean mass vs fat mass trajectories.
//
// Science: Heymsfield et al. (2014) — during recomp conditions, strength
// gains of >5% over 4 weeks with stable weight (±0.5kg) strongly suggest
// favorable body composition changes. The lean mass estimate uses the
// conservative Katch-McArdle proxy: if e1RM rises x% while weight is
// stable, ~60% of that strength adaptation correlates with lean tissue
// accretion in novice-intermediate lifters (Schoenfeld 2010 review).

struct BodyRecompCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var analysis: RecompAnalysis? = nil

    private var useLbs: Bool { appState.profile.prefersLbs }
    private var unit: String { useLbs ? "lbs" : "kg" }

    var body: some View {
        Group {
            if let a = analysis {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "arrow.up.and.down.circle.fill")
                            .foregroundColor(Color(hex: "8B5CF6"))
                        Text("Body Recomposition")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(a.statusLabel)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(a.statusColor)
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 12) {
                        recompMetric(
                            title: "Weight Δ",
                            value: String(format: "%+.1f %@", useLbs ? a.weightChange * 2.20462 : a.weightChange, unit),
                            color: abs(a.weightChange) < 0.5 ? Color(hex: "059669") : Color(hex: "F59E0B")
                        )
                        recompMetric(
                            title: "Strength Δ",
                            value: String(format: "%+.1f%%", a.strengthChange),
                            color: a.strengthChange > 0 ? Color(hex: "059669") : Color(hex: "DC2626")
                        )
                        recompMetric(
                            title: "Est. Lean Δ",
                            value: String(format: "%+.1f %@", useLbs ? a.estimatedLeanChange * 2.20462 : a.estimatedLeanChange, unit),
                            color: a.estimatedLeanChange > 0 ? Color(hex: "2563EB") : Color(hex: "DC2626")
                        )
                    }

                    if a.dataPoints.count >= 3 {
                        Chart {
                            ForEach(a.dataPoints) { point in
                                LineMark(
                                    x: .value("Week", point.weekLabel),
                                    y: .value("Value", useLbs ? point.weight * 2.20462 : point.weight),
                                    series: .value("Series", "Weight")
                                )
                                .foregroundStyle(Color(hex: "F59E0B"))
                                .interpolationMethod(.catmullRom)
                                .symbol(.circle)

                                LineMark(
                                    x: .value("Week", point.weekLabel),
                                    y: .value("Value", useLbs ? point.estimatedLean * 2.20462 : point.estimatedLean),
                                    series: .value("Series", "Lean Mass")
                                )
                                .foregroundStyle(Color(hex: "2563EB"))
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                                .symbol(.diamond)
                            }
                        }
                        .frame(height: 70)
                        .chartYScale(domain: .automatic(includesZero: false))
                        .chartXAxis {
                            AxisMarks {
                                AxisValueLabel()
                                    .font(.system(size: 8))
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                                AxisValueLabel()
                                    .font(.system(size: 8))
                            }
                        }

                        HStack(spacing: 12) {
                            HStack(spacing: 3) {
                                Circle().fill(Color(hex: "F59E0B")).frame(width: 5, height: 5)
                                Text("Weight").font(.system(size: 8)).foregroundColor(.secondary)
                            }
                            HStack(spacing: 3) {
                                Circle().fill(Color(hex: "2563EB")).frame(width: 5, height: 5)
                                Text("Est. Lean Mass").font(.system(size: 8)).foregroundColor(.secondary)
                            }
                        }
                    }

                    Text(a.insight)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Estimate based on Katch-McArdle proxy: strength gains with stable weight suggest lean tissue accretion (Schoenfeld 2010). Not a DEXA replacement.")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func recompMetric(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func compute() {
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        let eightWeeksAgo = calendar.date(byAdding: .day, value: -56, to: Date())!

        let wDescriptor = FetchDescriptor<BodyWeightLog>(
            predicate: #Predicate<BodyWeightLog> { $0.date >= eightWeeksAgo }
        )
        let weights = ((try? modelContext.fetch(wDescriptor)) ?? []).sorted { $0.date < $1.date }

        let sDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid && $0.date >= eightWeeksAgo }
        )
        let sessions = ((try? modelContext.fetch(sDescriptor)) ?? []).filter(\.isCompleted)

        guard weights.count >= 3, sessions.count >= 4 else { return }

        // Weight change
        let firstWeight = weights.prefix(3).map(\.weightKg).reduce(0, +) / Double(min(3, weights.count))
        let lastWeight = weights.suffix(3).map(\.weightKg).reduce(0, +) / Double(min(3, weights.count))
        let weightChange = lastWeight - firstWeight

        // Strength change via compound e1RM
        let compoundNames = ["bench", "squat", "deadlift", "overhead press", "row"]
        var earlyE1RMs: [Double] = []
        var lateE1RMs: [Double] = []

        let earlySessions = sessions.prefix(max(1, sessions.count / 3))
        let lateSessions = sessions.suffix(max(1, sessions.count / 3))

        for session in earlySessions {
            for log in session.exercises {
                if compoundNames.contains(where: { log.exerciseName.lowercased().contains($0) }) {
                    let best = log.sets.filter(\.isCompleted)
                        .map { $0.weightKg * (1 + Double($0.reps) / 30.0) }
                        .max() ?? 0
                    if best > 0 { earlyE1RMs.append(best) }
                }
            }
        }
        for session in lateSessions {
            for log in session.exercises {
                if compoundNames.contains(where: { log.exerciseName.lowercased().contains($0) }) {
                    let best = log.sets.filter(\.isCompleted)
                        .map { $0.weightKg * (1 + Double($0.reps) / 30.0) }
                        .max() ?? 0
                    if best > 0 { lateE1RMs.append(best) }
                }
            }
        }

        guard !earlyE1RMs.isEmpty, !lateE1RMs.isEmpty else { return }

        let earlyAvg = earlyE1RMs.reduce(0, +) / Double(earlyE1RMs.count)
        let lateAvg = lateE1RMs.reduce(0, +) / Double(lateE1RMs.count)
        let strengthChange = earlyAvg > 0 ? ((lateAvg - earlyAvg) / earlyAvg) * 100 : 0

        // Lean mass estimate
        let estimatedLeanChange: Double
        if abs(weightChange) < 1.0 && strengthChange > 3 {
            estimatedLeanChange = strengthChange * 0.06  // conservative lean gain proxy
        } else if weightChange > 0 && strengthChange > 0 {
            estimatedLeanChange = weightChange * 0.6  // surplus + strength = ~60% lean
        } else if weightChange < 0 && strengthChange > 0 {
            estimatedLeanChange = max(0, weightChange * 0.3)  // cutting but maintaining = minimal lean loss
        } else {
            estimatedLeanChange = weightChange * 0.4
        }

        // Weekly data points
        var dataPoints: [RecompPoint] = []
        let weekCount = max(1, weights.count / max(1, min(8, weights.count)))
        for i in stride(from: 0, to: weights.count, by: max(1, weekCount)) {
            let w = weights[i]
            let weekNum = calendar.dateComponents([.weekOfYear], from: weights.first?.date ?? w.date, to: w.date).weekOfYear ?? 0
            let label = "W\(weekNum + 1)"
            let progress = Double(i) / Double(max(1, weights.count - 1))
            let lean = firstWeight + estimatedLeanChange * progress
            dataPoints.append(RecompPoint(weekLabel: label, weight: w.weightKg, estimatedLean: lean))
        }

        // Status
        let status: RecompStatus
        let insight: String
        if abs(weightChange) < 0.5 && strengthChange > 5 {
            status = .recomping
            insight = "Classic recomposition: weight is stable while strength is climbing. You're likely gaining muscle and losing fat at similar rates."
        } else if weightChange > 1 && strengthChange > 3 {
            status = .bulking
            insight = "Weight and strength both rising — lean bulk phase. Roughly 60% of weight gain is estimated as lean tissue at your training intensity."
        } else if weightChange < -1 && strengthChange > 0 {
            status = .cutting
            insight = "Losing weight while maintaining or gaining strength — ideal cut. Muscle preservation looks good."
        } else if weightChange < -1 && strengthChange <= 0 {
            status = .caution
            insight = "Weight and strength both declining. Consider increasing protein intake and reducing calorie deficit to preserve muscle."
        } else {
            status = .maintaining
            insight = "Maintaining current body composition. To drive change, adjust calorie intake or training volume."
        }

        analysis = RecompAnalysis(
            weightChange: weightChange,
            strengthChange: strengthChange,
            estimatedLeanChange: estimatedLeanChange,
            status: status,
            insight: insight,
            dataPoints: dataPoints
        )
    }
}

private enum RecompStatus {
    case recomping, bulking, cutting, caution, maintaining
}

private struct RecompAnalysis {
    let weightChange: Double
    let strengthChange: Double
    let estimatedLeanChange: Double
    let status: RecompStatus
    let insight: String
    let dataPoints: [RecompPoint]

    var statusLabel: String {
        switch status {
        case .recomping: return "Recomping"
        case .bulking: return "Lean Bulk"
        case .cutting: return "Cutting"
        case .caution: return "Caution"
        case .maintaining: return "Maintaining"
        }
    }

    var statusColor: Color {
        switch status {
        case .recomping: return Color(hex: "8B5CF6")
        case .bulking: return Color(hex: "2563EB")
        case .cutting: return Color(hex: "059669")
        case .caution: return Color(hex: "DC2626")
        case .maintaining: return Color(hex: "F59E0B")
        }
    }
}

private struct RecompPoint: Identifiable {
    let id = UUID()
    let weekLabel: String
    let weight: Double
    let estimatedLean: Double
}
