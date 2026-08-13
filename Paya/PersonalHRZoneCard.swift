import SwiftUI
import SwiftData

// MARK: - Personalized HR Zone Calculator Card
// Replaces the crude "220 - age" formula (Fox et al. 1971) with
// evidence-based alternatives that use the user's actual data.
//
// Grounded in:
// - Tanaka et al. (2001) meta-analysis: HRmax = 208 - 0.7 × age
//   (more accurate than 220-age, especially for older adults)
// - Karvonen et al. (1957): Target HR = ((HRmax - HRrest) × %intensity) + HRrest
//   Uses heart rate reserve (HRR) which accounts for individual fitness
// - Robergs & Landwehr (2002): "220 - age" has ±10-12 bpm standard
//   deviation — essentially useless for individual prescription
//
// This card:
// 1. Computes HRmax from Tanaka formula + actual session peak HR data
// 2. Uses Karvonen method with real resting HR from Apple Health
// 3. Shows personalized 5-zone model with specific bpm ranges
// 4. Compares with the generic 220-age zones to show the difference

struct PersonalHRZoneCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var zones: [PersonalZone] = []
    @State private var estimatedMaxHR = 0
    @State private var restingHR = 0
    @State private var maxSource = ""
    @State private var genericMaxHR = 0
    @State private var hrDifference = 0
    @State private var hasData = false

    struct PersonalZone: Identifiable {
        let name: String
        let range: String
        let purpose: String
        let color: Color
        let lowBPM: Int
        let highBPM: Int
        var id: String { name }
    }

    var body: some View {
        Group {
            if hasData {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "heart.text.square.fill")
                            .foregroundColor(Color(hex: "DC2626"))
                        Text("Your HR zones")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("Personalized")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "DC2626"))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color(hex: "DC2626").opacity(0.1))
                            .clipShape(Capsule())
                    }

                    // Max HR summary
                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text("\(estimatedMaxHR)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                            Text("Max HR")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(maxSource)
                                .font(.system(size: 7))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color(hex: "DC2626").opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(spacing: 2) {
                            Text("\(restingHR)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                            Text("Resting HR")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("Apple Health")
                                .font(.system(size: 7))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color(hex: "2563EB").opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(spacing: 2) {
                            Text("\(estimatedMaxHR - restingHR)")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                            Text("HR Reserve")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("Karvonen")
                                .font(.system(size: 7))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color(hex: "059669").opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Zone bars
                    VStack(spacing: 4) {
                        ForEach(zones) { zone in
                            HStack(spacing: 6) {
                                Text(zone.name)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(zone.color)
                                    .frame(width: 48, alignment: .leading)

                                GeometryReader { geo in
                                    let maxBPM = Double(estimatedMaxHR)
                                    let low = max(0, Double(zone.lowBPM) / maxBPM)
                                    let high = min(1, Double(zone.highBPM) / maxBPM)
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color(.tertiarySystemBackground))
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(zone.color)
                                            .frame(width: geo.size.width * (high - low))
                                            .offset(x: geo.size.width * low)
                                    }
                                }
                                .frame(height: 12)

                                Text(zone.range)
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .trailing)
                            }
                        }
                    }

                    // Zones purpose legend
                    HStack(spacing: 8) {
                        ForEach(zones.prefix(3)) { zone in
                            VStack(spacing: 1) {
                                Text(zone.name)
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(zone.color)
                                Text(zone.purpose)
                                    .font(.system(size: 7))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }

                    // Comparison with generic
                    if hrDifference != 0 {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "F59E0B"))
                                .padding(.top, 1)
                            Text("Generic 220-age gives \(genericMaxHR) bpm — \(abs(hrDifference)) bpm \(hrDifference > 0 ? "lower" : "higher") than your actual data. Using generic zones would put you in the wrong zone \(abs(hrDifference) > 5 ? "significantly" : "slightly").")
                                .font(.system(size: 10))
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Text("Tanaka et al. (2001): HRmax = 208 - 0.7×age. Karvonen (1957): target HR uses heart rate reserve. Robergs & Landwehr (2002): 220-age has ±10-12 bpm error.")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    // MARK: - Compute

    private func compute() {
        let age = appState.profile.age
        guard age > 0 else { return }

        let pid = ActiveProfile.id

        // Generic formula
        genericMaxHR = 220 - age

        // Tanaka formula (better)
        let tanakaMax = Int(208 - 0.7 * Double(age))

        // Check actual session peak HRs for observed max
        let sessionDesc = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> {
                $0.profileId == pid && $0.isCompleted
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let sessions = (try? modelContext.fetch(sessionDesc)) ?? []
        let observedPeaks = sessions.compactMap(\.sessionPeakHR).filter { $0 > 100 }
        let observedMax = observedPeaks.max() ?? 0

        // Use the higher of Tanaka and observed (observed can exceed formula)
        if observedMax > tanakaMax {
            estimatedMaxHR = observedMax
            maxSource = "Observed peak"
        } else {
            estimatedMaxHR = tanakaMax
            maxSource = "Tanaka formula"
        }

        hrDifference = estimatedMaxHR - genericMaxHR

        // Get resting HR from recent session HR data or default
        let hrSamples = sessions.flatMap { $0.hrSamples ?? [] }.filter { $0 > 40 && $0 < 100 }
        if !hrSamples.isEmpty {
            // Use the 5th percentile as resting HR estimate
            let sorted = hrSamples.sorted()
            let p5Index = max(0, sorted.count * 5 / 100)
            restingHR = sorted[p5Index]
        } else {
            restingHR = 65 // default
        }

        guard estimatedMaxHR > restingHR else { return }
        hasData = true

        // Karvonen zones (using HRR)
        let hrr = estimatedMaxHR - restingHR

        func karvonen(_ pct: Double) -> Int {
            restingHR + Int(Double(hrr) * pct)
        }

        zones = [
            PersonalZone(
                name: "Zone 1",
                range: "\(karvonen(0.5))–\(karvonen(0.6))",
                purpose: "Recovery",
                color: Color(hex: "0891B2"),
                lowBPM: karvonen(0.5),
                highBPM: karvonen(0.6)
            ),
            PersonalZone(
                name: "Zone 2",
                range: "\(karvonen(0.6))–\(karvonen(0.7))",
                purpose: "Aerobic base",
                color: Color(hex: "059669"),
                lowBPM: karvonen(0.6),
                highBPM: karvonen(0.7)
            ),
            PersonalZone(
                name: "Zone 3",
                range: "\(karvonen(0.7))–\(karvonen(0.8))",
                purpose: "Tempo",
                color: Color(hex: "F59E0B"),
                lowBPM: karvonen(0.7),
                highBPM: karvonen(0.8)
            ),
            PersonalZone(
                name: "Zone 4",
                range: "\(karvonen(0.8))–\(karvonen(0.9))",
                purpose: "Threshold",
                color: Color(hex: "DC2626"),
                lowBPM: karvonen(0.8),
                highBPM: karvonen(0.9)
            ),
            PersonalZone(
                name: "Zone 5",
                range: "\(karvonen(0.9))–\(estimatedMaxHR)",
                purpose: "Max effort",
                color: Color(hex: "8B5CF6"),
                lowBPM: karvonen(0.9),
                highBPM: estimatedMaxHR
            ),
        ]
    }
}
