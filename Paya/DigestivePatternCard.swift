import SwiftUI
import SwiftData

// MARK: - Digestive Pattern Card
//
// Surfaces food → gut correlations personal to this user.
// Shows a digestive health score + top triggers + pattern details.

struct DigestivePatternCard: View {

    @Environment(\.modelContext) private var modelContext
    @State private var report: DigestivePatternEngine.Report?
    @State private var isLoading = true
    @State private var showDetail = false

    var body: some View {
        if report != nil || isLoading {
            Button { showDetail = true } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Pulse.hydration.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: "stomach")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Pulse.hydration)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Digestive Patterns")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(Pulse.textPrimary)
                            if isLoading {
                                Text("Analyzing food × gut data…")
                                    .font(.caption2)
                                    .foregroundColor(Pulse.textTertiary)
                            } else if let r = report {
                                Text("\(r.patterns.count) pattern\(r.patterns.count == 1 ? "" : "s") · \(r.topTriggers.count) trigger\(r.topTriggers.count == 1 ? "" : "s")")
                                    .font(.caption2)
                                    .foregroundColor(Pulse.textTertiary)
                            }
                        }
                        Spacer()

                        if isLoading {
                            ProgressView()
                        } else if let r = report {
                            VStack(spacing: 2) {
                                Text("\(r.digestiveScore)")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundColor(scoreColor(r.digestiveScore))
                                Text("gut score")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(Pulse.textTertiary)
                            }
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Pulse.textTertiary)
                    }

                    // Top trigger pills
                    if let r = report, !r.topTriggers.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(r.topTriggers.prefix(3)) { trigger in
                                HStack(spacing: 3) {
                                    Image(systemName: trigger.icon)
                                        .font(.system(size: 7))
                                    Text(trigger.label)
                                        .font(.system(size: 8, weight: .medium))
                                }
                                .foregroundColor(triggerColor(trigger.badOutcomeRate))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(triggerColor(trigger.badOutcomeRate).opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
                .payaCard(padding: 14)
            }
            .buttonStyle(PulsePress())
            .disabled(report == nil)
            .task {
                report = await DigestivePatternEngine.compute(context: modelContext)
                isLoading = false
            }
            .sheet(isPresented: $showDetail) {
                if let report {
                    DigestivePatternDetailView(report: report)
                }
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return Pulse.positive
        case 50..<80: return Pulse.nutrition
        default: return Pulse.critical
        }
    }

    private func triggerColor(_ rate: Double) -> Color {
        switch rate {
        case 0.5...: return Pulse.critical
        case 0.3..<0.5: return Pulse.warning
        default: return Pulse.textTertiary
        }
    }
}

// MARK: - Detail View

struct DigestivePatternDetailView: View {

    let report: DigestivePatternEngine.Report
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    scoreCard
                    if !report.topTriggers.isEmpty { triggersSection }
                    if !report.patterns.isEmpty { patternsSection }
                    methodologySection
                }
                .padding(16)
            }
            .navigationTitle("Digestive Patterns")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var scoreCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 8)
                    .frame(width: 90, height: 90)
                Circle()
                    .trim(from: 0, to: Double(report.digestiveScore) / 100)
                    .stroke(
                        scoreColor(report.digestiveScore),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text("\(report.digestiveScore)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(scoreColor(report.digestiveScore))
                    Text("GUT")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Pulse.textTertiary)
                }
            }

            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(report.idealDays)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.positive)
                    Text("Ideal days")
                        .font(.system(size: 9))
                        .foregroundColor(Pulse.textTertiary)
                }
                Divider().frame(height: 24)
                VStack(spacing: 2) {
                    Text("\(report.totalTrackedDays)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Tracked days")
                        .font(.system(size: 9))
                        .foregroundColor(Pulse.textTertiary)
                }
            }

            Text("Score = % of days with ideal stool (Bristol 3-4)")
                .font(.system(size: 9))
                .foregroundColor(Pulse.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .payaCard(padding: 20)
    }

    private var triggersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR TRIGGERS")
                .font(.caption.weight(.bold))
                .foregroundColor(Pulse.textTertiary)

            ForEach(report.topTriggers) { trigger in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(triggerColor(trigger.badOutcomeRate).opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: trigger.icon)
                            .font(.system(size: 13))
                            .foregroundColor(triggerColor(trigger.badOutcomeRate))
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(trigger.label)
                            .font(.caption.weight(.bold))
                            .foregroundColor(Pulse.textPrimary)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.06))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(triggerColor(trigger.badOutcomeRate))
                                    .frame(width: max(4, trigger.badOutcomeRate * geo.size.width))
                            }
                        }
                        .frame(height: 6)

                        Text("\(Int(trigger.badOutcomeRate * 100))% bad outcome rate · \(trigger.occurrences) days")
                            .font(.system(size: 9))
                            .foregroundColor(Pulse.textTertiary)
                    }
                }
                .padding(10)
                .background(Pulse.surfaceElevatedFallback)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PATTERNS")
                .font(.caption.weight(.bold))
                .foregroundColor(Pulse.textTertiary)

            ForEach(report.patterns) { pattern in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: categoryIcon(pattern.category))
                            .font(.system(size: 10))
                            .foregroundColor(toneColor(pattern.tone))
                        Text(pattern.category.rawValue)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Pulse.textTertiary)
                            .textCase(.uppercase)
                        Spacer()
                        Text("\(pattern.sampleDays)d")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Pulse.textTertiary)
                    }

                    HStack(spacing: 8) {
                        Text(pattern.metric)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(toneColor(pattern.tone))
                        Text(pattern.headline)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Pulse.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(pattern.detail)
                        .font(.system(size: 10))
                        .foregroundColor(Pulse.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .background(Pulse.surfaceElevatedFallback)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private var methodologySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HOW THIS WORKS")
                .font(.caption.weight(.bold))
                .foregroundColor(Pulse.textTertiary)

            VStack(alignment: .leading, spacing: 5) {
                methodRow("fork.knife", "Compares your food log macros with next-day bathroom outcomes")
                methodRow("stomach", "Bristol Stool Scale 3-4 = ideal transit time (Lewis & Heaton 1997)")
                methodRow("person.fill", "Individual trigger identification is the gold standard (Koloski 2019)")
                methodRow("clock.fill", "Uses 12-24h lag window matching typical gut transit (Böhn 2013)")
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

    private func categoryIcon(_ cat: DigestivePatternEngine.Pattern.Category) -> String {
        switch cat {
        case .fiber:    return "leaf.fill"
        case .sugar:    return "cube.fill"
        case .fat:      return "drop.fill"
        case .mealSize: return "fork.knife"
        case .hydration: return "drop.halffull"
        case .timing:   return "clock.fill"
        case .symptom:  return "exclamationmark.triangle.fill"
        }
    }

    private func toneColor(_ tone: DigestivePatternEngine.Pattern.Tone) -> Color {
        switch tone {
        case .positive: return Pulse.positive
        case .negative: return Pulse.critical
        case .neutral:  return Pulse.textTertiary
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return Pulse.positive
        case 50..<80: return Pulse.nutrition
        default: return Pulse.critical
        }
    }

    private func triggerColor(_ rate: Double) -> Color {
        switch rate {
        case 0.5...: return Pulse.critical
        case 0.3..<0.5: return Pulse.warning
        default: return Pulse.nutrition
        }
    }
}
