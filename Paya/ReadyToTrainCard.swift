import SwiftUI

struct ReadyToTrainCard: View {

    let readinessScore: Int?
    let freshMuscles: [String]
    let sorenessLevel: Int?

    private var readinessColor: Color {
        guard let score = readinessScore else { return .secondary }
        if score >= 70 { return Pulse.positive }
        if score >= 40 { return Pulse.nutrition }
        return Pulse.critical
    }

    private var readinessLabel: String {
        guard let score = readinessScore else { return "Unknown" }
        if score >= 80 { return "Primed" }
        if score >= 60 { return "Good to go" }
        if score >= 40 { return "Moderate" }
        return "Take it easy"
    }

    private var emoji: String {
        guard let score = readinessScore else { return "figure.walk" }
        if score >= 80 { return "bolt.fill" }
        if score >= 60 { return "flame.fill" }
        if score >= 40 { return "figure.walk" }
        return "moon.zzz.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: emoji)
                    .foregroundColor(readinessColor)
                Text("Training Readiness")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let score = readinessScore {
                    HStack(spacing: 4) {
                        Text("\(score)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(readinessColor)
                        Text("/100")
                            .font(.system(size: 11))
                            .foregroundColor(Pulse.textTertiary)
                    }
                }
            }

            if readinessScore != nil {
                HStack(spacing: 8) {
                    Text(readinessLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(readinessColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(readinessColor.opacity(0.1))
                        .clipShape(Capsule())

                    if let soreness = sorenessLevel, soreness > 0 {
                        HStack(spacing: 3) {
                            ForEach(0..<3, id: \.self) { i in
                                Circle()
                                    .fill(i < soreness ? Pulse.nutrition : Color.secondary.opacity(0.2))
                                    .frame(width: 6, height: 6)
                            }
                            Text("soreness")
                                .font(.system(size: 9))
                                .foregroundColor(Pulse.textTertiary)
                        }
                    }
                }
            }

            if !freshMuscles.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FULLY RECOVERED")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Pulse.textTertiary)
                    HStack(spacing: 6) {
                        ForEach(freshMuscles.prefix(5), id: \.self) { muscle in
                            Text(muscle)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Pulse.positive)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Pulse.positive.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        if freshMuscles.count > 5 {
                            Text("+\(freshMuscles.count - 5)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Pulse.textTertiary)
                        }
                    }
                }
            }
        }
        .payaCard(padding: 14)
    }
}
