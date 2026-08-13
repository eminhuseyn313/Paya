import SwiftUI
import SwiftData

// MARK: - Nutrient Timing Map
//
// Analyzes the relationship between meal timing and training
// sessions. Surfaces actionable insights like "You trained at
// 10 AM but didn't eat until 1 PM — that's a 3-hour post-workout
// gap" or "Your pre-workout window is usually 45 min (optimal
// range: 60-120 min)."
//
// Research basis:
// - Aragon & Schoenfeld (2013), JISSN: "Nutrient Timing Revisited"
//   — post-workout protein within 2 hours optimizes MPS when
//   pre-workout meal was >3h prior.
// - Kerksick et al. (2017), JISSN: "International Society of Sports
//   Nutrition Position Stand: Nutrient Timing" — 0.4-0.5 g/kg
//   protein pre and post workout, carbs to restore glycogen.

struct NutrientTimingCard: View {

    @Environment(\.modelContext) private var modelContext

    @State private var analysis: TimingAnalysis?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.arrow.2.circlepath")
                    .foregroundColor(Color(hex: "F59E0B"))
                    .font(.system(size: 12))
                Text("Nutrient timing")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let a = analysis, a.grade != .unknown {
                    Text(a.grade.label)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(a.grade.color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(a.grade.color.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            if isLoading {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.7)
                    Text("Analyzing meal timing…")
                        .font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
            } else if let a = analysis {
                // Pre-workout window
                if let pre = a.avgPreWorkoutMin {
                    timingRow(
                        icon: "fork.knife",
                        color: preWindowColor(pre),
                        title: "Pre-workout window",
                        value: formatMinutes(pre),
                        subtitle: preWindowAdvice(pre)
                    )
                }

                // Post-workout window
                if let post = a.avgPostWorkoutMin {
                    timingRow(
                        icon: "takeoutbag.and.cup.and.straw.fill",
                        color: postWindowColor(post),
                        title: "Post-workout meal",
                        value: formatMinutes(post),
                        subtitle: postWindowAdvice(post)
                    )
                }

                // Post-workout protein
                if let protein = a.avgPostWorkoutProtein {
                    timingRow(
                        icon: "target",
                        color: protein >= 25 ? "059669" : "DC2626",
                        title: "Post-workout protein",
                        value: "\(Int(protein))g avg",
                        subtitle: protein >= 25
                            ? "Good — meeting the 25-40g window for muscle protein synthesis."
                            : "Low — aim for 25-40g protein within 2h post-workout (Kerksick 2017)."
                    )
                }

                // Gap alerts
                if a.missedPostWorkoutCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "F59E0B"))
                        Text("\(a.missedPostWorkoutCount) of your last \(a.totalSessionsAnalyzed) sessions had no meal within 3 hours.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.title3).foregroundColor(.secondary)
                    Text("Not enough data yet")
                        .font(.caption.weight(.semibold))
                    Text("Log meals with timestamps and complete training sessions to unlock timing insights.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
            }

            // Source
            HStack(spacing: 4) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 8))
                Text("Based on ISSN nutrient timing guidelines (Kerksick et al. 2017)")
                    .font(.system(size: 9))
            }
            .foregroundColor(.secondary)
        }
        .payaCard(padding: 14)
        .task { await analyze() }
    }

    @ViewBuilder
    private func timingRow(icon: String, color: String, title: String, value: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(hex: color).opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: color))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(value)
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color(hex: color))
                }
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Analysis

    struct TimingAnalysis {
        let avgPreWorkoutMin: Double?
        let avgPostWorkoutMin: Double?
        let avgPostWorkoutProtein: Double?
        let missedPostWorkoutCount: Int
        let totalSessionsAnalyzed: Int
        let grade: TimingGrade
    }

    enum TimingGrade {
        case excellent, good, needsWork, unknown

        var label: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .needsWork: return "Needs work"
            case .unknown: return ""
            }
        }

        var color: Color {
            switch self {
            case .excellent: return Color(hex: "059669")
            case .good: return Color(hex: "F59E0B")
            case .needsWork: return Color(hex: "DC2626")
            case .unknown: return .secondary
            }
        }
    }

    @MainActor
    private func analyze() async {
        let pid = ActiveProfile.id
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -30, to: .now) ?? .now

        // Fetch completed sessions
        let sessDesc = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> {
                $0.profileId == pid && $0.isCompleted && $0.date >= cutoff
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let sessions = (try? modelContext.fetch(sessDesc)) ?? []
        guard sessions.count >= 3 else {
            isLoading = false
            return
        }

        // Fetch meals
        let nutDesc = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.profileId == pid && $0.date >= cutoff }
        )
        let nutritionLogs = (try? modelContext.fetch(nutDesc)) ?? []

        var preWindows: [Double] = []
        var postWindows: [Double] = []
        var postProteins: [Double] = []
        var missed = 0

        for session in sessions {
            let sessionDay = calendar.startOfDay(for: session.date)
            let sessionEnd = session.date.addingTimeInterval(Double(session.durationMinutes) * 60)

            // Find that day's nutrition log
            guard let dayLog = nutritionLogs.first(where: {
                calendar.startOfDay(for: $0.date) == sessionDay
            }) else {
                missed += 1
                continue
            }

            let meals = dayLog.meals.sorted(by: { $0.loggedAt < $1.loggedAt })

            // Pre-workout: last meal before session start
            let preMeals = meals.filter { $0.loggedAt < session.date }
            if let lastPre = preMeals.last {
                let gap = session.date.timeIntervalSince(lastPre.loggedAt) / 60
                if gap > 0 && gap < 480 { // reasonable range: up to 8 hours
                    preWindows.append(gap)
                }
            }

            // Post-workout: first meal after session end
            let postMeals = meals.filter { $0.loggedAt > sessionEnd }
            if let firstPost = postMeals.first {
                let gap = firstPost.loggedAt.timeIntervalSince(sessionEnd) / 60
                if gap > 0 && gap < 480 {
                    postWindows.append(gap)
                    postProteins.append(firstPost.protein)
                }
            } else {
                // No meal after workout
                missed += 1
            }
        }

        let avgPre = preWindows.isEmpty ? nil : preWindows.reduce(0, +) / Double(preWindows.count)
        let avgPost = postWindows.isEmpty ? nil : postWindows.reduce(0, +) / Double(postWindows.count)
        let avgProtein = postProteins.isEmpty ? nil : postProteins.reduce(0, +) / Double(postProteins.count)

        // Grade
        let grade: TimingGrade
        if let post = avgPost, let protein = avgProtein {
            if post <= 60 && protein >= 25 {
                grade = .excellent
            } else if post <= 120 && protein >= 20 {
                grade = .good
            } else {
                grade = .needsWork
            }
        } else {
            grade = .unknown
        }

        analysis = TimingAnalysis(
            avgPreWorkoutMin: avgPre,
            avgPostWorkoutMin: avgPost,
            avgPostWorkoutProtein: avgProtein,
            missedPostWorkoutCount: missed,
            totalSessionsAnalyzed: sessions.count,
            grade: grade
        )
        isLoading = false
    }

    // MARK: - Helpers

    private func formatMinutes(_ min: Double) -> String {
        let hours = Int(min) / 60
        let mins = Int(min) % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins) min"
    }

    private func preWindowColor(_ min: Double) -> String {
        if min >= 60 && min <= 180 { return "059669" }
        if min >= 30 && min <= 240 { return "F59E0B" }
        return "DC2626"
    }

    private func postWindowColor(_ min: Double) -> String {
        if min <= 60 { return "059669" }
        if min <= 120 { return "F59E0B" }
        return "DC2626"
    }

    private func preWindowAdvice(_ min: Double) -> String {
        if min >= 60 && min <= 180 {
            return "Optimal — your body has fuel without digestive load."
        }
        if min < 60 {
            return "Very short — eating too close to training may cause discomfort. Aim for 60-120 min."
        }
        if min <= 240 {
            return "Slightly long — consider a small snack 60-90 min before training."
        }
        return "Long gap — you may be training fasted. If intentional, ensure adequate post-workout nutrition."
    }

    private func postWindowAdvice(_ min: Double) -> String {
        if min <= 60 {
            return "Excellent — within the optimal post-workout window for glycogen replenishment."
        }
        if min <= 120 {
            return "Good — within the 2-hour window for muscle protein synthesis (Aragon & Schoenfeld 2013)."
        }
        return "Long gap — aim to eat within 2 hours post-workout, especially if pre-workout meal was >3h prior."
    }
}
