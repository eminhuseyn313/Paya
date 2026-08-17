import SwiftUI

// MARK: - Flare Risk Detail
//
// FlareDetectionEngine has always computed a real list of contributing
// factors (elevated resting HR, suppressed HRV, joint pain, poor sleep,
// pattern match to prior flares) — this data existed but was never shown
// anywhere; the Dashboard card only ever displayed the risk level and one
// generic recommendation sentence, with no way to see the actual reasoning
// behind it. This is the explanation the user has to tap to get to.

struct FlareRiskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let assessment: FlareRiskAssessment

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(assessment.level.color.opacity(0.15))
                                .frame(width: 56, height: 56)
                            Image(systemName: assessment.level.icon)
                                .font(.title2)
                                .foregroundColor(assessment.level.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Flare Risk · \(assessment.level.displayName)")
                                .font(.headline)
                            Text("Score \(assessment.score)/100 — \(assessment.confidence.displayName)")
                                .font(.caption)
                                .foregroundColor(Pulse.textTertiary)
                        }
                        Spacer()
                    }

                    Text(assessment.recommendation)
                        .font(.subheadline.weight(.semibold))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(assessment.level.color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    if assessment.factors.isEmpty {
                        Text("Nothing stands out today — this score reflects normal ranges across the board.")
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                    } else {
                        Text("WHY")
                            .font(.caption.weight(.bold))
                            .foregroundColor(Pulse.textTertiary)

                        VStack(spacing: 10) {
                            ForEach(assessment.factors) { factor in
                                HStack(spacing: 12) {
                                    Image(systemName: factor.icon)
                                        .font(.subheadline)
                                        .foregroundColor(severityColor(factor.severity))
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(factor.name)
                                            .font(.subheadline.weight(.semibold))
                                        Text(factor.observation)
                                            .font(.caption)
                                            .foregroundColor(Pulse.textTertiary)
                                    }
                                    Spacer()
                                }
                                .payaCard(padding: 12)
                            }
                        }
                    }

                    Text("\(assessment.confidence.subtitle) — this is pattern-spotting from your own data, not a diagnosis.")
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                }
                .padding(16)
            }
            .navigationTitle("Flare Risk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func severityColor(_ severity: Int) -> Color {
        switch severity {
        case 0...1: return Pulse.warning
        case 2: return Color(hex: "EA580C")
        default: return Pulse.critical
        }
    }
}
