import SwiftUI
import SwiftData

// MARK: - Chrononutrition Card
//
// Surfaces meal-timing × sleep/HRV correlations personalized to
// the user's own data. Differentiator: no other consumer app does
// this at the individual level — population stats say "don't eat
// late," this card says "when YOU eat after 9 PM, YOUR deep sleep
// drops X%."

struct ChronoNutritionCard: View {

    @Environment(\.modelContext) private var modelContext
    @State private var insights: [ChronoNutritionEngine.Insight] = []
    @State private var isLoading = true
    @State private var showDetail = false

    var body: some View {
        if !insights.isEmpty || isLoading {
            Button { showDetail = true } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Pulse.nutrition.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "fork.knife.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Pulse.nutrition)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Meal Timing × Sleep")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Pulse.textPrimary)
                            if isLoading {
                                Text("Analyzing your patterns…")
                                    .font(.caption2)
                                    .foregroundColor(Pulse.textTertiary)
                            } else {
                                Text("\(insights.count) pattern\(insights.count == 1 ? "" : "s") found")
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

                    if !isLoading, let top = insights.first {
                        HStack(spacing: 8) {
                            Text(top.metric)
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(toneColor(top.metricColor))
                            Text(top.headline)
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
            .disabled(insights.isEmpty)
            .task {
                insights = await ChronoNutritionEngine.compute(context: modelContext)
                isLoading = false
            }
            .sheet(isPresented: $showDetail) {
                ChronoNutritionDetailView(insights: insights)
            }
        }
    }

    private func toneColor(_ tone: ChronoNutritionEngine.Insight.MetricTone) -> Color {
        switch tone {
        case .positive: return Pulse.positive
        case .negative: return Pulse.critical
        case .neutral:  return Pulse.textTertiary
        }
    }
}

// MARK: - Detail View

struct ChronoNutritionDetailView: View {

    let insights: [ChronoNutritionEngine.Insight]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection

                    ForEach(insights) { insight in
                        insightCard(insight)
                    }

                    methodologySection
                }
                .padding(16)
            }
            .navigationTitle("Meal Timing Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How WHEN you eat affects your sleep and recovery")
                .font(.headline.weight(.bold))
                .foregroundColor(Pulse.textPrimary)
            Text("These patterns are from YOUR data, not population averages. More logged meals = sharper insights.")
                .font(.caption)
                .foregroundColor(Pulse.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .payaCard(padding: 14)
    }

    @ViewBuilder
    private func insightCard(_ insight: ChronoNutritionEngine.Insight) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: categoryIcon(insight.category))
                    .font(.system(size: 12))
                    .foregroundColor(toneColor(insight.metricColor))
                Text(insight.category.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Pulse.textTertiary)
                    .textCase(.uppercase)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(confidenceColor(insight.confidence))
                        .frame(width: 5, height: 5)
                    Text(insight.confidence.rawValue)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Pulse.textTertiary)
                }
            }

            HStack(spacing: 10) {
                Text(insight.metric)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(toneColor(insight.metricColor))
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.headline)
                        .font(.caption.weight(.bold))
                        .foregroundColor(Pulse.textPrimary)
                    Text("\(insight.sampleDays) days analyzed")
                        .font(.system(size: 9))
                        .foregroundColor(Pulse.textTertiary)
                }
            }

            Text(insight.detail)
                .font(.system(size: 10))
                .foregroundColor(Pulse.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Pulse.surfaceElevatedFallback)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var methodologySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HOW THIS WORKS")
                .font(.caption.weight(.bold))
                .foregroundColor(Pulse.textTertiary)

            VStack(alignment: .leading, spacing: 5) {
                methodRow("fork.knife", "Compares your logged meal times with same-night sleep data from Apple Watch")
                methodRow("chart.xyaxis.line", "Uses split-group analysis (early vs. late dinner) and Pearson correlation")
                methodRow("person.fill", "All thresholds are relative to YOUR baseline, not population averages")
                methodRow("book.closed.fill", "Grounded in Crispim 2011, St-Onge 2016, Iao 2021, Wirth 2020")
            }
        }
        .padding(14)
        .background(Pulse.surfaceElevatedFallback.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: PayaRadius.card))
    }

    private func methodRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(Pulse.textTertiary)
                .frame(width: 14)
                .padding(.top, 2)
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(Pulse.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func categoryIcon(_ category: ChronoNutritionEngine.Insight.Category) -> String {
        switch category {
        case .lastMealTiming: return "clock.fill"
        case .eatingWindow:   return "timer"
        case .deepSleep:      return "moon.zzz.fill"
        case .hrvRecovery:    return "waveform.path.ecg"
        case .sleepOnset:     return "bed.double.fill"
        case .caffeineTiming: return "cup.and.saucer.fill"
        }
    }

    private func toneColor(_ tone: ChronoNutritionEngine.Insight.MetricTone) -> Color {
        switch tone {
        case .positive: return Pulse.positive
        case .negative: return Pulse.critical
        case .neutral:  return Pulse.textTertiary
        }
    }

    private func confidenceColor(_ conf: ChronoNutritionEngine.Insight.Confidence) -> Color {
        switch conf {
        case .strong:   return Pulse.positive
        case .moderate: return Pulse.nutrition
        case .emerging: return Pulse.textTertiary
        }
    }
}
