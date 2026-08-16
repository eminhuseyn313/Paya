import SwiftUI
import SwiftData

// MARK: - Soreness Correlation Card
//
// "Cannot see yesterday's body heatmap, and is my soreness today actually
// correlated with it or not." Two real gaps in one card: yesterday's effort
// map wasn't shown anywhere outside editing that exact session, and there
// was no way to say WHERE you're sore — only a single overall 1-5 number —
// so nothing could ever be checked against it. This shows yesterday's map,
// lets you tap where you're sore right on the same body, and gives a
// region-by-region verdict instead of an invented correlation coefficient.
// Each tap cycles off → sore (DOMS) → flare/joint pain → off, since those
// two need different responses and a single soreness number can't tell them
// apart.

struct SorenessCorrelationCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var result: SorenessCorrelationEngine.Result? = nil
    @State private var soreKinds: [BodyRegion: SorenessKind] = [:]

    var body: some View {
        Group {
            if let result, result.referenceSession != nil {
                content(result)
            }
        }
        .onAppear { load() }
    }

    @ViewBuilder
    private func content(_ result: SorenessCorrelationEngine.Result) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "figure.cooldown")
                    .foregroundColor(Color(hex: "7C3AED"))
                Text("Soreness vs. Yesterday's Effort")
                    .font(.subheadline.weight(.semibold))
                CardInfoButton(
                    title: "Soreness vs. Effort",
                    explanation: "Tap a region to cycle it through sore (DOMS) → flare/joint pain → off. Each is checked against how hard that region was trained across your last 3 days — not just yesterday, since DOMS commonly peaks 24-72h after training (Cheung et al., Sports Med 2003) — using heart rate when available, training load otherwise."
                )
                Spacer()
            }

            if !result.referenceIsYesterday, let session = result.referenceSession {
                Text("No session logged yesterday — showing your last one instead (\(session.date.formatted(.dateTime.month(.abbreviated).day()))).")
                    .font(.caption2)
                    .foregroundColor(Pulse.textTertiary)
            }

            HStack(spacing: 24) {
                Spacer()
                VStack(spacing: 4) {
                    ZStack {
                        BodyFigureView(isFront: true, regionColors: colorMap(result))
                        soreOverlay(isFront: true)
                    }
                    Text("Front").font(.caption2).foregroundColor(Pulse.textTertiary)
                }
                VStack(spacing: 4) {
                    ZStack {
                        BodyFigureView(isFront: false, regionColors: colorMap(result))
                        soreOverlay(isFront: false)
                    }
                    Text("Back").font(.caption2).foregroundColor(Pulse.textTertiary)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Text("Tap where you're sore today").font(.caption2.weight(.bold)).foregroundColor(Pulse.textTertiary)
                Spacer()
                legendDot(Color(hex: "7C3AED"), "DOMS")
                legendDot(Pulse.critical, "Flare")
            }

            FlowChips(
                regions: BodyRegion.allCases,
                kinds: soreKinds,
                onTap: { region in
                    withAnimation(.spring(response: 0.25)) {
                        switch soreKinds[region] {
                        case .none: soreKinds[region] = .doms
                        case .doms: soreKinds[region] = .flare
                        case .flare: soreKinds[region] = nil
                        }
                    }
                    SorenessCorrelationEngine.cycle(region, context: modelContext)
                    load()
                }
            )

            if let summary = result.summary {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: result.flareTaggedUnexplainedCount > 0 ? "exclamationmark.triangle.fill" : (result.unexplainedCount > 0 && result.matchedCount == 0 ? "questionmark.circle.fill" : "checkmark.seal.fill"))
                        .font(.caption)
                        .foregroundColor(result.flareTaggedUnexplainedCount > 0 ? Pulse.critical : (result.matchedCount > 0 ? Pulse.positive : Pulse.warning))
                    Text(summary)
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .payaCard(padding: 14)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().stroke(color, lineWidth: 2).frame(width: 8, height: 8)
            Text(label).font(.system(size: 9)).foregroundColor(Pulse.textTertiary)
        }
    }

    @ViewBuilder
    private func soreOverlay(isFront: Bool) -> some View {
        let positions: [(BodyRegion, CGPoint)] = isFront
            ? [(.frontDelts, CGPoint(x: 34, y: 46)), (.frontDelts, CGPoint(x: 76, y: 46)),
               (.chest, CGPoint(x: 55, y: 62)), (.abs, CGPoint(x: 55, y: 96)),
               (.biceps, CGPoint(x: 30, y: 80)), (.biceps, CGPoint(x: 80, y: 80)),
               (.quads, CGPoint(x: 44, y: 160)), (.quads, CGPoint(x: 66, y: 160))]
            : [(.rearDelts, CGPoint(x: 34, y: 46)), (.rearDelts, CGPoint(x: 76, y: 46)),
               (.back, CGPoint(x: 55, y: 78)), (.triceps, CGPoint(x: 30, y: 80)), (.triceps, CGPoint(x: 80, y: 80)),
               (.glutes, CGPoint(x: 55, y: 132)), (.hamstrings, CGPoint(x: 44, y: 168)), (.hamstrings, CGPoint(x: 66, y: 168)),
               (.calves, CGPoint(x: 44, y: 210)), (.calves, CGPoint(x: 66, y: 210))]

        ForEach(Array(positions.enumerated()), id: \.offset) { _, pair in
            if let kind = soreKinds[pair.0] {
                Circle()
                    .stroke(kind == .flare ? Pulse.critical : Color(hex: "7C3AED"), lineWidth: 2.5)
                    .frame(width: 14, height: 14)
                    .position(pair.1)
            }
        }
    }

    private func colorMap(_ result: SorenessCorrelationEngine.Result) -> [BodyRegion: Color] {
        result.regionColors.mapValues { Color(hex: $0.colorHex) }
    }

    private func load() {
        let entries = SorenessCorrelationEngine.todaysSoreEntries(context: modelContext)
        soreKinds = Dictionary(uniqueKeysWithValues: entries.map { ($0.region, $0.kind) })
        result = SorenessCorrelationEngine.analyze(context: modelContext, maxHR: LiveHRManager.shared.maxHR)
    }
}

private struct FlowChips: View {
    let regions: [BodyRegion]
    let kinds: [BodyRegion: SorenessKind]
    let onTap: (BodyRegion) -> Void

    private let columns = [GridItem(.adaptive(minimum: 78), spacing: 6)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(regions, id: \.self) { region in
                let kind = kinds[region]
                Button {
                    onTap(region)
                } label: {
                    Text(region.displayName)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(kind == nil ? .primary : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(chipColor(kind))
                        .clipShape(Capsule())
                }
                .buttonStyle(PulsePress())
            }
        }
    }

    private func chipColor(_ kind: SorenessKind?) -> Color {
        switch kind {
        case .none: return Color(.tertiarySystemFill)
        case .doms: return Color(hex: "7C3AED")
        case .flare: return Pulse.critical
        }
    }
}
