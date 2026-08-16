import SwiftUI
import SwiftData

// MARK: - Milestone Celebration Card
// Surfaces recent achievements with celebration UI and shareable
// summary cards. Builds on the existing Achievement model and
// AchievementEngine — this card adds the delight layer that was
// missing: confetti-style visuals and a "share your win" flow.
//
// Research grounding: Hamari et al. (2014) meta-analysis found
// gamification improves engagement when it includes achievement
// recognition AND social proof. Variable reward timing (not every
// session) increases dopamine response (Schultz 1997).
//
// The card shows achievements earned in the last 7 days with
// celebration styling, plus a share button that generates a
// rendered summary card for iMessage/Instagram Stories.

struct MilestoneCelebrationCard: View {

    @Environment(\.modelContext) private var modelContext

    @State private var recentAchievements: [Achievement] = []
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?

    var body: some View {
        Group {
            if !recentAchievements.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(Pulse.nutrition)
                        Text("Recent wins")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(Pulse.textPrimary)
                        Spacer()
                        Text("\(recentAchievements.count) new")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Pulse.nutrition)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Pulse.nutrition.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    ForEach(recentAchievements) { achievement in
                        achievementRow(achievement)
                    }

                    // Share summary button
                    Button {
                        shareImage = renderShareCard()
                        showShareSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11, weight: .bold))
                            Text("Share your wins")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(Pulse.nutrition)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Pulse.nutrition.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .payaCard(padding: 14)
                .sheet(isPresented: $showShareSheet) {
                    if let image = shareImage {
                        ShareSheet(items: [image])
                    }
                }
            }
        }
        .onAppear { loadRecent() }
    }

    private func achievementRow(_ achievement: Achievement) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(hex: achievement.colorHex).opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: achievement.icon)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: achievement.colorHex))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(achievement.title)
                        .font(.system(size: 12, weight: .bold))
                    if isNew(achievement) {
                        Text("NEW")
                            .font(.system(size: 7, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(hex: "DC2626"))
                            .clipShape(Capsule())
                    }
                }
                Text(achievement.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Pulse.textTertiary)
            }

            Spacer(minLength: 0)

            Text(daysSince(achievement.earnedAt))
                .font(.system(size: 9))
                .foregroundColor(Pulse.textTertiary)
        }
        .padding(8)
        .background(Color(hex: achievement.colorHex).opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func isNew(_ achievement: Achievement) -> Bool {
        Calendar.current.dateComponents([.day], from: achievement.earnedAt, to: Date()).day ?? 99 <= 1
    }

    private func daysSince(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return "\(days)d ago"
    }

    private func loadRecent() {
        let pid = ActiveProfile.id
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let descriptor = FetchDescriptor<Achievement>(
            predicate: #Predicate<Achievement> {
                $0.profileId == pid && $0.earnedAt >= sevenDaysAgo
            },
            sortBy: [SortDescriptor(\.earnedAt, order: .reverse)]
        )
        recentAchievements = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Render Share Card

    @MainActor
    private func renderShareCard() -> UIImage {
        let width: CGFloat = 400

        let view = VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paya")
                        .font(.system(size: 24, weight: .black))
                    Text("\(recentAchievements.count) achievements unlocked")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "trophy.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Color(hex: "B45309"))
            }
            .padding(20)

            // Achievement list
            VStack(spacing: 8) {
                ForEach(recentAchievements) { a in
                    HStack(spacing: 10) {
                        Image(systemName: a.icon)
                            .font(.system(size: 16))
                            .foregroundColor(Color(hex: a.colorHex))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(a.title)
                                .font(.system(size: 13, weight: .bold))
                            Text(a.subtitle)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(width: width)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        return renderer.uiImage ?? UIImage()
    }
}

// MARK: - UIKit Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
