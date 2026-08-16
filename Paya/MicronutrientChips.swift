import SwiftUI

struct MicronutrientChips: View {
    let estimate: GeminiFoodService.Estimate
    var portionFraction: Double = 1.0

    private var chips: [(label: String, value: Double, unit: String)] {
        let f = portionFraction
        var result: [(String, Double, String)] = []
        if let v = estimate.fatG { result.append(("Fat", v * f, "g")) }
        if let v = estimate.carbsG { result.append(("Carbs", v * f, "g")) }
        if let v = estimate.fiberG { result.append(("Fiber", v * f, "g")) }
        if let v = estimate.sugarG { result.append(("Sugar", v * f, "g")) }
        if let v = estimate.magnesiumMg { result.append(("Magnesium", v * f, "mg")) }
        if let v = estimate.zincMg { result.append(("Zinc", v * f, "mg")) }
        if let v = estimate.ironMg { result.append(("Iron", v * f, "mg")) }
        if let v = estimate.calciumMg { result.append(("Calcium", v * f, "mg")) }
        if let v = estimate.vitaminDMcg { result.append(("Vitamin D", v * f, "mcg")) }
        if let v = estimate.potassiumMg { result.append(("Potassium", v * f, "mg")) }
        if let v = estimate.vitaminCMg { result.append(("Vitamin C", v * f, "mg")) }
        if let v = estimate.sodiumMg { result.append(("Sodium", v * f, "mg")) }
        return result
    }

    var body: some View {
        if !chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips, id: \.label) { chip in
                        VStack(spacing: 2) {
                            Text(String(format: chip.value < 10 ? "%.1f" : "%.0f", chip.value))
                                .font(.caption.weight(.bold))
                            Text("\(chip.label) (\(chip.unit))")
                                .font(.system(size: 9))
                                .foregroundColor(Pulse.textTertiary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Pulse.surfaceElevatedFallback)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
}
