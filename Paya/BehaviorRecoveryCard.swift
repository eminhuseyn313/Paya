import SwiftUI
import SwiftData

// MARK: - Behavior Tag Picker
//
// Tappable behavior tag grid used in both the morning check-in
// and as a standalone dashboard card. Each tag feeds the
// BehaviorRecoveryEngine which correlates behaviors with
// next-day recovery (see BehaviorTag.swift).

struct BehaviorTagPicker: View {

    @Environment(\.modelContext) private var modelContext
    @State private var activeTags: Set<String> = []

    /// If true, shows as an inline section (for check-in).
    /// If false, shows as a standalone .payaCard.
    var inline: Bool = false

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "tag.fill")
                    .foregroundColor(Color(hex: "8B5CF6"))
                    .font(.system(size: 12))
                Text("Today's behaviors")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(activeTags.count) tagged")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text("Tag what you did today — Paya correlates these with your recovery.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            ForEach(BehaviorCategory.allCases) { category in
                let tags = BehaviorTags.all.filter { $0.category == category }
                VStack(alignment: .leading, spacing: 6) {
                    Text(category.displayName.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)

                    FlowLayout(spacing: 6) {
                        ForEach(tags) { tag in
                            let isOn = activeTags.contains(tag.id)
                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    if isOn {
                                        activeTags.remove(tag.id)
                                    } else {
                                        activeTags.insert(tag.id)
                                    }
                                    BehaviorStore.toggleTag(tag.id, context: modelContext)
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: tag.icon)
                                        .font(.system(size: 10))
                                    Text(tag.label)
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(isOn ? Color(hex: tag.colorHex).opacity(0.2) : Color(.tertiarySystemBackground))
                                .foregroundStyle(isOn ? Color(hex: tag.colorHex) : .primary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(isOn ? Color(hex: tag.colorHex).opacity(0.5) : .clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }

        if inline {
            content
        } else {
            content.payaCard(padding: 14)
        }
    }

    func loadExisting() {
        if let log = BehaviorStore.todaysLog(context: modelContext) {
            activeTags = Set(log.tagIds)
        }
    }
}

// MARK: - Behavior ↔ Recovery Map Card
//
// Dashboard card that surfaces the strongest behavior ↔ recovery
// correlations. Whoop charges $30/month for this via "Behavior
// Trends". Paya does it free, on-device.
//
// Research basis: Whoop's published population data shows alcohol
// suppresses next-day HRV by ~15%, cold exposure improves it ~8%,
// stretching improves it ~5%. Our engine uses the user's own data.

struct BehaviorRecoveryCard: View {

    @Environment(\.modelContext) private var modelContext
    @State private var insights: [BehaviorRecoveryEngine.BehaviorInsight] = []
    @State private var isLoading = true
    @State private var showAllInsights = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundColor(Color(hex: "8B5CF6"))
                    .font(.system(size: 12))
                Text("Behavior ↔ Recovery")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !insights.isEmpty {
                    Text("\(insights.count) patterns")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "8B5CF6"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(hex: "8B5CF6").opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if isLoading {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Analyzing patterns…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
            } else if insights.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "chart.line.text.clipboard")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text("Not enough data yet")
                        .font(.caption.weight(.semibold))
                    Text("Tag your daily behaviors for 2+ weeks to see how they affect your recovery.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                let displayInsights = showAllInsights ? insights : Array(insights.prefix(3))
                ForEach(displayInsights) { insight in
                    insightRow(insight)
                }

                if insights.count > 3 {
                    Button {
                        withAnimation { showAllInsights.toggle() }
                    } label: {
                        Text(showAllInsights ? "Show less" : "See all \(insights.count) patterns")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color(hex: "8B5CF6"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                }
            }

            // Footer
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 8))
                Text("Correlation, not causation. Based on your data only.")
                    .font(.system(size: 9))
            }
            .foregroundColor(.secondary)
        }
        .payaCard(padding: 14)
        .task {
            insights = await BehaviorRecoveryEngine.computeInsights(context: modelContext)
            isLoading = false
        }
    }

    @ViewBuilder
    private func insightRow(_ insight: BehaviorRecoveryEngine.BehaviorInsight) -> some View {
        HStack(spacing: 10) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: insight.tag.colorHex).opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: insight.tag.icon)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: insight.tag.colorHex))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.tag.label)
                    .font(.caption.weight(.semibold))
                Text(insight.text)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Delta badge
            VStack(spacing: 1) {
                Image(systemName: insight.isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                Text("\(Int(abs(insight.delta)))%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundColor(insight.isPositive ? Color(hex: "059669") : Color(hex: "DC2626"))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                (insight.isPositive ? Color(hex: "059669") : Color(hex: "DC2626")).opacity(0.1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 4)
    }
}
