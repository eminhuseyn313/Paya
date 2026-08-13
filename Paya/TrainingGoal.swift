import Foundation
import SwiftUI

// MARK: - Training Goal
// The master setting that reconfigures program bias, nutrition targets,
// cardio emphasis, and how effort is assessed. Stored on the user profile
// (profile-ready for Phase 2 multi-profile).

enum TrainingGoal: String, CaseIterable, Codable {
    case hypertrophy
    case strength
    case fatLoss
    case stayFit
    case endurance

    var displayName: String {
        switch self {
        case .hypertrophy: return "Build Muscle"
        case .strength:    return "Get Stronger"
        case .fatLoss:     return "Lose Fat"
        case .stayFit:     return "Stay Fit"
        case .endurance:   return "Endurance"
        }
    }

    var icon: String {
        switch self {
        case .hypertrophy: return "figure.strengthtraining.traditional"
        case .strength:    return "scalemass.fill"
        case .fatLoss:     return "flame.fill"
        case .stayFit:     return "heart.circle.fill"
        case .endurance:   return "figure.run"
        }
    }

    var colorHex: String {
        switch self {
        case .hypertrophy: return "2563EB"
        case .strength:    return "D97706"
        case .fatLoss:     return "DC2626"
        case .stayFit:     return "059669"
        case .endurance:   return "0891B2"
        }
    }

    var color: Color { Color(hex: colorHex) }

    var summary: String {
        switch self {
        case .hypertrophy:
            return "Maximum muscle growth. Higher training volume at RPE 7-9, calorie surplus, protein 2g/kg."
        case .strength:
            return "Heavier loads, lower reps, longer rests. Progress measured in kg on the bar."
        case .fatLoss:
            return "Calorie deficit with high protein to keep muscle. Steps and Zone-2 cardio targets."
        case .stayFit:
            return "Balanced training, maintenance nutrition, consistency over intensity."
        case .endurance:
            return "Cardio capacity focus. Zone-minutes targets, carb-forward nutrition."
        }
    }

    var effortLevers: String {
        switch self {
        case .hypertrophy: return "Volume progression · RPE 7-9 · set completion"
        case .strength:    return "Load progression · RPE 7-9 on top sets"
        case .fatLoss:     return "Deficit adherence · daily steps · weekly TRIMP"
        case .stayFit:     return "Session consistency · streaks"
        case .endurance:   return "Zone 2-3 minutes · weekly TRIMP"
        }
    }
}

// MARK: - Goal Engine
// Derives concrete targets from goal + bodyweight.

enum GoalEngine {

    struct Targets {
        let proteinG: Double
        let trainingDayCalories: Double
        let restDayCalories: Double
        let dailyStepTarget: Int?
        let weeklyZone2Minutes: Int?
    }

    /// Mifflin-St Jeor estimate — the sex-specific constant matters (+5 for
    /// men, -161 for women; using the male constant for everyone
    /// overstates BMR for women by ~166 kcal/day, which silently inflated
    /// every calorie target derived from it) — wrapped in a simple activity
    /// multiplier, then adjusted by goal.
    static func targets(
        goal: TrainingGoal,
        bodyWeightKg: Double,
        age: Int,
        heightCm: Double = 178,
        sexRaw: String = "male"
    ) -> Targets {
        let sexConstant: Double = sexRaw.lowercased() == "female" ? -161 : 5
        let bmr = 10 * bodyWeightKg + 6.25 * heightCm - 5 * Double(age) + sexConstant
        // 1.55 = the standard "moderately active" Physical Activity Level
        // multiplier (structured exercise 3-5x/week) from the Mifflin-St
        // Jeor/Harris-Benedict activity-factor table, matching this app's
        // 2-4 session/week program tiers rather than a sedentary or
        // athlete-level PAL.
        let maintenance = bmr * 1.55

        let trainingCal: Double
        let restCal: Double
        let proteinPerKg: Double
        var steps: Int? = nil
        var zone2: Int? = nil

        // Protein targets: Morton et al. 2018 (meta-analysis, BJSM) found
        // resistance-training muscle gains plateau around 1.6g/kg/day for
        // most lifters, with an upper bound near 2.2g/kg for those training
        // hardest or in a deficit (higher protein spares lean mass under
        // caloric restriction — Helms et al. 2014 physique-athlete review).
        // Surplus/deficit sizing: ~10% surplus for hypertrophy follows
        // Slater/Phillips lean-gain guidance (large surpluses add
        // disproportionate fat, not more muscle); the fat-loss deficit
        // (~15-22% below maintenance) sits inside Garthe et al. 2011's
        // slower-deficit range shown to preserve more lean mass than an
        // aggressive cut at the same total loss.
        switch goal {
        case .hypertrophy:
            trainingCal = maintenance * 1.10
            restCal = maintenance * 1.05
            proteinPerKg = 2.0
        case .strength:
            trainingCal = maintenance * 1.05
            restCal = maintenance
            proteinPerKg = 1.8
        case .fatLoss:
            trainingCal = maintenance * 0.85
            restCal = maintenance * 0.78
            proteinPerKg = 2.2
            steps = 10000
            zone2 = 90
        case .stayFit:
            trainingCal = maintenance
            restCal = maintenance
            proteinPerKg = 1.6
            steps = 8000
        case .endurance:
            trainingCal = maintenance * 1.05
            restCal = maintenance
            proteinPerKg = 1.6
            zone2 = 150
        }

        return Targets(
            proteinG: (bodyWeightKg * proteinPerKg).rounded(),
            trainingDayCalories: (trainingCal / 10).rounded() * 10,
            restDayCalories: (restCal / 10).rounded() * 10,
            dailyStepTarget: steps,
            weeklyZone2Minutes: zone2
        )
    }
}
