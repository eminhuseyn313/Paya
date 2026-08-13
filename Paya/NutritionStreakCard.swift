import SwiftUI
import SwiftData

// MARK: - Nutrition Streak Card
// Gamified protein/calorie adherence tracking with streaks and hit rates.
// Shows last 14 days as a dot grid — green for hit, red for miss, gray
// for unlogged. Whoop has recovery streaks; this is nutrition streaks.

struct NutritionStreakCard: View {

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @State private var proteinStreak: Int = 0
    @State private var calorieStreak: Int = 0
    @State private var dayDots: [DayDot] = []
    @State private var proteinHitRate: Int = 0
    @State private var calorieHitRate: Int = 0

    var body: some View {
        Group {
            if !dayDots.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "flame.circle.fill")
                            .foregroundColor(Color(hex: "059669"))
                        Text("Nutrition Streaks")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        streakStat(
                            value: "\(proteinStreak)",
                            label: "Protein streak",
                            sublabel: "days",
                            color: Color(hex: "2563EB"),
                            icon: "p.circle.fill"
                        )
                        streakStat(
                            value: "\(calorieStreak)",
                            label: "Calorie streak",
                            sublabel: "days",
                            color: Color(hex: "F59E0B"),
                            icon: "c.circle.fill"
                        )
                        streakStat(
                            value: "\(proteinHitRate)%",
                            label: "Protein hit",
                            sublabel: "14d rate",
                            color: Color(hex: "059669"),
                            icon: "target"
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last 14 days")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 3) {
                            ForEach(dayDots) { dot in
                                VStack(spacing: 2) {
                                    // Protein dot
                                    Circle()
                                        .fill(dot.proteinColor)
                                        .frame(width: 14, height: 14)
                                    // Calorie dot
                                    Circle()
                                        .fill(dot.calorieColor)
                                        .frame(width: 14, height: 14)
                                    Text(dot.dayLabel)
                                        .font(.system(size: 6))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            HStack(spacing: 3) {
                                Circle().fill(Color(hex: "2563EB")).frame(width: 5, height: 5)
                                Text("Protein").font(.system(size: 7)).foregroundColor(.secondary)
                            }
                            HStack(spacing: 3) {
                                Circle().fill(Color(hex: "F59E0B")).frame(width: 5, height: 5)
                                Text("Calories").font(.system(size: 7)).foregroundColor(.secondary)
                            }
                            HStack(spacing: 3) {
                                Circle().fill(Color(hex: "059669")).frame(width: 5, height: 5)
                                Text("Hit").font(.system(size: 7)).foregroundColor(.secondary)
                            }
                            HStack(spacing: 3) {
                                Circle().fill(Color(hex: "DC2626").opacity(0.4)).frame(width: 5, height: 5)
                                Text("Miss").font(.system(size: 7)).foregroundColor(.secondary)
                            }
                        }
                    }

                    Text("Green = within 90% of target. Keep the streak alive — consistency matters more than perfection.")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .payaCard(padding: 14)
            }
        }
        .onAppear { compute() }
    }

    private func streakStat(value: String, label: String, sublabel: String, color: Color, icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.secondary)
            Text(sublabel)
                .font(.system(size: 7))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }

    private func compute() {
        let calendar = Calendar.current
        let pid = ActiveProfile.id
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: Date())!

        let descriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == pid && $0.date >= fourteenDaysAgo }
        )
        let logs = (try? modelContext.fetch(descriptor)) ?? []
        guard !logs.isEmpty else { return }

        let logsByDay: [Date: NutritionLog] = Dictionary(
            logs.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { a, _ in a }
        )

        var dots: [DayDot] = []
        var pStreak = 0
        var cStreak = 0
        var pStreakCounting = true
        var cStreakCounting = true
        var pHits = 0
        var cHits = 0
        var logged = 0

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "E"

        for dayOffset in (0..<14).reversed() {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: Date()))!
            let label = String(dayFormatter.string(from: day).prefix(1))

            if let log = logsByDay[day] {
                logged += 1
                let proteinHit = log.totalProtein >= log.proteinTarget * 0.9
                let calorieHit = log.totalCalories >= log.calorieTarget * 0.9 && log.totalCalories <= log.calorieTarget * 1.1

                if proteinHit { pHits += 1 }
                if calorieHit { cHits += 1 }

                dots.append(DayDot(
                    dayLabel: label,
                    proteinColor: proteinHit ? Color(hex: "059669") : Color(hex: "DC2626").opacity(0.4),
                    calorieColor: calorieHit ? Color(hex: "059669") : Color(hex: "DC2626").opacity(0.4)
                ))

                // Streak counting (from most recent day backward)
                if dayOffset == 0 || pStreakCounting {
                    if proteinHit { pStreak += 1 } else { pStreakCounting = false }
                }
                if dayOffset == 0 || cStreakCounting {
                    if calorieHit { cStreak += 1 } else { cStreakCounting = false }
                }
            } else {
                dots.append(DayDot(
                    dayLabel: label,
                    proteinColor: Color(.tertiarySystemBackground),
                    calorieColor: Color(.tertiarySystemBackground)
                ))
                pStreakCounting = false
                cStreakCounting = false
            }
        }

        dayDots = dots
        proteinStreak = pStreak
        calorieStreak = cStreak
        proteinHitRate = logged > 0 ? Int(Double(pHits) / Double(logged) * 100) : 0
        calorieHitRate = logged > 0 ? Int(Double(cHits) / Double(logged) * 100) : 0
    }
}

private struct DayDot: Identifiable {
    let id = UUID()
    let dayLabel: String
    let proteinColor: Color
    let calorieColor: Color
}
