import SwiftUI
import SwiftData

struct TrophyCaseCard: View {

    @Query(sort: \Achievement.earnedAt, order: .reverse)
    private var allAchievements: [Achievement]

    private var achievements: [Achievement] {
        allAchievements.filter { $0.profileId == ActiveProfile.id }
    }

    @State private var showAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(Color(hex: "F59E0B"))
                Text("Achievements")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(achievements.count)/\(AchievementEngine.allBadges.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(Capsule())
            }

            if achievements.isEmpty {
                Text("Complete sessions, hit targets, and stay consistent to earn badges.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                let display = showAll ? achievements : Array(achievements.prefix(6))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 10)], spacing: 12) {
                    ForEach(display) { badge in
                        BadgeCell(badge: badge)
                    }
                }

                if achievements.count > 6 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showAll.toggle() }
                    } label: {
                        Text(showAll ? "Show less" : "See all \(achievements.count) badges")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color(hex: "2563EB"))
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            // Show next locked badge as motivation
            if let next = nextUnearned {
                HStack(spacing: 8) {
                    Image(systemName: next.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Next: \(next.title)")
                            .font(.caption2.weight(.semibold))
                        Text(next.subtitle)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .payaCard(padding: 14)
    }

    private var nextUnearned: AchievementEngine.Badge? {
        let earnedKeys = Set(achievements.map(\.key))
        return AchievementEngine.allBadges.first { !earnedKeys.contains($0.key) }
    }
}

private struct BadgeCell: View {
    let badge: Achievement

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color(hex: badge.colorHex).opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: badge.icon)
                    .font(.title3)
                    .foregroundColor(Color(hex: badge.colorHex))
            }
            Text(badge.title)
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
                .foregroundColor(.primary)
            Text(badge.earnedAt.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 7))
                .foregroundColor(.secondary)
        }
    }
}
