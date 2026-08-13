import Foundation
import SwiftData

// MARK: - TDEE Engine
// Estimates today's actual calories-out from BMR plus measured activity
// (steps + today's training sessions), as opposed to GoalEngine's fixed
// activity-multiplier estimate used for the baseline target.

enum TDEEEngine {

    struct Breakdown {
        let bmr: Double
        let stepActivityKcal: Double
        let trainingActivityKcal: Double

        var activityKcal: Double { stepActivityKcal + trainingActivityKcal }
        var total: Double { bmr + activityKcal }
    }

    /// Mifflin-St Jeor, matching GoalEngine.targets' baseline formula —
    /// including the sex-specific constant (+5 male / -161 female); using
    /// the male constant unconditionally overstated BMR for women by
    /// ~166 kcal/day.
    static func bmr(bodyWeightKg: Double, age: Int, heightCm: Double = 178, sexRaw: String = "male") -> Double {
        let sexConstant: Double = sexRaw.lowercased() == "female" ? -161 : 5
        return 10 * bodyWeightKg + 6.25 * heightCm - 5 * Double(age) + sexConstant
    }

    /// Rough NEAT estimate scaled by bodyweight (~45 kcal per 1,000 steps at 90kg).
    static func stepActivityKcal(steps: Int, bodyWeightKg: Double) -> Double {
        Double(steps) * bodyWeightKg * 0.0005
    }

    /// Per-session energy expenditure from heart rate — Keytel et al.
    /// (2005), "Prediction of energy expenditure from heart rate monitoring
    /// during submaximal exercise" (J Sports Sci), validated against
    /// indirect calorimetry. This replaces a flat "TRIMP × 0.5" heuristic:
    /// TRIMP (Banister) is a training-load unit, not a calorie unit, and has
    /// no established kcal conversion factor — deriving energy expenditure
    /// from actual heart rate, weight, age, and sex is the real formula.
    static func sessionActivityKcal(avgHR: Int, durationMinutes: Int, bodyWeightKg: Double, age: Int, sexRaw: String) -> Double {
        guard avgHR > 0, durationMinutes > 0 else { return 0 }
        let hr = Double(avgHR)
        let kcalPerMin: Double
        if sexRaw.lowercased() == "female" {
            kcalPerMin = (-20.4022 + 0.4472 * hr - 0.1263 * bodyWeightKg + 0.074 * Double(age)) / 4.184
        } else {
            kcalPerMin = (-55.0969 + 0.6309 * hr + 0.1988 * bodyWeightKg + 0.2017 * Double(age)) / 4.184
        }
        return max(0, kcalPerMin) * Double(durationMinutes)
    }

    /// Degraded fallback for sessions with no heart-rate data at all (no
    /// wearable connected) — TRIMP is the only signal available then, so we
    /// keep the old heuristic here, clearly labeled as a fallback rather
    /// than presenting it as equivalent to the HR-derived estimate above.
    private static func trimpFallbackKcal(trimp: Double) -> Double {
        trimp * 0.5
    }

    static func compute(
        bodyWeightKg: Double,
        age: Int,
        heightCm: Double = 178,
        sexRaw: String = "male",
        steps: Int,
        todayTrainingKcal: Double
    ) -> Breakdown {
        Breakdown(
            bmr: bmr(bodyWeightKg: bodyWeightKg, age: age, heightCm: heightCm, sexRaw: sexRaw),
            stepActivityKcal: stepActivityKcal(steps: steps, bodyWeightKg: bodyWeightKg),
            trainingActivityKcal: todayTrainingKcal
        )
    }

    /// Sums today's completed sessions' energy expenditure — HR-derived
    /// (Keytel) per session when heart-rate data exists, falling back to the
    /// TRIMP heuristic only for sessions with none.
    @MainActor
    static func todayTrainingKcal(bodyWeightKg: Double, age: Int, sexRaw: String, context: ModelContext) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.profileId == pid },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let sessions = (try? context.fetch(descriptor)) ?? []
        return sessions
            .filter { $0.isCompleted && calendar.isDate($0.date, inSameDayAs: today) }
            .reduce(0.0) { total, session in
                if let avgHR = session.sessionAvgHR, avgHR > 0, session.durationMinutes > 0 {
                    return total + sessionActivityKcal(
                        avgHR: avgHR, durationMinutes: session.durationMinutes,
                        bodyWeightKg: bodyWeightKg, age: age, sexRaw: sexRaw
                    )
                }
                return total + trimpFallbackKcal(trimp: session.sessionTrimpScore ?? 0)
            }
    }

    /// Convenience: computes today's breakdown given a profile and model context.
    @MainActor
    static func computeToday(profile: UserProfile, steps: Int, context: ModelContext) -> Breakdown {
        compute(
            bodyWeightKg: profile.currentWeightKg,
            age: profile.age,
            heightCm: profile.heightCm,
            sexRaw: profile.sexRaw,
            steps: steps,
            todayTrainingKcal: todayTrainingKcal(
                bodyWeightKg: profile.currentWeightKg, age: profile.age, sexRaw: profile.sexRaw, context: context
            )
        )
    }
}
