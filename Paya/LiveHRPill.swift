import SwiftUI

struct LiveHRPill: View {

    var hr: LiveHRManager = .shared

    @State private var pulse: Bool = false

    var body: some View {
        if let bpm = hr.currentBPM {
            HStack(spacing: 5) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .scaleEffect(pulse ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: pulse
                    )
                Text("\(bpm)")
                    .font(.system(size: 12, weight: .bold))
                    .monospacedDigit()
                if let zone = hr.currentZone {
                    Text(zone.shortName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(zone.color)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    hr.currentZone?.color.opacity(0.4) ?? .clear,
                    lineWidth: 1
                )
            )
            .onAppear { pulse = true }
        }
    }
}

struct LiveHRPanel: View {

    var hr: LiveHRManager = .shared
    var peakBPM: Int?
    var restStartBPM: Int?

    @State private var pulse: Bool = false

    var currentBPM: Int? { hr.currentBPM }

    var recoveryDrop: Int? {
        guard let peak = peakBPM, let current = currentBPM, peak > current else { return nil }
        return peak - current
    }

    var body: some View {
        VStack(spacing: 10) {

            if let bpm = currentBPM, let zone = hr.currentZone {

                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                        .scaleEffect(pulse ? 1.15 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                            value: pulse
                        )

                    Text("\(bpm)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    VStack(alignment: .leading, spacing: 0) {
                        Text("BPM")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(zone.shortName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(zone.color)
                    }
                }
                .onAppear { pulse = true }

                Text(zone.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(zone.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(zone.color.opacity(0.12))
                    .clipShape(Capsule())

                if let peak = peakBPM, let drop = recoveryDrop {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("PEAK")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("\(peak)")
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                        }

                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("NOW")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("\(bpm)")
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                        }

                        Image(systemName: "arrow.down")
                            .font(.caption2)
                            .foregroundColor(Color(hex: "059669"))

                        Text("\(drop)")
                            .font(.subheadline.weight(.bold))
                            .foregroundColor(Color(hex: "059669"))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
                }
            } else {

                HStack(spacing: 6) {
                    Image(systemName: "heart.slash")
                        .foregroundColor(.secondary)
                    Text("No HR monitor connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}//
//  LiveHRPill.swift
//  Paya
//
//  Created by Emin Huseynzade on 05.07.26.
//

