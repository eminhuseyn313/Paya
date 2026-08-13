import SwiftUI

struct MuscleBalanceCard: View {

    var sessions: [TrainingSession]

    @State private var pairs: [BalancePair] = []

    var body: some View {
        Group {
            if !pairs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "scalemass.fill")
                            .foregroundColor(Color(hex: "0891B2"))
                        Text("Muscle Balance")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if let worstRatio = pairs.map(\.ratio).min(), worstRatio < 0.7 {
                            Text("Imbalance")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color(hex: "DC2626"))
                                .clipShape(Capsule())
                        }
                    }

                    ForEach(pairs) { pair in
                        VStack(spacing: 4) {
                            HStack {
                                Text(pair.pushGroup)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(pair.pullGroup)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.primary)
                            }

                            GeometryReader { geo in
                                let midX = geo.size.width / 2
                                let pushWidth = midX * CGFloat(min(1, pair.pushNorm))
                                let pullWidth = midX * CGFloat(min(1, pair.pullNorm))

                                ZStack(alignment: .center) {
                                    HStack(spacing: 0) {
                                        Spacer()
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color(hex: "2563EB"))
                                            .frame(width: pushWidth, height: 8)
                                    }
                                    .frame(width: midX - 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    HStack(spacing: 0) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color(hex: "059669"))
                                            .frame(width: pullWidth, height: 8)
                                        Spacer()
                                    }
                                    .frame(width: midX - 2)
                                    .frame(maxWidth: .infinity, alignment: .trailing)

                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.3))
                                        .frame(width: 1, height: 14)
                                }
                            }
                            .frame(height: 14)

                            HStack {
                                Text(String(format: "%.0f sets", pair.pushSets))
                                    .font(.system(size: 9))
                                    .foregroundColor(Color(hex: "2563EB"))
                                Spacer()
                                Text(ratioLabel(pair.ratio))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(ratioColor(pair.ratio))
                                Spacer()
                                Text(String(format: "%.0f sets", pair.pullSets))
                                    .font(.system(size: 9))
                                    .foregroundColor(Color(hex: "059669"))
                            }
                        }
                    }

                    Text("Push:Pull set ratio over last 4 weeks. Aim for 0.8–1.2 to prevent imbalances.")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func ratioLabel(_ ratio: Double) -> String {
        if ratio >= 0.8 && ratio <= 1.2 { return "Balanced" }
        if ratio < 0.8 { return "Push heavy" }
        return "Pull heavy"
    }

    private func ratioColor(_ ratio: Double) -> Color {
        if ratio >= 0.8 && ratio <= 1.2 { return Color(hex: "059669") }
        return Color(hex: "F59E0B")
    }

    private func compute() {
        let calendar = Calendar.current
        let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: Date())!
        let recent = sessions.filter { $0.isCompleted && $0.date >= fourWeeksAgo }

        let pushGroups = Set(["Chest", "Shoulders", "Triceps", "Side Delts", "Front Delts"])
        let pullGroups = Set(["Back", "Biceps", "Rear Delts", "Lats"])
        let legPush = Set(["Quads", "Glutes"])
        let legPull = Set(["Hamstrings", "Calves"])

        var pushSets: Double = 0
        var pullSets: Double = 0
        var legPushSets: Double = 0
        var legPullSets: Double = 0

        for session in recent {
            for log in session.exercises {
                let completed = Double(log.sets.filter(\.isCompleted).count)
                let group = log.muscleGroup
                if pushGroups.contains(group) { pushSets += completed }
                else if pullGroups.contains(group) { pullSets += completed }
                else if legPush.contains(group) { legPushSets += completed }
                else if legPull.contains(group) { legPullSets += completed }
            }
        }

        var result: [BalancePair] = []
        let maxSets = max(pushSets, pullSets, legPushSets, legPullSets, 1)

        if pushSets > 0 || pullSets > 0 {
            result.append(BalancePair(
                pushGroup: "Push (upper)",
                pullGroup: "Pull (upper)",
                pushSets: pushSets,
                pullSets: pullSets,
                pushNorm: pushSets / maxSets,
                pullNorm: pullSets / maxSets,
                ratio: pullSets > 0 ? pushSets / pullSets : 0
            ))
        }

        if legPushSets > 0 || legPullSets > 0 {
            result.append(BalancePair(
                pushGroup: "Quads/Glutes",
                pullGroup: "Hams/Calves",
                pushSets: legPushSets,
                pullSets: legPullSets,
                pushNorm: legPushSets / maxSets,
                pullNorm: legPullSets / maxSets,
                ratio: legPullSets > 0 ? legPushSets / legPullSets : 0
            ))
        }

        pairs = result
    }
}

private struct BalancePair: Identifiable {
    let pushGroup: String
    let pullGroup: String
    let pushSets: Double
    let pullSets: Double
    let pushNorm: Double
    let pullNorm: Double
    let ratio: Double
    var id: String { pushGroup }
}
