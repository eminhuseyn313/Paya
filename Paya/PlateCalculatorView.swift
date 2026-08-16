import SwiftUI

// MARK: - Plate Calculator View
// "What do I actually load on the bar for this weight" — shown from the
// number pad while logging a set.

struct PlateCalculatorView: View {

    @Environment(\.dismiss) private var dismiss

    var targetWeightKg: Double
    var sessionColor: Color

    // Remembers your last bar choice across uses — most gyms only have one
    // or two bar types, re-picking it every single set is friction with no
    // payoff.
    @AppStorage("plateCalculator_barWeight") private var storedBarWeight: Double = PlateCalculator.BarWeight.olympic.rawValue
    @State private var barWeight: PlateCalculator.BarWeight = .olympic

    private var plates: [Double] {
        PlateCalculator.platesPerSide(targetWeightKg: targetWeightKg, barWeightKg: barWeight.rawValue) ?? []
    }

    private var achieved: Double {
        PlateCalculator.achievedWeight(plates: plates, barWeightKg: barWeight.rawValue)
    }

    private var isExactMatch: Bool {
        abs(achieved - targetWeightKg) < 0.05
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Bar", selection: $barWeight) {
                    ForEach(PlateCalculator.BarWeight.allCases) { bar in
                        Text(bar.label).tag(bar)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Text(String(format: "%.1f kg total", targetWeightKg))
                    .font(.title2.bold())

                if !isExactMatch {
                    Text("Closest achievable: \(String(format: "%.2f", achieved))kg with this plate set")
                        .font(.caption)
                        .foregroundColor(Pulse.warning)
                }

                // Visual bar
                HStack(spacing: 3) {
                    ForEach(Array(plates.reversed().enumerated()), id: \.offset) { _, plate in
                        PlateBar(weightKg: plate, color: sessionColor)
                    }
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray3))
                        .frame(width: 50, height: 14)
                }
                .frame(height: 140, alignment: .center)
                .frame(maxWidth: .infinity)

                Text("Per side — mirror on the other end")
                    .font(.caption2)
                    .foregroundColor(Pulse.textTertiary)

                if plates.isEmpty {
                    Text(targetWeightKg < barWeight.rawValue
                         ? "Target is lighter than the bar itself."
                         : "No plates needed — bar weight only.")
                        .font(.subheadline)
                        .foregroundColor(Pulse.textTertiary)
                        .padding(.top, 8)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(Dictionary(grouping: plates, by: { $0 }).sorted { $0.key > $1.key }), id: \.key) { weight, group in
                            HStack {
                                Text("\(group.count) ×")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(Pulse.textTertiary)
                                Text("\(weight, specifier: "%.2f") kg plate\(group.count > 1 ? "s" : "")")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                            }
                        }
                    }
                    .payaCard(padding: 14)
                    .padding(.horizontal, 20)
                }

                Spacer()
            }
            .padding(.bottom, 20)
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            barWeight = PlateCalculator.BarWeight(rawValue: storedBarWeight) ?? .olympic
        }
        .onChange(of: barWeight) { _, newValue in
            storedBarWeight = newValue.rawValue
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PlateBar: View {
    var weightKg: Double
    var color: Color

    /// Taller/wider plates for heavier weight, roughly matching real
    /// commercial plate proportions (bumper-plate-style uniform diameter
    /// isn't universal, but relative sizing communicates "big vs small"
    /// plate at a glance, which is the point here).
    private var height: CGFloat {
        switch weightKg {
        case 25: return 140
        case 20: return 120
        case 15: return 105
        case 10: return 90
        case 5: return 70
        case 2.5: return 55
        default: return 45
        }
    }
    private var width: CGFloat {
        weightKg >= 10 ? 18 : 12
    }

    var body: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(weightKg >= 10 ? 0.85 : 0.5))
                .frame(width: width, height: height)
            Text(weightKg.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(weightKg))" : String(format: "%.1f", weightKg))
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Pulse.textTertiary)
        }
    }
}
