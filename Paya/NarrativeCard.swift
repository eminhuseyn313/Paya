import SwiftUI

// MARK: - Narrative Card
//
// Displays a DailyNarrativeEngine.Narrative — the ONE headline finding for
// today, with everything else as ranked supporting points instead of
// separate cards. Sits at the top of the Health tab's Insights section,
// ahead of the individual per-domain cards it draws from — those still
// exist below for anyone who wants the full detail behind any one signal;
// this is the "read this first" layer.

struct NarrativeCard: View {

    var narrative: DailyNarrativeEngine.Narrative?
    var isLoading: Bool
    @State private var expanded = false

    var body: some View {
        if isLoading {
            loadingState
        } else if let narrative {
            content(narrative)
        }
        // Nothing to show and not loading → render nothing rather than an
        // empty-state card; a day with no signal worth surfacing shouldn't
        // occupy space at the top of the section.
    }

    private var loadingState: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(Pulse.ai)
            Text("Reading today's signals…")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
            Spacer()
        }
        .payaCard(padding: 14)
    }

    private func content(_ narrative: DailyNarrativeEngine.Narrative) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if !narrative.supporting.isEmpty {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        expanded.toggle()
                    }
                }
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundColor(Pulse.ai)
                        Text("Today's story")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Pulse.textTertiary)
                            .textCase(.uppercase)
                        Spacer()
                        if narrative.sourceCount > 1 {
                            Text("from \(narrative.sourceCount) signals")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Pulse.textTertiary)
                        }
                    }

                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: narrative.headline.colorHex).opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: narrative.headline.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(hex: narrative.headline.colorHex))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(narrative.headline.source)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: narrative.headline.colorHex))
                                .textCase(.uppercase)
                            Text(narrative.headline.text)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Pulse.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

                        if !narrative.supporting.isEmpty {
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Pulse.textTertiary)
                                .padding(.top, 2)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            if expanded && !narrative.supporting.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().padding(.top, 12).padding(.bottom, 2)
                    ForEach(narrative.supporting) { point in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: point.icon)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: point.colorHex))
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(point.source)
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Pulse.textTertiary)
                                    .textCase(.uppercase)
                                Text(point.text)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Pulse.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            } else if !narrative.supporting.isEmpty {
                Text("+\(narrative.supporting.count) more signal\(narrative.supporting.count == 1 ? "" : "s") — tap to expand")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Pulse.textTertiary)
                    .padding(.top, 8)
            }
        }
        .payaCard(padding: 14)
    }
}
