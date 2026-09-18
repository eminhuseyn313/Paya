import SwiftUI

// MARK: - Allostatic Load Card
//
// Shows the user's composite stress-accumulation score in the Health tab.
// Tapping opens a detail sheet with per-driver breakdown.
// The score is labeled "Stress Load" to avoid medical terminology —
// allostatic load is the engine name, not the user-facing concept.

struct AllostasisCard: View {

    @State private var report: AllostasisEngine.AllostasisReport?
    @State private var isLoading = true
    @State private var showDetail = false

    var body: some View {
        Button { showDetail = true } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "gauge.with.dots.needle.50percent")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stress Load")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Pulse.textPrimary)
                        if let report {
                            Text("\(report.band.rawValue) · \(report.trajectory.rawValue)")
                                .font(.caption2)
                                .foregroundColor(Pulse.textTertiary)
                        } else if isLoading {
                            Text("Analyzing 30 days of data...")
                                .font(.caption2)
                                .foregroundColor(Pulse.textTertiary)
                        } else {
                            Text("Need 14+ days of HRV data")
                                .font(.caption2)
                                .foregroundColor(Pulse.textTertiary)
                        }
                    }
                    Spacer()

                    if let report {
                        HStack(spacing: 4) {
                            Text("\(report.score)")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundColor(bandColor(report.band))
                            Image(systemName: report.trajectory.icon)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(trajectoryColor(report.trajectory))
                        }
                    } else if isLoading {
                        ProgressView()
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Pulse.textTertiary)
                }

                if let report {
                    // Mini driver bars
                    HStack(spacing: 4) {
                        ForEach(report.drivers.prefix(4)) { driver in
                            VStack(spacing: 3) {
                                GeometryReader { geo in
                                    let filled = driver.score * geo.size.height
                                    VStack(spacing: 0) {
                                        Spacer(minLength: 0)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(driverBarColor(driver.score))
                                            .frame(height: max(2, filled))
                                    }
                                }
                                .frame(height: 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.white.opacity(0.05))
                                )

                                Image(systemName: driver.icon)
                                    .font(.system(size: 7))
                                    .foregroundColor(Pulse.textTertiary)
                            }
                        }
                    }

                    Text(report.recommendation)
                        .font(.system(size: 10))
                        .foregroundColor(Pulse.textTertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .payaCard(padding: 14)
        }
        .buttonStyle(PulsePress())
        .disabled(report == nil && !isLoading)
        .task {
            report = await AllostasisEngine.compute()
            isLoading = false
        }
        .sheet(isPresented: $showDetail) {
            if let report {
                AllostasisDetailView(report: report)
            }
        }
    }

    private var iconColor: Color {
        guard let report else { return Pulse.textTertiary }
        return bandColor(report.band)
    }

    private func bandColor(_ band: AllostasisEngine.Band) -> Color {
        switch band {
        case .low:      return Pulse.positive
        case .moderate: return Pulse.recovery
        case .elevated: return Pulse.warning
        case .high:     return Pulse.critical
        }
    }

    private func trajectoryColor(_ t: AllostasisEngine.Trajectory) -> Color {
        switch t {
        case .rising:  return Pulse.critical
        case .stable:  return Pulse.textTertiary
        case .falling: return Pulse.positive
        }
    }

    private func driverBarColor(_ score: Double) -> Color {
        switch score {
        case 0..<0.3:  return Pulse.positive
        case 0.3..<0.6: return Pulse.warning
        default:       return Pulse.critical
        }
    }
}

// MARK: - Detail View

struct AllostasisDetailView: View {

    let report: AllostasisEngine.AllostasisReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroSection
                    driversSection
                    recommendationSection
                    methodologySection
                }
                .padding(16)
            }
            .navigationTitle("Stress Load")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // Score ring
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 8)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: Double(report.score) / 100)
                    .stroke(
                        bandColor(report.band),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(report.score)")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(bandColor(report.band))
                    HStack(spacing: 3) {
                        Image(systemName: report.trajectory.icon)
                            .font(.system(size: 9))
                        Text(report.trajectory.rawValue)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(trajectoryColor(report.trajectory))
                }
            }

            Text(report.band.rawValue)
                .font(.headline.weight(.bold))
                .foregroundColor(bandColor(report.band))

            Text("Based on \(report.dataPoints) days of wearable data")
                .font(.caption2)
                .foregroundColor(Pulse.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .payaCard(padding: 20)
    }

    private var driversSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STRESS DRIVERS")
                .font(.caption.weight(.bold))
                .foregroundColor(Pulse.textTertiary)

            ForEach(report.drivers) { driver in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(driverColor(driver.score).opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: driver.icon)
                            .font(.system(size: 13))
                            .foregroundColor(driverColor(driver.score))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(driver.label)
                                .font(.caption.weight(.bold))
                                .foregroundColor(Pulse.textPrimary)
                            Spacer()
                            Text("\(Int(driver.weight * 100))%")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Pulse.textTertiary)
                        }

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.06))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(driverColor(driver.score))
                                    .frame(width: max(4, driver.score * geo.size.width))
                            }
                        }
                        .frame(height: 6)

                        Text(driver.detail)
                            .font(.system(size: 10))
                            .foregroundColor(Pulse.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .background(Pulse.surfaceElevatedFallback)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundColor(Pulse.nutrition)
                Text("RECOMMENDATION")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Pulse.textTertiary)
            }

            Text(report.recommendation)
                .font(.subheadline)
                .foregroundColor(Pulse.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .payaCard(padding: 14)
    }

    private var methodologySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOW THIS WORKS")
                .font(.caption.weight(.bold))
                .foregroundColor(Pulse.textTertiary)

            VStack(alignment: .leading, spacing: 6) {
                methodRow("heart.fill", "Combines HRV trend, resting HR, sleep, temperature, and training load into one composite score")
                methodRow("chart.line.uptrend.xyaxis", "Uses 30-day baseline with 14-day trend analysis (Johns Hopkins 2025, Davy et al. 2024)")
                methodRow("person.fill", "All thresholds are relative to YOUR baseline, not population averages")
                methodRow("exclamationmark.triangle.fill", "This is not a medical diagnosis — it tracks stress accumulation from wearable signals")
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

    private func bandColor(_ band: AllostasisEngine.Band) -> Color {
        switch band {
        case .low:      return Pulse.positive
        case .moderate: return Pulse.recovery
        case .elevated: return Pulse.warning
        case .high:     return Pulse.critical
        }
    }

    private func trajectoryColor(_ t: AllostasisEngine.Trajectory) -> Color {
        switch t {
        case .rising:  return Pulse.critical
        case .stable:  return Pulse.textTertiary
        case .falling: return Pulse.positive
        }
    }

    private func driverColor(_ score: Double) -> Color {
        switch score {
        case 0..<0.3:  return Pulse.positive
        case 0.3..<0.6: return Pulse.warning
        default:       return Pulse.critical
        }
    }
}
