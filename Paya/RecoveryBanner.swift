import SwiftUI

// MARK: - Recovery Banner
// Shown at the top of the Train tab when today's loads have been recovery-adjusted.
// Explains WHY so the user understands the app isn't being arbitrary.

struct RecoveryBanner: View {

    var adjustment: RecoveryAdjuster.Adjustment

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(adjustment.severity.color.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: adjustment.severity.icon)
                            .font(.headline)
                            .foregroundColor(adjustment.severity.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(adjustment.multiplier > 1.0 ? "Primed" : adjustment.severity.label)
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(Pulse.textPrimary)
                            Text("· \(adjustment.signedPercentLabel)")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(adjustment.severity.color)
                        }
                        Text("\(adjustment.reasons.count) signal\(adjustment.reasons.count == 1 ? "" : "s") · tap to see why")
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                }
                .padding(14)
            }
            .buttonStyle(PulsePress())

            if isExpanded {
                Divider().padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(adjustment.reasons) { reason in
                        HStack(spacing: 10) {
                            Image(systemName: reason.icon)
                                .font(.caption)
                                .foregroundColor(adjustment.severity.color)
                                .frame(width: 22)
                            Text(reason.text)
                                .font(.caption)
                                .foregroundColor(Pulse.textPrimary)
                            Spacer()
                        }
                    }

                    Divider()

                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundColor(Pulse.textTertiary)
                        Text("You can still override any weight manually.")
                            .font(.caption2)
                            .foregroundColor(Pulse.textTertiary)
                        Spacer()
                    }
                }
                .padding(14)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(adjustment.severity.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Quick Session Banner
//
// Offered alongside the recovery banner on a caution/deload day — the
// binary choice has always been "do the full session or skip it," and a
// skipped day gets you nothing. This is the third option: today's compound
// lifts only, 2 sets each. Consistency over completeness for one day.

struct QuickSessionBanner: View {
    var onAccept: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Pulse.ai.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "bolt.fill")
                    .font(.subheadline)
                    .foregroundColor(Pulse.ai)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Shorter workout available")
                    .font(.caption.weight(.semibold))
                Text("Your recovery is low — switch to a 20-min session with only the key compound lifts, 2 sets each. Still counts toward your weekly volume.")
                    .font(.caption2)
                    .foregroundColor(Pulse.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Switch", action: onAccept)
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Pulse.ai)
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Pulse.ai.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Pulse.ai.opacity(0.2), lineWidth: 1))
    }
}//
//  RecoveryBanner.swift
//  Paya
//
//  Created by Emin Huseynzade on 05.07.26.
//

