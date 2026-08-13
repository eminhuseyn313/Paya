import SwiftUI
import SwiftData

struct TrainingInsightsCard: View {

    var sessions: [TrainingSession]
    @Environment(\.modelContext) private var modelContext
    @State private var insights: [TrainingInsight] = []
    @State private var showAll = false

    private var displayInsights: [TrainingInsight] {
        showAll ? insights : Array(insights.prefix(3))
    }

    var body: some View {
        Group {
            if !insights.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(Color(hex: "8B5CF6"))
                        Text("Insights")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(insights.count)")
                            .font(.caption.weight(.bold))
                            .foregroundColor(Color(hex: "8B5CF6"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(hex: "8B5CF6").opacity(0.12))
                            .clipShape(Capsule())
                    }

                    ForEach(displayInsights) { insight in
                        HStack(alignment: .top, spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: insight.colorHex).opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: insight.icon)
                                    .font(.system(size: 13))
                                    .foregroundColor(Color(hex: insight.colorHex))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(insight.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.primary)
                                Text(insight.detail)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if insights.count > 3 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showAll.toggle() }
                        } label: {
                            HStack {
                                Text(showAll ? "Show less" : "Show \(insights.count - 3) more")
                                    .font(.caption.weight(.medium))
                                Image(systemName: showAll ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(Color(hex: "8B5CF6"))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                        }
                    }
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { loadInsights() }
    }

    private func loadInsights() {
        insights = TrainingInsightsEngine.generate(sessions: sessions, context: modelContext)
    }
}
