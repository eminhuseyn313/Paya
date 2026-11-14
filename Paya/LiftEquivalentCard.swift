import SwiftUI

// MARK: - Lift Equivalent
//
// End-of-session motivation: translate the session's total volume (sets ×
// reps × kg, already dual-dumbbell-corrected by TrainViewModel) into
// something tangible — "you lifted 1.4 elephants" — plus a "next up"
// teaser so there's always a concrete number to chase.
//
// Reference weights are rounded, commonly cited averages (not measured
// specimens), which is why the card carries an "approximate" footnote.
// The ladder is deliberately dense at the low end (typical sessions are
// ~2,000–12,000 kg of volume) so most sessions land on a relatable object
// rather than always hitting the elephant.

enum LiftEquivalentEngine {

    struct Reference {
        let singular: String   // includes article: "an elephant"
        let plural: String     // "elephants"
        let emoji: String
        let weightKg: Double
    }

    struct Result {
        let reference: Reference
        let ratio: Double          // volume / reference weight, always >= 1
        let next: Reference?       // next rung up, nil at the top
    }

    /// Ascending by weight.
    static let ladder: [Reference] = [
        Reference(singular: "a Labrador", plural: "Labradors", emoji: "🐕", weightKg: 30),
        Reference(singular: "a grown adult", plural: "grown adults", emoji: "🧍", weightKg: 70),
        Reference(singular: "a lion", plural: "lions", emoji: "🦁", weightKg: 190),
        Reference(singular: "a motorcycle", plural: "motorcycles", emoji: "🏍️", weightKg: 250),
        Reference(singular: "a grand piano", plural: "grand pianos", emoji: "🎹", weightKg: 450),
        Reference(singular: "a cow", plural: "cows", emoji: "🐄", weightKg: 700),
        Reference(singular: "a small car", plural: "small cars", emoji: "🚗", weightKg: 1_200),
        Reference(singular: "a hippo", plural: "hippos", emoji: "🦛", weightKg: 1_500),
        Reference(singular: "a white rhino", plural: "white rhinos", emoji: "🦏", weightKg: 2_300),
        Reference(singular: "an elephant", plural: "elephants", emoji: "🐘", weightKg: 6_000),
        Reference(singular: "a T. rex", plural: "T. rexes", emoji: "🦖", weightKg: 8_000),
        Reference(singular: "a school bus", plural: "school buses", emoji: "🚌", weightKg: 11_000),
        Reference(singular: "a humpback whale", plural: "humpback whales", emoji: "🐋", weightKg: 30_000),
        Reference(singular: "an airliner", plural: "airliners", emoji: "✈️", weightKg: 41_000),
    ]

    /// Largest object that fits inside the session volume. nil under the
    /// smallest rung (30 kg) — a near-empty session isn't worth a joke.
    static func equivalent(forVolumeKg volume: Double) -> Result? {
        guard let index = ladder.lastIndex(where: { $0.weightKg <= volume }) else { return nil }
        let ref = ladder[index]
        let next = index + 1 < ladder.count ? ladder[index + 1] : nil
        return Result(reference: ref, ratio: volume / ref.weightKg, next: next)
    }
}

struct LiftEquivalentCard: View {
    let volumeKg: Double
    let prefersLbs: Bool

    @State private var appeared = false

    private var result: LiftEquivalentEngine.Result? {
        LiftEquivalentEngine.equivalent(forVolumeKg: volumeKg)
    }

    private func headline(_ r: LiftEquivalentEngine.Result) -> String {
        if r.ratio < 1.25 { return "You lifted \(r.reference.singular)" }
        let count = r.ratio >= 10 ? String(format: "%.0f", r.ratio) : String(format: "%.1f", r.ratio)
        return "You lifted \(count) \(r.reference.plural)"
    }

    private func weightText(_ kg: Double) -> String {
        let value = prefersLbs ? kg * 2.20462 : kg
        return "\(Int(value.rounded()).formatted()) \(prefersLbs ? "lbs" : "kg")"
    }

    var body: some View {
        if let r = result {
            HStack(spacing: 14) {
                Text(r.reference.emoji)
                    .font(.pulse(size: 44))
                    .scaleEffect(appeared ? 1 : 0.4)
                    .rotationEffect(.degrees(appeared ? 0 : -12))

                VStack(alignment: .leading, spacing: 3) {
                    Text(headline(r))
                        .font(.pulse(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.textPrimary)
                    Text("\(weightText(volumeKg)) moved this session")
                        .font(.pulse(size: 12, weight: .medium))
                        .foregroundColor(Pulse.textSecondary)
                    if let next = r.next {
                        Text("Next up: \(next.singular) \(next.emoji) — \(weightText(max(0, next.weightKg - volumeKg))) to go")
                            .font(.pulse(size: 11))
                            .foregroundColor(Pulse.ai)
                    } else {
                        Text("Top of the scale — nothing heavier left to compare to 🏆")
                            .font(.pulse(size: 11))
                            .foregroundColor(Pulse.ai)
                    }
                    Text("Approximate average weights, for fun")
                        .font(.pulse(size: 9))
                        .foregroundColor(Pulse.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .payaCard(padding: 14)
            .onAppear {
                if UIAccessibility.isReduceMotionEnabled {
                    appeared = true
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.5)) {
                        appeared = true
                    }
                }
            }
        }
    }
}
