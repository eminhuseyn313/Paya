import SwiftUI
import SwiftData
import Charts

struct CorrelationInsightsCard: View {

    @Environment(\.modelContext) private var modelContext
    @State private var insights: [CorrelationEngine.Insight] = []
    @State private var days: [CorrelationEngine.DailyMetrics] = []
    @State private var isLoading = true
    @State private var sampleDays = 0
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "8B5CF6").opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "8B5CF6"))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Correlations")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        Text("\(sampleDays) days tracked · \(insights.count) patterns found")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding(.vertical, 8)
                        Spacer()
                    }
                } else if insights.isEmpty {
                    Text(sampleDays < 8
                         ? "Keep logging — need 8+ overlapping days to find patterns."
                         : "No strong correlations yet. Normal result — check back as more data builds up.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    if let top = insights.first {
                        topInsightPreview(top)
                    }
                    if insights.count > 1 {
                        Text("+\(insights.count - 1) more pattern\(insights.count > 2 ? "s" : "")")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .payaCard(padding: 14)
        }
        .buttonStyle(.plain)
        .task {
            days = await CorrelationEngine.gatherDailyMetrics(context: modelContext)
            sampleDays = days.count
            insights = CorrelationEngine.discoverInsights(from: days)
            isLoading = false
        }
        .sheet(isPresented: $showDetail) {
            CorrelationDetailView(insights: insights, days: days, sampleDays: sampleDays)
        }
    }

    @ViewBuilder
    private func topInsightPreview(_ insight: CorrelationEngine.Insight) -> some View {
        let advice = CorrelationAdvice.generate(for: insight)
        VStack(alignment: .leading, spacing: 6) {
            Text(advice.headline)
                .font(.caption.weight(.semibold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(advice.actionTip)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "059669"))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func strengthColor(_ r: Double) -> Color {
        switch abs(r) {
        case 0.6...: return Color(hex: "8B5CF6")
        case 0.45..<0.6: return Color(hex: "0891B2")
        case 0.35..<0.45: return Color(hex: "059669")
        default: return .secondary
        }
    }
}

// MARK: - Correlation Detail View

struct CorrelationDetailView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let insights: [CorrelationEngine.Insight]
    let days: [CorrelationEngine.DailyMetrics]
    let sampleDays: Int

    @State private var selectedInsight: CorrelationEngine.Insight?
    @State private var showBuilder = false
    @State private var builderMetricA: String = ""
    @State private var builderMetricB: String = ""

    private let accentPurple = Color(hex: "8B5CF6")
    private let accentTeal = Color(hex: "0891B2")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    if !insights.isEmpty {
                        whatToTrySection
                        topInsightsSection
                        strengthMatrixSection
                    } else {
                        emptyStateSection
                    }
                    builderSection
                    methodologySection
                }
                .padding(16)
            }
            .navigationTitle("Correlations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showBuilder) {
                CorrelationBuilderView(
                    initialMetricA: builderMetricA,
                    initialMetricB: builderMetricB
                )
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accentPurple.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(accentPurple)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HeroNumberText(
                        value: "\(insights.count)",
                        size: 28,
                        color: accentPurple
                    )
                    Text("patterns discovered across \(sampleDays) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            if !insights.isEmpty {
                let strongCount = insights.filter { abs($0.r) >= 0.5 }.count
                let moderateCount = insights.filter { abs($0.r) >= 0.35 && abs($0.r) < 0.5 }.count
                HStack(spacing: 12) {
                    strengthPill("Strong", count: strongCount, color: accentPurple)
                    strengthPill("Moderate", count: moderateCount, color: accentTeal)
                }
            }
        }
        .payaCard(padding: 16)
    }

    private func strengthPill(_ label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(count) \(label)")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.08))
        .clipShape(Capsule())
    }

    // MARK: - Strength Matrix

    private var strengthMatrixSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CORRELATION STRENGTH")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)

            let sorted = insights.sorted { abs($0.r) > abs($1.r) }
            VStack(spacing: 2) {
                ForEach(sorted) { insight in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedInsight = selectedInsight?.id == insight.id ? nil : insight
                        }
                    } label: {
                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 0)
                                .fill(barColor(insight.r))
                                .frame(
                                    width: max(20, CGFloat(abs(insight.r)) * 200),
                                    height: 32
                                )
                                .overlay(alignment: .leading) {
                                    Text(String(format: "%.2f", insight.r))
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.leading, 6)
                                }

                            Text("\(insight.metricA.label) × \(insight.metricB.label)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .padding(.leading, 8)

                            Spacer()

                            Image(systemName: insight.r > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 9))
                                .foregroundColor(insight.r > 0 ? Color(hex: "059669") : Color(hex: "DC2626"))
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)

                    if selectedInsight?.id == insight.id {
                        insightDetailExpanded(insight)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    private func barColor(_ r: Double) -> Color {
        let absR = abs(r)
        if absR >= 0.6 { return accentPurple }
        if absR >= 0.45 { return accentTeal }
        return Color(hex: "059669")
    }

    // MARK: - Expanded Insight Detail

    private func insightDetailExpanded(_ insight: CorrelationEngine.Insight) -> some View {
        let pairs = days.compactMap { day -> (x: Double, y: Double, date: Date)? in
            guard let x = insight.metricA.keyPath(day),
                  let y = insight.metricB.keyPath(day) else { return nil }
            return (x, y, day.date)
        }

        return VStack(alignment: .leading, spacing: 10) {
            if pairs.count >= 3 {
                Chart(pairs, id: \.date) { point in
                    PointMark(
                        x: .value(insight.metricA.label, point.x),
                        y: .value(insight.metricB.label, point.y)
                    )
                    .foregroundStyle(barColor(insight.r).opacity(0.7))
                    .symbolSize(24)
                }
                .frame(height: 140)
                .chartXAxisLabel(insight.metricA.label + " (\(insight.metricA.unit))")
                .chartYAxisLabel(insight.metricB.label + " (\(insight.metricB.unit))")
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        AxisValueLabel()
                            .font(.system(size: 8))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        AxisValueLabel()
                            .font(.system(size: 8))
                    }
                }
            }

            Text(insight.text)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Label("\(insight.sampleSize) days", systemImage: "calendar")
                Label(strengthLabel(insight.r), systemImage: "gauge.with.dots.needle.33percent")
                Label(insight.r > 0 ? "Positive" : "Inverse", systemImage: insight.r > 0 ? "arrow.up.right" : "arrow.down.right")
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.secondary)

            Button {
                builderMetricA = insight.metricA.id
                builderMetricB = insight.metricB.id
                showBuilder = true
            } label: {
                Text("Explore this pair")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(accentPurple)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - What to try

    private var whatToTrySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "F59E0B"))
                Text("WHAT TO TRY THIS WEEK")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.secondary)
            }

            let tips = insights.prefix(3).map { CorrelationAdvice.generate(for: $0) }
            ForEach(Array(tips.enumerated()), id: \.offset) { _, advice in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color(hex: "059669"))
                        .frame(width: 6, height: 6)
                        .padding(.top, 5)
                    Text(advice.actionTip)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .payaCard(padding: 14)
    }

    // MARK: - Top Insights

    private var topInsightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("KEY FINDINGS")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)

            let actionable = generateActionableInsights()
            ForEach(Array(actionable.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: item.icon)
                        .font(.system(size: 12))
                        .foregroundColor(item.color)
                        .frame(width: 24)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                        Text(item.body)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .payaCard(padding: 12)
            }
        }
    }

    private struct ActionableInsight {
        let icon: String
        let color: Color
        let title: String
        let body: String
    }

    private func generateActionableInsights() -> [ActionableInsight] {
        insights.prefix(6).map { insight in
            let advice = CorrelationAdvice.generate(for: insight)
            let absR = abs(insight.r)
            let icon: String
            let color: Color
            switch advice.category {
            case .sleep: icon = "moon.fill"; color = Color(hex: "8B5CF6")
            case .training: icon = "figure.strengthtraining.traditional"; color = Color(hex: "059669")
            case .nutrition: icon = "fork.knife"; color = Color(hex: "B45309")
            case .recovery: icon = "heart.fill"; color = Color(hex: "DC2626")
            case .environment: icon = "sun.max.fill"; color = Color(hex: "F59E0B")
            case .general: icon = absR >= 0.5 ? "exclamationmark.circle.fill" : "info.circle.fill"; color = accentTeal
            }
            return ActionableInsight(
                icon: icon,
                color: color,
                title: advice.headline,
                body: advice.actionTip + " (\(insight.sampleSize) days, r=\(String(format: "%.2f", insight.r)))"
            )
        }
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.dots.scatter")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.4))
            Text("No patterns found yet")
                .font(.headline)
            Text(sampleDays < 8
                 ? "Log training, nutrition, sleep, water, and check-ins across at least 8 days so the engine has enough overlapping data points to test every pair."
                 : "With \(sampleDays) days of data, no two metrics showed a correlation above the r=0.35 threshold. That's a real result — it means the things you're tracking are varying independently, which is useful to know.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Builder

    private var builderSection: some View {
        Button {
            builderMetricA = CorrelationEngine.metrics[0].id
            builderMetricB = CorrelationEngine.metrics[1].id
            showBuilder = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accentTeal.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 14))
                        .foregroundColor(accentTeal)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Build your own")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text("Pick any two of \(CorrelationEngine.metrics.count) metrics and see the scatter plot")
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
    }

    // MARK: - Methodology

    private var methodologySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOW THIS WORKS")
                .font(.caption.weight(.bold))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                methodologyRow("chart.bar.fill", "Pearson correlation coefficient (r) measures linear association between -1 and +1")
                methodologyRow("line.horizontal.3.decrease", "Only pairs with |r| >= 0.35 shown — Cohen's moderate effect-size band (Cohen J., 1988)")
                methodologyRow("calendar", "Minimum 8 overlapping days required — below that, coefficients are too noisy")
                methodologyRow("exclamationmark.triangle.fill", "Correlation ≠ causation — two things moving together doesn't prove one causes the other")
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: PayaRadius.card))
    }

    private func methodologyRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .frame(width: 14)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func strengthLabel(_ r: Double) -> String {
        switch abs(r) {
        case 0.5...: return "Strong"
        case 0.35..<0.5: return "Moderate"
        default: return "Weak"
        }
    }
}
