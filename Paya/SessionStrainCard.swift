import SwiftUI

struct SessionStrainCard: View {
    var report: SessionStrainCalculator.StrainReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(Color(hex: report.strainColorHex))
                Text("Session Load")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(report.strainLabel)
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color(hex: report.strainColorHex))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                StatMini(
                    label: "TRIMP",
                    value: String(format: "%.0f", report.trimpScore),
                    color: Color(hex: report.strainColorHex)
                )
                if let peak = report.peakHR {
                    StatMini(
                        label: "PEAK HR",
                        value: "\(peak)",
                        color: Pulse.critical
                    )
                }
                if let avg = report.avgHR {
                    StatMini(
                        label: "AVG HR",
                        value: "\(avg)",
                        color: Pulse.warning
                    )
                }
            }

            if report.totalActiveSeconds > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Time in zones")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(Pulse.textTertiary)
                    ZoneBar(zoneSeconds: report.timeInZoneSeconds)
                    ZoneLegend(zoneSeconds: report.timeInZoneSeconds)
                }
                .padding(.top, 4)
            }
        }
        .payaCard(padding: 14)
    }
}

struct StatMini: View {
    var label: String
    var value: String
    var color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.bold())
                .foregroundColor(color)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Pulse.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ZoneBar: View {
    var zoneSeconds: [Int]

    let colors: [Color] = [
        Pulse.hydration,
        Pulse.positive,
        Pulse.warning,
        Color(hex: "C2410C"),
        Pulse.critical
    ]

    var total: Int {
        zoneSeconds.reduce(0, +)
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(0..<5, id: \.self) { i in
                    let ratio = total > 0 ? CGFloat(zoneSeconds[i]) / CGFloat(total) : 0
                    Rectangle()
                        .fill(colors[i])
                        .frame(width: geo.size.width * ratio)
                }
            }
        }
        .frame(height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

struct ZoneLegend: View {
    var zoneSeconds: [Int]

    let colors: [Color] = [
        Pulse.hydration,
        Pulse.positive,
        Pulse.warning,
        Color(hex: "C2410C"),
        Pulse.critical
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { i in
                if zoneSeconds[i] > 0 {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(colors[i])
                            .frame(width: 6, height: 6)
                        Text("Z\(i + 1)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Pulse.textTertiary)
                        Text(SessionStrainCalculator.formatDuration(zoneSeconds[i]))
                            .font(.system(size: 9))
                            .foregroundColor(Pulse.textTertiary)
                    }
                }
            }
            Spacer()
        }
    }
}//
//  SessionStrainCard.swift
//  Paya
//
//  Created by Emin Huseynzade on 05.07.26.
//

