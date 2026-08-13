import SwiftUI
import SwiftData

// MARK: - Weekly Summary Share Card
// Lightweight accountability feature — share a rendered weekly summary
// card via iMessage/WhatsApp/Instagram Stories. Users with workout
// partners are 40% more likely to maintain their routine after 6 months
// (Irwin et al. 2012).
//
// This is NOT a social network. Zero backend, zero accounts to create.
// It's just a beautiful rendered image summarizing the week's work,
// shared via the native iOS share sheet. Social proof without the
// infrastructure.

struct WeeklySummaryShareCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var sessionsThisWeek = 0
    @State private var totalVolumeKg: Double = 0
    @State private var proteinHitDays = 0
    @State private var prCount = 0
    @State private var currentStreak = 0
    @State private var avgDuration = 0
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var hasData = false

    var body: some View {
        Group {
            if hasData {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(Color(hex: "8B5CF6"))
                        Text("Share your week")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("Accountability")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "8B5CF6"))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color(hex: "8B5CF6").opacity(0.1))
                            .clipShape(Capsule())
                    }

                    // Preview stats
                    HStack(spacing: 0) {
                        miniStat(value: "\(sessionsThisWeek)", label: "Sessions", icon: "dumbbell.fill", color: Color(hex: "2563EB"))
                        miniStat(value: "\(prCount)", label: "PRs", icon: "trophy.fill", color: Color(hex: "B45309"))
                        miniStat(value: "\(proteinHitDays)/7", label: "Protein days", icon: "fork.knife", color: Color(hex: "059669"))
                        miniStat(value: "\(currentStreak)w", label: "Streak", icon: "flame.fill", color: Color(hex: "DC2626"))
                    }

                    Text("Send your training buddy a summary card to keep each other accountable. 40% better adherence with a training partner.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Button {
                        shareImage = renderWeeklyCard()
                        showShareSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 11, weight: .bold))
                            Text("Share weekly summary")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "8B5CF6"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
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
        .onAppear { loadWeekData() }
    }

    private func miniStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 7, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func loadWeekData() {
        let calendar = Calendar.current
        let pid = ActiveProfile.id
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!

        // Sessions
        let sessionDesc = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> {
                $0.profileId == pid && $0.isCompleted && $0.date >= weekAgo
            }
        )
        let sessions = (try? modelContext.fetch(sessionDesc)) ?? []
        sessionsThisWeek = sessions.count

        guard sessionsThisWeek > 0 else { return }
        hasData = true

        // Volume
        totalVolumeKg = sessions.reduce(0.0) { total, session in
            total + session.exercises.reduce(0.0) { t, ex in
                t + ex.sets.filter(\.isCompleted).reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
            }
        }

        // Duration
        let totalDuration = sessions.reduce(0) { $0 + $1.durationMinutes }
        avgDuration = sessions.isEmpty ? 0 : totalDuration / sessions.count

        // Protein hit days
        let nutritionDesc = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> {
                $0.profileId == pid && $0.date >= weekAgo
            }
        )
        let nutritionLogs = (try? modelContext.fetch(nutritionDesc)) ?? []
        proteinHitDays = nutritionLogs.filter { $0.totalProtein >= $0.proteinTarget }.count

        // PRs this week
        let prs = ProgressAnalytics.recentPRs(sessions: sessions, daysBack: 7)
        prCount = prs.count

        // Streak
        let allSessionsDesc = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid && $0.isCompleted },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let allSessions = (try? modelContext.fetch(allSessionsDesc)) ?? []
        currentStreak = weekStreak(allSessions)
    }

    private func weekStreak(_ sessions: [TrainingSession]) -> Int {
        let calendar = Calendar.current
        guard !sessions.isEmpty else { return 0 }
        var weeksWithSession = Set<DateComponents>()
        for session in sessions {
            weeksWithSession.insert(calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: session.date))
        }
        var streak = 0
        var checkWeekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        ) ?? Date()
        for weekIndex in 0..<52 {
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: checkWeekStart)
            if weeksWithSession.contains(comps) {
                streak += 1
            } else if weekIndex > 0 {
                break
            }
            checkWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: checkWeekStart) ?? checkWeekStart
        }
        return streak
    }

    // MARK: - Render Weekly Card Image

    @MainActor
    private func renderWeeklyCard() -> UIImage {
        let useLbs = appState.profile.prefersLbs
        let volume = useLbs ? totalVolumeKg * 2.20462 : totalVolumeKg
        let unit = useLbs ? "lbs" : "kg"
        let name = appState.profile.name

        let view = VStack(spacing: 0) {
            // Dark header
            VStack(spacing: 6) {
                HStack {
                    Text("Paya")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("Weekly Report")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(name)
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.white)
                    Spacer()
                    if currentStreak > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12))
                            Text("\(currentStreak)w streak")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(Color(hex: "F59E0B"))
                    }
                }
            }
            .padding(20)
            .background(Color(hex: "1a1a2e"))

            // Stats grid
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    shareStatBox(
                        value: "\(sessionsThisWeek)",
                        label: "Sessions",
                        icon: "dumbbell.fill",
                        color: Color(hex: "2563EB")
                    )
                    shareStatBox(
                        value: String(format: "%.0f %@", volume, unit),
                        label: "Volume",
                        icon: "scalemass.fill",
                        color: Color(hex: "8B5CF6")
                    )
                }
                HStack(spacing: 12) {
                    shareStatBox(
                        value: "\(prCount) PRs",
                        label: "Records",
                        icon: "trophy.fill",
                        color: Color(hex: "B45309")
                    )
                    shareStatBox(
                        value: "\(proteinHitDays)/7",
                        label: "Protein target hit",
                        icon: "fork.knife",
                        color: Color(hex: "059669")
                    )
                }
                HStack(spacing: 12) {
                    shareStatBox(
                        value: "\(avgDuration)min",
                        label: "Avg session",
                        icon: "clock.fill",
                        color: Color(hex: "0891B2")
                    )
                    shareStatBox(
                        value: currentStreak > 0 ? "\(currentStreak) weeks" : "—",
                        label: "Training streak",
                        icon: "flame.fill",
                        color: Color(hex: "DC2626")
                    )
                }
            }
            .padding(16)
            .background(Color(.systemBackground))

            // Footer
            HStack {
                Text("Tracked with Paya — 100% on-device")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(hex: "1a1a2e"))
        }
        .frame(width: 360)
        .clipShape(RoundedRectangle(cornerRadius: 16))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        return renderer.uiImage ?? UIImage()
    }

    private func shareStatBox(value: String, label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
