import SwiftUI
import SwiftData
import Charts

// MARK: - Correlation Builder
//
// CorrelationInsightsCard surfaces what the engine found on its own; this
// is the requested complement — pick any two tracked metrics yourself and
// see exactly how they relate, even when the result is weak or there's not
// enough data. Asking "is there a link between X and Y" is itself useful,
// whether or not the auto-discovery pass happened to surface that pair.

struct CorrelationBuilderCard: View {
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "0891B2").opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "chart.xyaxis.line")
                        .foregroundColor(Color(hex: "0891B2"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Build a correlation")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text("Pick any two metrics and see how they relate")
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
}

struct CorrelationBuilderView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var initialMetricA: String = ""
    var initialMetricB: String = ""

    @State private var metricAId: String = CorrelationEngine.metrics[0].id
    @State private var metricBId: String = CorrelationEngine.metrics[1].id
    @State private var days: [CorrelationEngine.DailyMetrics] = []
    @State private var isLoading = true

    private var metricA: CorrelationEngine.Metric {
        CorrelationEngine.metrics.first { $0.id == metricAId } ?? CorrelationEngine.metrics[0]
    }
    private var metricB: CorrelationEngine.Metric {
        CorrelationEngine.metrics.first { $0.id == metricBId } ?? CorrelationEngine.metrics[1]
    }
    private var result: CorrelationEngine.ManualResult {
        CorrelationEngine.correlate(metricA, metricB, days: days)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        metricPicker("First metric", selection: $metricAId, excluding: metricBId)
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        metricPicker("Second metric", selection: $metricBId, excluding: metricAId)
                    }
                    .payaCard(padding: 14)

                    if isLoading {
                        SwiftUI.ProgressView()
                            .padding(.top, 40)
                    } else {
                        resultCard
                    }

                    Spacer(minLength: 20)
                }
                .padding(16)
            }
            .navigationTitle("Build a Correlation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            if !initialMetricA.isEmpty { metricAId = initialMetricA }
            if !initialMetricB.isEmpty { metricBId = initialMetricB }
            days = await CorrelationEngine.gatherDailyMetrics(context: modelContext)
            isLoading = false
        }
    }

    private func metricPicker(_ label: String, selection: Binding<String>, excluding: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Picker(label, selection: selection) {
                ForEach(CorrelationEngine.metrics) { metric in
                    Text(metric.label).tag(metric.id)
                }
            }
            .pickerStyle(.menu)
            .tint(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: selection.wrappedValue) { _, newValue in
            // Two pickers can't land on the same metric — a self-correlation
            // is trivially r=1 and tells the user nothing.
            if newValue == excluding {
                let fallback = CorrelationEngine.metrics.first { $0.id != newValue }
                selection.wrappedValue = fallback?.id ?? newValue
            }
        }
    }

    @ViewBuilder
    private var resultCard: some View {
        let r = result.r

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(metricA.label) vs \(metricB.label)")
                        .font(.subheadline.weight(.semibold))
                    Text(result.strengthLabel + (r != nil ? " correlation" : ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let r {
                    Text(String(format: "r = %.2f", r))
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(abs(r) >= 0.3 ? Color(hex: "0891B2") : .secondary)
                }
            }

            if result.sampleSize < 8 {
                Text("Only \(result.sampleSize) day\(result.sampleSize == 1 ? "" : "s") with both metrics logged — keep tracking both for a trustworthy read. Fewer than 8 overlapping days makes any coefficient unstable.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if result.pairs.count >= 3 {
                Chart(result.pairs, id: \.date) { point in
                    PointMark(
                        x: .value(metricA.label, point.x),
                        y: .value(metricB.label, point.y)
                    )
                    .foregroundStyle(Color(hex: "0891B2").opacity(0.7))
                }
                .frame(height: 160)
                .chartXAxisLabel(metricA.label)
                .chartYAxisLabel(metricB.label)
            }

            Text("Correlation, not causation — this shows two things moving together across \(result.sampleSize) days, not that one causes the other.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .payaCard(padding: 14)
    }
}
