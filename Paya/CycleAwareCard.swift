import SwiftUI

// MARK: - Cycle-Aware Card
//
// Surfaces menstrual cycle phase and phase-specific training/nutrition
// recommendations. Only appears for female users who have cycle data
// in Apple Health. Zero footprint otherwise.

struct CycleAwareCard: View {

    let sexRaw: String
    @State private var overview: CycleAwareEngine.CycleOverview?
    @State private var isLoading = true
    @State private var showDetail = false

    var body: some View {
        if isLoading || (overview?.isAvailable == true) {
            Button { showDetail = true } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(phaseColor.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: overview?.currentPhase.icon ?? "moon.stars.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(phaseColor)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cycle Phase")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Pulse.textPrimary)
                            if isLoading {
                                Text("Reading cycle data…")
                                    .font(.caption2)
                                    .foregroundColor(Pulse.textTertiary)
                            } else if let day = overview?.currentDay {
                                Text("\(day.phase.rawValue) • Day \(day.dayOfCycle) of \(day.cycleLength)")
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

                    // Phase progress bar
                    if !isLoading, let day = overview?.currentDay {
                        phaseProgressBar(day: day)
                    }

                    // Top recommendation preview
                    if !isLoading, let rec = overview?.recommendations.first {
                        HStack(spacing: 8) {
                            Image(systemName: rec.icon)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(phaseColor)
                            Text(rec.title)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Pulse.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .payaCard(padding: 14)
            }
            .buttonStyle(PulsePress())
            .disabled(overview?.isAvailable != true)
            .task {
                overview = await CycleAwareEngine.compute(sexRaw: sexRaw)
                isLoading = false
            }
            .sheet(isPresented: $showDetail) {
                if let overview {
                    CycleAwareDetailView(overview: overview)
                }
            }
        }
    }

    private func phaseProgressBar(day: CycleAwareEngine.CycleDay) -> some View {
        GeometryReader { geo in
            let total = CGFloat(day.cycleLength)
            let menstrualEnd: CGFloat = 5 / total
            let follicularEnd: CGFloat = CGFloat(Int(Double(day.cycleLength) * 0.46)) / total
            let ovulatoryEnd: CGFloat = CGFloat(Int(Double(day.cycleLength) * 0.57)) / total
            let progress = CGFloat(day.dayOfCycle) / total

            ZStack(alignment: .leading) {
                // Phase segments
                HStack(spacing: 1) {
                    phaseSegment(width: geo.size.width * menstrualEnd, color: "FF5A8A")
                    phaseSegment(width: geo.size.width * (follicularEnd - menstrualEnd), color: "4AE68A")
                    phaseSegment(width: geo.size.width * (ovulatoryEnd - follicularEnd), color: "FFB547")
                    phaseSegment(width: geo.size.width * (1 - ovulatoryEnd), color: "7B61FF")
                }

                // Current position indicator
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .offset(x: geo.size.width * progress - 4)
            }
        }
        .frame(height: 8)
    }

    private func phaseSegment(width: CGFloat, color: String) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(hex: color).opacity(0.4))
            .frame(width: max(0, width), height: 8)
    }

    private var phaseColor: Color {
        guard let phase = overview?.currentPhase else { return Pulse.vitals }
        return Color(hex: phase.color)
    }
}

// MARK: - Cycle-Aware Detail View

struct CycleAwareDetailView: View {

    let overview: CycleAwareEngine.CycleOverview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    recommendationsSection
                    if let tempTrend = overview.tempTrend {
                        temperatureSection(tempTrend)
                    }
                    cycleHistorySection
                    methodologySection
                }
                .padding(16)
            }
            .navigationTitle("Cycle Adaptation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .background(Pulse.canvasFallback.ignoresSafeArea())
            .preferredColorScheme(.dark)
        }
        .presentationDetents([.large])
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(phaseColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: overview.currentPhase.icon)
                        .font(.title2.weight(.bold))
                        .foregroundColor(phaseColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(overview.currentPhase.rawValue)
                        .font(.title3.weight(.bold))
                        .foregroundColor(Pulse.textPrimary)
                    if let day = overview.currentDay {
                        Text("Day \(day.dayOfCycle) of \(day.cycleLength)-day cycle")
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                    }
                }
                Spacer()
            }

            phaseDescription
        }
    }

    private var phaseDescription: some View {
        let description: String = {
            switch overview.currentPhase {
            case .menstrual:
                return "Estrogen and progesterone are at their lowest. Your body is recovering — honor it. Moderate intensity, iron-rich foods, and quality sleep are your priorities."
            case .follicular:
                return "Rising estrogen powers up your neuromuscular system. This is your strength window — the best time for heavy lifts, progressive overload, and setting PRs."
            case .ovulatory:
                return "Estrogen peaks — you'll feel at your most energetic. But joint laxity also peaks, so warm up thoroughly and be mindful of explosive movements."
            case .luteal:
                return "Progesterone raises your core temperature and perceived exertion. The same weights feel harder — that's hormonal, not a fitness decline. Your body burns more fat and needs more calories."
            case .unknown:
                return "Track your menstrual flow in Apple Health to unlock phase-specific guidance."
            }
        }()

        return Text(description)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Pulse.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .background(phaseColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Phase-Specific Guidance")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Pulse.textPrimary)

            ForEach(overview.recommendations) { rec in
                recommendationCard(rec)
            }
        }
    }

    private func recommendationCard(_ rec: CycleAwareEngine.PhaseRecommendation) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(categoryColor(rec.category).opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: rec.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(categoryColor(rec.category))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(rec.category.rawValue)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(categoryColor(rec.category))
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Spacer()
                }
                Text(rec.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Pulse.textPrimary)
                Text(rec.detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Pulse.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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

    private func categoryColor(_ cat: CycleAwareEngine.PhaseRecommendation.Category) -> Color {
        switch cat {
        case .training:  return Pulse.positive
        case .nutrition: return Pulse.nutrition
        case .recovery:  return Pulse.hydration
        case .caution:   return Pulse.warning
        }
    }

    // MARK: - Temperature

    private func temperatureSection(_ trend: CycleAwareEngine.TempTrend) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Temperature Pattern")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Pulse.textPrimary)

            HStack(spacing: 16) {
                tempStat(label: "Follicular avg", value: String(format: "%.2f°C", trend.avgFollicular))
                tempStat(label: "Luteal avg", value: String(format: "%.2f°C", trend.avgLuteal))
                tempStat(label: "Shift", value: String(format: "%+.2f°C", trend.shift))
            }

            Text(trend.hasShift
                 ? "Biphasic pattern detected — consistent with ovulatory cycles (Barron & Fehring 2005). The \(String(format: "%.2f", trend.shift))°C rise confirms the luteal progesterone surge."
                 : "No clear biphasic shift yet. This may indicate anovulatory cycle or insufficient data. More nights with Apple Watch will clarify.")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
        }
        .padding(14)
        .background(Pulse.surfaceFallback)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func tempStat(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(Pulse.textPrimary)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(Pulse.textTertiary)
        }
    }

    // MARK: - Cycle History

    private var cycleHistorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Cycles")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Pulse.textPrimary)

            if overview.recentCycles.isEmpty {
                Text("Not enough data to show cycle history yet.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Pulse.textTertiary)
            } else {
                ForEach(overview.recentCycles) { cycle in
                    HStack {
                        Text(cycle.startDate, style: .date)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Pulse.textPrimary)
                        Spacer()
                        Text("\(cycle.length) days")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(cycle.length >= 24 && cycle.length <= 35 ? Pulse.positive : Pulse.warning)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Pulse.surfaceFallback)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Methodology

    private var methodologySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Research")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Pulse.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                methodLine("Follicular phase strength advantage", source: "McNulty et al. 2020, Sports Med")
                methodLine("Luteal phase substrate shifts (↑ fat oxidation)", source: "Oosthuyse & Bosch 2010, Sports Med")
                methodLine("Ovulatory ACL injury risk 2-3×", source: "Hewett et al. 2007, Am J Sports Med")
                methodLine("Luteal BMR increase +100-300 kcal/day", source: "Barr et al. 1995, Med Sci Sports Exerc")
                methodLine("Individual variation > population trends", source: "De Jonge 2003, Sports Med")
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

    private var phaseColor: Color {
        Color(hex: overview.currentPhase.color)
    }
}
