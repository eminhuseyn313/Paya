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
                    .foregroundColor(Pulse.nutrition)
                Text("Achievements")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Pulse.textPrimary)
                Spacer()
                Text("\(achievements.count)/\(AchievementEngine.allBadges.count)")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(Pulse.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Pulse.surfaceElevatedFallback)
                    .clipShape(Capsule())
            }

            if achievements.isEmpty {
                Text("Complete sessions, hit targets, and stay consistent to earn badges.")
                    .font(.caption)
                    .foregroundColor(Pulse.textSecondary)
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
                            .foregroundColor(Pulse.hydration)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PulsePress())
                }
            }

            // Show next locked badge as motivation
            if let next = nextUnearned {
                HStack(spacing: 8) {
                    Image(systemName: next.icon)
                        .font(.caption)
                        .foregroundColor(Pulse.textTertiary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Next: \(next.title)")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(Pulse.textPrimary)
                        Text(next.subtitle)
                            .font(.caption2)
                            .foregroundColor(Pulse.textTertiary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(Pulse.surfaceElevatedFallback)
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
                .foregroundColor(Pulse.textPrimary)
            Text(badge.earnedAt.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 7))
                .foregroundColor(Pulse.textTertiary)
        }
    }
}
