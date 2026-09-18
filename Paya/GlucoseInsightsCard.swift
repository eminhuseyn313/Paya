import SwiftUI
import SwiftData

// MARK: - Glucose Insights Card
//
// Surfaces CGM data insights on the Health tab. Reads blood glucose
// from HealthKit (written by Dexcom Stelo, Abbott Lingo/Libre, or
// any CGM that syncs to Apple Health) and correlates with meals and
// training sessions.
//
// Only appears when the user actually has glucose data — zero UI
// footprint for users without a CGM.

struct GlucoseInsightsCard: View {

    @Environment(\.modelContext) private var modelContext
    @State private var overview: GlucoseEngine.GlucoseOverview?
    @State private var isLoading = true
    @State private var showDetail = false

    var body: some View {
        if isLoading || (overview?.hasData == true) {
            Button { showDetail = true } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(glucoseAccent.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "waveform.path.ecg")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(glucoseAccent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Glucose Response")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Pulse.textPrimary)
                            if isLoading {
                                Text("Reading CGM data…")
                                    .font(.caption2)
                                    .foregroundColor(Pulse.textTertiary)
                            } else if let overview {
                                Text("\(overview.insights.count) insight\(overview.insights.count == 1 ? "" : "s") • \(overview.postMealCurves.count) meals tracked")
                                    .font(.caption2)
                                    .foregroundColor(Pulse.textTertiary)
                            }
                        }
                        Spacer()

                        if isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Pulse.textTertiary)
                        }
                    }

                    // Today's glucose summary strip
                    if let today = overview?.todaySummary {
                        HStack(spacing: 16) {
                            glucoseStat(
                                value: String(format: "%.0f", today.mean),
                                unit: "mg/dL",
                                label: "Avg"
                            )
                            glucoseStat(
                                value: String(format: "%.0f", today.timeInRange),
                                unit: "%",
                                label: "In range"
                            )
                            glucoseStat(
                                value: String(format: "%.0f", today.coefficientOfVariation),
                                unit: "%",
                                label: "CV"
                            )
                        }
                    } else if !isLoading, let topInsight = overview?.insights.first {
                        HStack(spacing: 8) {
                            Text(topInsight.metric)
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(toneColor(topInsight.metricTone))
                            Text(topInsight.headline)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Pulse.textTertiary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .payaCard(padding: 14)
            }
            .buttonStyle(PulsePress())
            .disabled(overview?.hasData != true)
            .task {
                overview = await GlucoseEngine.compute(context: modelContext)
                isLoading = false
            }
            .sheet(isPresented: $showDetail) {
                if let overview {
                    GlucoseDetailView(overview: overview)
                }
            }
        }
    }

    private func glucoseStat(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(Pulse.textPrimary)
                Text(unit)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Pulse.textTertiary)
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
        }
    }

    private func toneColor(_ tone: GlucoseEngine.Insight.MetricTone) -> Color {
        switch tone {
        case .positive: return Pulse.positive
        case .negative: return Pulse.critical
        case .neutral:  return Pulse.textTertiary
        }
    }

    private var glucoseAccent: Color { Color(hex: "7B61FF") }  // distinct purple for glucose
}

// MARK: - Glucose Detail View

struct GlucoseDetailView: View {

    let overview: GlucoseEngine.GlucoseOverview
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: DetailTab = .overview

    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case meals = "Meals"
        case rankings = "Rankings"
        case workouts = "Workouts"
    }

    private var glucoseAccent: Color { Color(hex: "7B61FF") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    tabPicker
                    contentForTab
                    methodologySection
                }
                .padding(16)
            }
            .navigationTitle("Glucose Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .background(Pulse.canvasFallback.ignoresSafeArea())
        }
        .presentationDetents([.large])
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .font(.title2.weight(.bold))
                    .foregroundColor(glucoseAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Glucose Profile")
                        .font(.title3.weight(.bold))
                        .foregroundColor(Pulse.textPrimary)
                    Text("\(overview.dayStats.count) days of CGM data")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                }
            }

            // Key stats row
            if let today = overview.todaySummary {
                HStack(spacing: 0) {
                    statPill(label: "Mean", value: "\(String(format: "%.0f", today.mean)) mg/dL", color: glucoseAccent)
                    Spacer()
                    statPill(label: "Range", value: "\(String(format: "%.0f", today.minGlucose))-\(String(format: "%.0f", today.maxGlucose))", color: Pulse.warning)
                    Spacer()
                    statPill(label: "TIR", value: "\(String(format: "%.0f", today.timeInRange))%", color: today.timeInRange >= 70 ? Pulse.positive : Pulse.critical)
                    Spacer()
                    statPill(label: "CV", value: "\(String(format: "%.0f", today.coefficientOfVariation))%", color: today.coefficientOfVariation < 36 ? Pulse.positive : Pulse.warning)
                }
                .padding(12)
                .background(Pulse.surfaceFallback)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Pulse.textTertiary)
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(selectedTab == tab ? Pulse.textPrimary : Pulse.textTertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selectedTab == tab ? glucoseAccent.opacity(0.15) : Pulse.surfaceFallback)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentForTab: some View {
        switch selectedTab {
        case .overview:
            insightsContent
        case .meals:
            mealsContent
        case .rankings:
            rankingsContent
        case .workouts:
            workoutsContent
        }
    }

    // MARK: Overview / Insights

    @ViewBuilder
    private var insightsContent: some View {
        if overview.insights.isEmpty {
            emptyState("Not enough data yet", detail: "Keep logging meals and wearing your CGM — insights appear after 3+ matched days.")
        } else {
            ForEach(overview.insights) { insight in
                insightCard(insight)
            }
        }
    }

    private func insightCard(_ insight: GlucoseEngine.Insight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(insight.category.rawValue)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(glucoseAccent)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text(insight.metric)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(toneColor(insight.metricTone))
            }
            Text(insight.headline)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Pulse.textPrimary)
            Text(insight.detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Pulse.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Pulse.surfaceFallback)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: Meals — Post-Meal Curves

    @ViewBuilder
    private var mealsContent: some View {
        if overview.postMealCurves.isEmpty {
            emptyState("No meal-glucose matches", detail: "Log meals in the Nutrition tab while wearing your CGM. The engine pairs each meal with the glucose curve that follows.")
        } else {
            ForEach(overview.postMealCurves.prefix(20)) { curve in
                mealCurveCard(curve)
            }
        }
    }

    private func mealCurveCard(_ curve: GlucoseEngine.PostMealCurve) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(curve.mealName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(glucoseAccent)
                    Text(curve.foodDescription)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Pulse.textPrimary)
                        .lineLimit(2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(curve.mealTime, style: .date)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Pulse.textTertiary)
                    Text(curve.mealTime, style: .time)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Pulse.textTertiary)
                }
            }

            // Mini glucose curve visualization
            glucoseCurveBar(curve)

            HStack(spacing: 16) {
                curveMetric(label: "Peak", value: "\(String(format: "%.0f", curve.peakGlucose))", unit: "mg/dL")
                curveMetric(label: "Spike", value: "+\(String(format: "%.0f", curve.deltaFromBaseline))", unit: "mg/dL")
                curveMetric(label: "Peak at", value: "\(curve.peakTimeMinutes)", unit: "min")
                if curve.carbsG > 0 {
                    curveMetric(label: "Carbs", value: "\(String(format: "%.0f", curve.carbsG))", unit: "g")
                }
            }
        }
        .padding(14)
        .background(Pulse.surfaceFallback)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func glucoseCurveBar(_ curve: GlucoseEngine.PostMealCurve) -> some View {
        // Simple bar representation of the glucose spike
        GeometryReader { geo in
            let maxVal = max(curve.peakGlucose, 180)
            let minVal = min(curve.preMealGlucose ?? 70, 70)
            let range = maxVal - minVal

            ZStack(alignment: .leading) {
                // In-range zone (70-180)
                let rangeStart = (70 - minVal) / range
                let rangeEnd = (180 - minVal) / range
                Rectangle()
                    .fill(Pulse.positive.opacity(0.08))
                    .frame(
                        width: geo.size.width * (rangeEnd - rangeStart),
                        height: geo.size.height
                    )
                    .offset(x: geo.size.width * rangeStart)

                // Spike line
                let spikePos = (curve.peakGlucose - minVal) / range
                Rectangle()
                    .fill(curve.deltaFromBaseline > 40 ? Pulse.critical : glucoseAccent)
                    .frame(width: 3, height: geo.size.height)
                    .offset(x: geo.size.width * spikePos)
                    .clipShape(Capsule())

                // Baseline dot
                if let pre = curve.preMealGlucose {
                    let basePos = (pre - minVal) / range
                    Circle()
                        .fill(Pulse.textTertiary)
                        .frame(width: 6, height: 6)
                        .offset(x: geo.size.width * basePos - 3)
                }
            }
        }
        .frame(height: 16)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Pulse.surfaceElevatedFallback)
        )
    }

    private func curveMetric(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 1) {
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(Pulse.textPrimary)
                Text(unit)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(Pulse.textTertiary)
            }
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
        }
    }

    // MARK: Rankings

    @ViewBuilder
    private var rankingsContent: some View {
        if overview.foodRankings.isEmpty {
            emptyState("Not enough repeat meals", detail: "Eat the same foods on different days with your CGM on. Rankings need 2+ data points per food.")
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Foods ranked by glucose spike (highest first)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Pulse.textTertiary)
                    .padding(.bottom, 4)

                ForEach(Array(overview.foodRankings.enumerated()), id: \.element.id) { idx, ranking in
                    rankingRow(ranking, rank: idx + 1)
                }
            }
        }
    }

    private func rankingRow(_ ranking: GlucoseEngine.FoodGlucoseRanking, rank: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(rank <= 3 ? Pulse.critical : Pulse.textTertiary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(ranking.food)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Pulse.textPrimary)
                    .lineLimit(1)
                Text("\(ranking.occurrences) meals • peaks at \(ranking.avgTimeToPeak) min")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Pulse.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(String(format: "%.0f", ranking.avgDelta))")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(ranking.avgDelta > 40 ? Pulse.critical : ranking.avgDelta > 25 ? Pulse.warning : Pulse.positive)
                Text(ranking.trend.rawValue)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(ranking.trend == .improving ? Pulse.positive : ranking.trend == .worsening ? Pulse.critical : Pulse.textTertiary)
            }
        }
        .padding(12)
        .background(Pulse.surfaceFallback)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: Workouts

    @ViewBuilder
    private var workoutsContent: some View {
        if overview.workoutCorrelations.isEmpty {
            emptyState("No pre-workout glucose data", detail: "Wear your CGM during training days. The engine checks glucose 0-30 min before each session.")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                // Zone summary
                let zoneGroups = Dictionary(grouping: overview.workoutCorrelations) { $0.glucoseZone }
                HStack(spacing: 8) {
                    ForEach([GlucoseEngine.PreWorkoutCorrelation.GlucoseZone.low, .optimal, .elevated, .high], id: \.self) { zone in
                        let count = zoneGroups[zone]?.count ?? 0
                        if count > 0 {
                            VStack(spacing: 2) {
                                Text("\(count)")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundColor(zoneColor(zone))
                                Text(zoneLabel(zone))
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundColor(Pulse.textTertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(zoneColor(zone).opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                ForEach(overview.workoutCorrelations.prefix(15)) { corr in
                    workoutRow(corr)
                }
            }
        }
    }

    private func workoutRow(_ corr: GlucoseEngine.PreWorkoutCorrelation) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(zoneColor(corr.glucoseZone))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(corr.sessionDate, style: .date)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Pulse.textPrimary)
                Text("Pre-workout: \(String(format: "%.0f", corr.preWorkoutGlucose)) mg/dL")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Pulse.textTertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.0f", corr.sessionVolume)) kg")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Pulse.textPrimary)
                if let rpe = corr.sessionRPE {
                    Text("RPE \(rpe)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Pulse.textTertiary)
                }
            }
        }
        .padding(12)
        .background(Pulse.surfaceFallback)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func zoneColor(_ zone: GlucoseEngine.PreWorkoutCorrelation.GlucoseZone) -> Color {
        switch zone {
        case .low: return Pulse.critical
        case .optimal: return Pulse.positive
        case .elevated: return Pulse.warning
        case .high: return Pulse.critical
        }
    }

    private func zoneLabel(_ zone: GlucoseEngine.PreWorkoutCorrelation.GlucoseZone) -> String {
        switch zone {
        case .low: return "Low"
        case .optimal: return "Optimal"
        case .elevated: return "Elevated"
        case .high: return "High"
        }
    }

    // MARK: - Methodology

    private var methodologySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Methodology")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Pulse.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                methodLine("Time-in-range: 70-180 mg/dL target ≥70%", source: "Battelino et al. 2019, Diabetes Care")
                methodLine("Glucose variability: CV% <36% stability threshold", source: "Danne et al. 2017, International Consensus")
                methodLine("Post-meal window: 2h post-prandial, trapezoidal AUC", source: "Standard clinical practice")
                methodLine("Individual glycemic response variability", source: "Zeevi et al. 2015, Cell")
                methodLine("Pre-workout glucose 60-120 mg/dL for optimal performance", source: "Cockcroft et al. 2020, J Sports Sci")
                methodLine("Glucose variability × oxidative stress", source: "Monnier et al. 2003, JAMA")
            }
        }
        .padding(14)
        .background(Pulse.surfaceFallback.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func methodLine(_ text: String, source: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Pulse.textSecondary)
            Text(source)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
                .italic()
        }
    }

    // MARK: - Helpers

    private func toneColor(_ tone: GlucoseEngine.Insight.MetricTone) -> Color {
        switch tone {
        case .positive: return Pulse.positive
        case .negative: return Pulse.critical
        case .neutral:  return Pulse.textTertiary
        }
    }

    private func emptyState(_ title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 28))
                .foregroundColor(Pulse.textTertiary.opacity(0.5))
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Pulse.textSecondary)
            Text(detail)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Pulse.surfaceFallback)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
