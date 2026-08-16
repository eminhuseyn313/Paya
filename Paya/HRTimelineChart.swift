import SwiftUI
import Charts

struct HRTimelineChart: View {
    var samples: [Int]
    var intervalSeconds: Int
    var maxHR: Int

    struct DataPoint: Identifiable {
        let id = UUID()
        let minute: Double
        let bpm: Int
    }

    var dataPoints: [DataPoint] {
        samples.enumerated().compactMap { index, bpm in
            guard bpm > 0 else { return nil }
            return DataPoint(
                minute: Double(index * intervalSeconds) / 60.0,
                bpm: bpm
            )
        }
    }

    var maxMinute: Double {
        dataPoints.last?.minute ?? 60
    }

    var hrAccessibilitySummary: String {
        guard !dataPoints.isEmpty else { return "No data" }
        let peak = dataPoints.map(\.bpm).max() ?? 0
        let avg = dataPoints.map(\.bpm).reduce(0, +) / dataPoints.count
        return "Peak \(peak) beats per minute, average \(avg), over \(Int(maxMinute)) minutes"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(Pulse.critical)
                Text("HR Timeline")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            if dataPoints.isEmpty {
                Text("No HR data recorded this session")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart {
                    ForEach([
                        ZoneBand(from: 0.5, to: 0.6, color: Pulse.hydration),
                        ZoneBand(from: 0.6, to: 0.7, color: Pulse.positive),
                        ZoneBand(from: 0.7, to: 0.8, color: Pulse.warning),
                        ZoneBand(from: 0.8, to: 0.9, color: Color(hex: "C2410C")),
                        ZoneBand(from: 0.9, to: 1.0, color: Pulse.critical)
                    ]) { band in
                        RectangleMark(
                            xStart: .value("start", 0.0),
                            xEnd: .value("end", maxMinute),
                            yStart: .value("y1", Double(maxHR) * band.from),
                            yEnd: .value("y2", Double(maxHR) * band.to)
                        )
                        .foregroundStyle(band.color.opacity(0.10))
                    }

                    ForEach(dataPoints) { point in
                        LineMark(
                            x: .value("Minute", point.minute),
                            y: .value("BPM", point.bpm)
                        )
                        .foregroundStyle(Pulse.critical)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 180)
                .accessibilityLabel("Heart rate over time")
                .accessibilityValue(hrAccessibilitySummary)
                .chartXAxis {
                    AxisMarks(preset: .aligned, position: .bottom) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let mins = value.as(Double.self) {
                                Text("\(Int(mins))m")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(preset: .aligned, position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let bpm = value.as(Int.self) {
                                Text("\(bpm)")
                                    .font(.caption2)
                            }
                        }
                    }
                }
            }
        }
        .payaCard(padding: 14)
    }
}

struct ZoneBand: Identifiable {
    let id = UUID()
    let from: Double
    let to: Double
    let color: Color
}//
//  HRTimelineChart.swift
//  Paya
//
//  Created by Emin Huseynzade on 05.07.26.
//

