import SwiftUI

struct HRZoneDistributionCard: View {

    @Environment(AppState.self) private var appState
    var sessions: [TrainingSession]
    @State private var zones: [ZoneData] = []
    @State private var totalSamples: Int = 0

    var body: some View {
        Group {
            if !zones.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "heart.circle.fill")
                            .foregroundColor(.red)
                        Text("HR Zone Distribution")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("Last 10 sessions")
                            .font(.system(size: 9))
                            .foregroundColor(Pulse.textTertiary)
                    }

                    VStack(spacing: 6) {
                        ForEach(zones) { zone in
                            HStack(spacing: 8) {
                                Text(zone.name)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(zone.color)
                                    .frame(width: 50, alignment: .leading)

                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(zone.color)
                                        .frame(width: max(2, geo.size.width * CGFloat(zone.percent) / 100))
                                }
                                .frame(height: 14)

                                Text(String(format: "%.0f%%", zone.percent))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(Pulse.textTertiary)
                                    .frame(width: 34, alignment: .trailing)
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        ForEach(zones.prefix(3)) { zone in
                            HStack(spacing: 3) {
                                Circle().fill(zone.color).frame(width: 5, height: 5)
                                Text("\(zone.bpmRange)")
                                    .font(.system(size: 8))
                                    .foregroundColor(Pulse.textTertiary)
                            }
                        }
                    }

                    Text("Based on standard HR zones (% of est. max HR). Higher Zone 3-4 time indicates effective hypertrophy stimulus.")
                        .font(.system(size: 9))
                        .foregroundColor(Pulse.textTertiary)
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func compute() {
        let recent = sessions
            .filter { $0.isCompleted && $0.hrSamples != nil && !($0.hrSamples?.isEmpty ?? true) }
            .sorted { $0.date > $1.date }
            .prefix(10)

        guard !recent.isEmpty else { return }

        let allSamples = recent.flatMap { $0.hrSamples ?? [] }.filter { $0 > 0 }
        guard !allSamples.isEmpty else { return }
        totalSamples = allSamples.count

        let age = appState.profile.age > 0 ? appState.profile.age : 28
        let maxHR = 220 - age
        let z1Max = Int(Double(maxHR) * 0.6)
        let z2Max = Int(Double(maxHR) * 0.7)
        let z3Max = Int(Double(maxHR) * 0.8)
        let z4Max = Int(Double(maxHR) * 0.9)

        var z1 = 0, z2 = 0, z3 = 0, z4 = 0, z5 = 0
        for hr in allSamples {
            if hr <= z1Max { z1 += 1 }
            else if hr <= z2Max { z2 += 1 }
            else if hr <= z3Max { z3 += 1 }
            else if hr <= z4Max { z4 += 1 }
            else { z5 += 1 }
        }

        let total = Double(allSamples.count)
        zones = [
            ZoneData(name: "Zone 1", bpmRange: "<\(z1Max)", percent: Double(z1) / total * 100, color: Pulse.recovery),
            ZoneData(name: "Zone 2", bpmRange: "\(z1Max)-\(z2Max)", percent: Double(z2) / total * 100, color: Pulse.positive),
            ZoneData(name: "Zone 3", bpmRange: "\(z2Max)-\(z3Max)", percent: Double(z3) / total * 100, color: Pulse.nutrition),
            ZoneData(name: "Zone 4", bpmRange: "\(z3Max)-\(z4Max)", percent: Double(z4) / total * 100, color: Pulse.critical),
            ZoneData(name: "Zone 5", bpmRange: ">\(z4Max)", percent: Double(z5) / total * 100, color: Pulse.ai),
        ]
    }
}

private struct ZoneData: Identifiable {
    let name: String
    let bpmRange: String
    let percent: Double
    let color: Color
    var id: String { name }
}
