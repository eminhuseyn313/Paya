import SwiftUI
import SwiftData

struct NutrientDashboardCard: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var report: NutrientDeficitEngine.Report?
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Pulse.positive.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Pulse.positive)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nutrient Balance")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Pulse.textPrimary)
                        if let report {
                            let defCount = report.deficits.count
                            Text(defCount == 0 ? "All nutrients on track" : "\(defCount) nutrient\(defCount == 1 ? "" : "s") running low")
                                .font(.caption2)
                                .foregroundColor(defCount == 0 ? .secondary : Pulse.nutrition)
                        } else {
                            Text("Tap to see your nutrient breakdown")
                                .font(.caption2)
                                .foregroundColor(Pulse.textTertiary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Pulse.textTertiary)
                }

                if let report, !report.nutrients.isEmpty {
                    nutrientPreviewBars(report)
                }
            }
            .payaCard(padding: 14)
        }
        .buttonStyle(PulsePress())
        .onAppear { loadReport() }
        .onChange(of: appState.dataRefreshTrigger) { _, _ in loadReport() }
        .sheet(isPresented: $showDetail) {
            if let report {
                NutrientDetailView(report: report, age: appState.profile.age, sex: appState.profile.sexRaw)
            }
        }
    }

    private func loadReport() {
        report = NutrientDeficitEngine.analyze(
            context: modelContext,
            age: appState.profile.age,
            sex: appState.profile.sexRaw
        )
    }

    @ViewBuilder
    private func nutrientPreviewBars(_ report: NutrientDeficitEngine.Report) -> some View {
        let key = report.nutrients.filter { $0.target.id != "sodium" }.prefix(6)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(Array(key)) { nutrient in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: nutrient.level.color))
                        .frame(width: 6, height: 6)
                    Text(nutrient.target.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Pulse.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(Int(nutrient.percentRDA))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: nutrient.level.color))
                }
            }
        }
    }
}

// MARK: - Nutrient Detail View

struct NutrientDetailView: View {

    @Environment(\.dismiss) private var dismiss
    let report: NutrientDeficitEngine.Report
    let age: Int
    let sex: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryHeader
                    nutrientGrid
                    if !report.supplementRecommendations.isEmpty {
                        recommendationsSection
                    }
                    if !report.supplementStopSuggestions.isEmpty {
                        stopSuggestionsSection
                    }
                    foodSourcesSection
                    rdaSourceNote
                }
                .padding(16)
            }
            .navigationTitle("Nutrients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Summary

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Pulse.positive.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Pulse.positive)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Nutrient Balance")
                        .font(.headline)
                    let ok = report.nutrients.filter { $0.level == .adequate }.count
                    Text("\(ok)/\(report.nutrients.count) nutrients at adequate levels")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                legendPill("Good", color: "059669")
                legendPill("Low", color: "F59E0B")
                legendPill("Very Low", color: "DC2626")
                legendPill("High", color: "2563EB")
            }
        }
        .payaCard(padding: 16)
    }

    private func legendPill(_ label: String, color: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(Color(hex: color)).frame(width: 6, height: 6)
            Text(label).font(.system(size: 9, weight: .medium)).foregroundColor(Pulse.textTertiary)
        }
    }

    // MARK: - Nutrient Grid

    private var nutrientGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR INTAKE VS RDA")
                .font(.caption.weight(.bold))
                .foregroundColor(Pulse.textTertiary)

            ForEach(report.nutrients) { nutrient in
                NutrientRow(nutrient: nutrient, todaysMeals: report.todaysMeals)
            }
        }
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONSIDER SUPPLEMENTING")
                .font(.caption.weight(.bold))
                .foregroundColor(Pulse.textTertiary)

            ForEach(Array(report.supplementRecommendations.enumerated()), id: \.offset) { _, rec in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Pulse.positive)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(rec.nutrientName)
                            .font(.subheadline.weight(.semibold))
                        Text(rec.reason)
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .payaCard(padding: 12)
            }
        }
    }

    private var stopSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("REVIEW YOUR SUPPLEMENTS")
                .font(.caption.weight(.bold))
                .foregroundColor(Pulse.textTertiary)

            ForEach(Array(report.supplementStopSuggestions.enumerated()), id: \.offset) { _, stop in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Pulse.warning)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(stop.supplementName)
                            .font(.subheadline.weight(.semibold))
                        Text(stop.reason)
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .payaCard(padding: 12)
            }
        }
    }

    // MARK: - Food Sources

    private var foodSourcesSection: some View {
        let low = report.nutrients.filter { $0.level == .critical || $0.level == .low }
        return Group {
            if !low.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("TOP FOOD SOURCES")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Pulse.textTertiary)

                    ForEach(low) { nutrient in
                        let sources = NutrientFoodSources.sources(for: nutrient.target.id)
                        if !sources.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(nutrient.target.name)
                                    .font(.subheadline.weight(.semibold))
                                ForEach(sources, id: \.food) { src in
                                    HStack(spacing: 8) {
                                        Text(src.emoji)
                                            .font(.system(size: 16))
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(src.food)
                                                .font(.caption.weight(.medium))
                                            Text(src.portion)
                                                .font(.system(size: 9))
                                                .foregroundColor(Pulse.textTertiary)
                                        }
                                        Spacer()
                                        Text(src.amount)
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(Color(hex: "22C55E"))
                                    }
                                }
                            }
                            .payaCard(padding: 12)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Source

    private var rdaSourceNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DATA SOURCE")
                .font(.caption.weight(.bold))
                .foregroundColor(Pulse.textTertiary)
            Text("RDA values from the Institute of Medicine / National Academies \"Dietary Reference Intakes\" (2019 consolidated tables), adjusted for your age (\(age)) and sex (\(sex.lowercased())). Nutrient amounts are AI-estimated from food descriptions — not lab-measured. Use as directional guidance, not clinical data.")
                .font(.system(size: 10))
                .foregroundColor(Pulse.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Pulse.surfaceElevatedFallback.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: PayaRadius.card))
    }
}

// MARK: - Nutrient Row

struct NutrientRow: View {
    let nutrient: NutrientDeficitEngine.NutrientStatus
    var todaysMeals: [MealLog] = []
    @State private var isExpanded = false

    private var contributions: [NutrientDeficitEngine.FoodContribution] {
        NutrientDeficitEngine.contributions(for: nutrient.target, from: todaysMeals)
    }

    private var hasFoodData: Bool { !contributions.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // Main row — tappable when food contributions exist
            Button {
                guard hasFoodData else { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            } label: {
                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: nutrient.level.icon)
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: nutrient.level.color))
                        Text(nutrient.target.name)
                            .font(.subheadline.weight(.semibold))

                        if nutrient.isSupplemented {
                            Image(systemName: "pills.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Pulse.ai)
                        }

                        Spacer()

                        if hasFoodData {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Pulse.textTertiary)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }

                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(formatted(nutrient.todayIntake))/\(formatted(nutrient.target.rda))\(nutrient.target.unit)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            Text("\(Int(nutrient.percentRDA))% of RDA")
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: nutrient.level.color))
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Pulse.surfaceElevatedFallback)

                            // Stacked segments showing each food's contribution
                            if isExpanded && contributions.count > 1 {
                                stackedBar(in: geo.size.width)
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: nutrient.level.color))
                                    .frame(width: min(geo.size.width, geo.size.width * CGFloat(nutrient.percentRDA / 100)))
                            }

                            // 100% marker
                            if nutrient.percentRDA < 150 {
                                Rectangle()
                                    .fill(Color.primary.opacity(0.3))
                                    .frame(width: 1)
                                    .offset(x: geo.size.width * 1.0 - 0.5)
                            }
                        }
                    }
                    .frame(height: 8)

                    if nutrient.weekPercentRDA > 0 && nutrient.weekPercentRDA != nutrient.percentRDA {
                        HStack(spacing: 4) {
                            Text("7-day avg:")
                                .font(.system(size: 9))
                                .foregroundColor(Pulse.textTertiary)
                            Text("\(formatted(nutrient.weekAvgIntake))\(nutrient.target.unit) (\(Int(nutrient.weekPercentRDA))%)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Color(hex: nutrient.level.color))
                            Spacer()
                        }
                    }
                }
                .padding(10)
            }
            .buttonStyle(.plain)

            // Expanded food breakdown
            if isExpanded && hasFoodData {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Pulse.surfaceElevatedFallback)
                        .frame(height: 1)
                        .padding(.horizontal, 10)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("FROM YOUR FOOD LOG")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Pulse.textTertiary)
                            .padding(.top, 4)

                        ForEach(Array(contributions.enumerated()), id: \.element.id) { idx, item in
                            HStack(spacing: 10) {
                                // Segment color dot
                                Circle()
                                    .fill(segmentColor(at: idx))
                                    .frame(width: 8, height: 8)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.foodDescription)
                                        .font(.caption.weight(.medium))
                                        .foregroundColor(Pulse.textPrimary)
                                        .lineLimit(2)
                                    Text(item.mealName)
                                        .font(.system(size: 9))
                                        .foregroundColor(Pulse.textTertiary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("\(formatted(item.amount))\(item.unit)")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundColor(Pulse.textPrimary)
                                    let pct = nutrient.target.rda > 0 ? (item.amount / nutrient.target.rda) * 100 : 0
                                    Text("\(Int(pct))%")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(Color(hex: nutrient.level.color))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Pulse.surfaceFallback)
        .clipShape(RoundedRectangle(cornerRadius: PayaRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: PayaRadius.card)
                .strokeBorder(Color.white.opacity(0.04), lineWidth: 1)
        )
    }

    // MARK: - Stacked Progress Bar

    @ViewBuilder
    private func stackedBar(in totalWidth: CGFloat) -> some View {
        let barWidth = min(totalWidth, totalWidth * CGFloat(nutrient.percentRDA / 100))
        let total = nutrient.todayIntake
        HStack(spacing: 0) {
            ForEach(Array(contributions.enumerated()), id: \.element.id) { idx, item in
                let fraction = total > 0 ? item.amount / total : 0
                RoundedRectangle(cornerRadius: idx == 0 ? 4 : 0)
                    .fill(segmentColor(at: idx))
                    .frame(width: max(1, barWidth * CGFloat(fraction)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .frame(width: barWidth)
    }

    // MARK: - Helpers

    private static let segmentPalette: [Color] = [
        Color(hex: "22C55E"),  // green
        Color(hex: "3B82F6"),  // blue
        Color(hex: "F59E0B"),  // amber
        Color(hex: "8B5CF6"),  // violet
        Color(hex: "EC4899"),  // pink
        Color(hex: "14B8A6"),  // teal
        Color(hex: "F97316"),  // orange
        Color(hex: "6366F1"),  // indigo
    ]

    private func segmentColor(at index: Int) -> Color {
        Self.segmentPalette[index % Self.segmentPalette.count]
    }

    private func formatted(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f", value) : String(format: "%.0f", value)
    }
}
