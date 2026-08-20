import Foundation
import SwiftData

// MARK: - Training Session

@Model
class TrainingSession {
    var id: UUID
    var sessionType: String       // "A", "B", "C"
    var date: Date
    var durationMinutes: Int
    var isCompleted: Bool
    var notes: String
    var isFlareDay: Bool
    var profileId: UUID? = nil

    // Source — "app" for sessions logged through Paya's own workout flow,
    // "appleFitness" for ones imported read-only from Apple's native
    // Fitness/Watch workout app via HealthKit (see ExternalWorkoutImporter).
    var sourceRaw: String = "app"
    var externalWorkoutId: String? = nil   // HKWorkout.uuid, for de-duplication on re-import

    // Session HR analytics
        var hrSamples: [Int]?
        var hrSampleIntervalSeconds: Int = 5
        var sessionPeakHR: Int?
        var sessionAvgHR: Int?
        var sessionTrimpScore: Double?
        var hrRecovery60: Int?        // bpm drop 60s after final effort

        // Subjective post-session reflection
        var subjectiveRPE: Int?              // 1-10
        var energyAfter: Int?                // 1=drained, 2=OK, 3=energized
        var reflectionTags: [String] = []
        var reflectionNotes: String?
        var reflectedAt: Date?

    @Relationship(deleteRule: .cascade)
    var exercises: [ExerciseLog] = []

    init(
        sessionType: String,
        date: Date = .now,
        durationMinutes: Int = 0,
        isCompleted: Bool = false,
        notes: String = "",
        isFlareDay: Bool = false,
        hrSamples: [Int]? = nil,
        hrSampleIntervalSeconds: Int = 5,
        sessionPeakHR: Int? = nil,
                sessionAvgHR: Int? = nil,
                sessionTrimpScore: Double? = nil,
                hrRecovery60: Int? = nil,
                subjectiveRPE: Int? = nil,
                energyAfter: Int? = nil,
                reflectionTags: [String] = [],
                reflectionNotes: String? = nil,
                reflectedAt: Date? = nil
            ) {
        self.id = UUID()
        self.sessionType = sessionType
        self.date = date
        self.durationMinutes = durationMinutes
        self.isCompleted = isCompleted
        self.notes = notes
        self.isFlareDay = isFlareDay
        self.hrSamples = hrSamples
        self.hrSampleIntervalSeconds = hrSampleIntervalSeconds
                self.sessionPeakHR = sessionPeakHR
                        self.sessionAvgHR = sessionAvgHR
                        self.sessionTrimpScore = sessionTrimpScore
                        self.hrRecovery60 = hrRecovery60
                        self.subjectiveRPE = subjectiveRPE
                        self.energyAfter = energyAfter
                        self.reflectionTags = reflectionTags
                        self.reflectionNotes = reflectionNotes
                        self.reflectedAt = reflectedAt
                    }
}

// MARK: - Exercise Log

@Model
class ExerciseLog {
    var id: UUID
    var exerciseId: String        // matches ProgramData exercise id
    var exerciseName: String
    var isPersonalBest: Bool
    var orderIndex: Int           // preserves display order

    // Captured at log time from the exercise definition rather than
    // reconstructed later by matching exerciseName against the pool —
    // custom/swapped/renamed exercises wouldn't match reliably after the
    // fact. Empty for freeform custom exercises with no known pattern.
    var muscleGroup: String = ""
    var note: String = ""

    /// Cable machine variant metadata — only meaningful for cable exercises.
    /// Stored as raw strings so SwiftData can persist them without enums.
    var cableAttachment: String? = nil   // e.g. "rope", "straight_bar"
    var cablePosition: String? = nil     // e.g. "high", "mid", "low"

    @Relationship(deleteRule: .cascade)
    var sets: [SetLog] = []

    @Relationship(inverse: \TrainingSession.exercises)
    var session: TrainingSession?

    init(
        exerciseId: String,
        exerciseName: String,
        orderIndex: Int = 0,
        isPersonalBest: Bool = false,
        muscleGroup: String = ""
    ) {
        self.id = UUID()
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.orderIndex = orderIndex
        self.isPersonalBest = isPersonalBest
        self.muscleGroup = muscleGroup
    }
}

// MARK: - Set Log

@Model
class SetLog {
    var id: UUID
    var setNumber: Int
    var weightKg: Double
    var reps: Int
    var isCompleted: Bool
    var rpe: Int                  // 1–10, target 8
    var peakHR: Int?              // Peak BPM during the set
    var avgHR: Int?               // Average BPM during the set
    var endHR: Int?               // BPM at the moment you tapped done

    @Relationship(inverse: \ExerciseLog.sets)
    var exercise: ExerciseLog?

    init(
        setNumber: Int,
        weightKg: Double,
        reps: Int,
        isCompleted: Bool = false,
        rpe: Int = 0,
        peakHR: Int? = nil,
        avgHR: Int? = nil,
        endHR: Int? = nil
    ) {
        self.id = UUID()
        self.setNumber = setNumber
        self.weightKg = weightKg
        self.reps = reps
        self.isCompleted = isCompleted
        self.rpe = rpe
        self.peakHR = peakHR
        self.avgHR = avgHR
        self.endHR = endHR
    }
}

// MARK: - Nutrition Log

@Model
class NutritionLog {
    var id: UUID
    var date: Date
    var totalProtein: Double
    var totalCalories: Double
    var isTrainingDay: Bool
    var proteinTarget: Double     // default 170
    var calorieTarget: Double     // 2200 training / 1900 rest
    var profileId: UUID? = nil

    @Relationship(deleteRule: .cascade)
    var meals: [MealLog] = []

    init(
        date: Date = .now,
        isTrainingDay: Bool = false,
        proteinTarget: Double = 170,
        calorieTarget: Double? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.totalProtein = 0
        self.totalCalories = 0
        self.isTrainingDay = isTrainingDay
        self.proteinTarget = proteinTarget
        self.calorieTarget = calorieTarget ?? (isTrainingDay ? 2200 : 1900)
    }

    func recalculateTotals() {
        totalProtein = meals.reduce(0) { $0 + $1.protein }
        totalCalories = meals.reduce(0) { $0 + $1.calories }
    }

    var totalFat: Double { meals.reduce(0) { $0 + $1.fatG } }
    var totalCarbs: Double { meals.reduce(0) { $0 + $1.carbsG } }
    var totalFiber: Double { meals.reduce(0) { $0 + $1.fiberG } }
    var totalSugar: Double { meals.reduce(0) { $0 + $1.sugarG } }
}

// MARK: - Meal Log

@Model
class MealLog {
    var id: UUID
    var name: String              // e.g. "Breakfast"
    var food: String              // e.g. "3 eggs + 80g oats"
    var protein: Double
    var calories: Double
    var loggedAt: Date

    var fatG: Double = 0
    var carbsG: Double = 0
    var fiberG: Double = 0
    var sugarG: Double = 0
    var sodiumMg: Double = 0
    var ironMg: Double = 0
    var calciumMg: Double = 0
    var magnesiumMg: Double = 0
    var zincMg: Double = 0
    var vitaminDMcg: Double = 0
    var potassiumMg: Double = 0
    var vitaminCMg: Double = 0

    @Relationship(inverse: \NutritionLog.meals)
    var nutritionLog: NutritionLog?

    init(
        name: String,
        food: String,
        protein: Double,
        calories: Double,
        loggedAt: Date = .now,
        fatG: Double = 0,
        carbsG: Double = 0,
        fiberG: Double = 0,
        sugarG: Double = 0,
        sodiumMg: Double = 0,
        ironMg: Double = 0,
        calciumMg: Double = 0,
        magnesiumMg: Double = 0,
        zincMg: Double = 0,
        vitaminDMcg: Double = 0,
        potassiumMg: Double = 0,
        vitaminCMg: Double = 0
    ) {
        self.id = UUID()
        self.name = name
        self.food = food
        self.protein = protein
        self.calories = calories
        self.loggedAt = loggedAt
        self.fatG = fatG
        self.carbsG = carbsG
        self.fiberG = fiberG
        self.sugarG = sugarG
        self.sodiumMg = sodiumMg
        self.ironMg = ironMg
        self.calciumMg = calciumMg
        self.magnesiumMg = magnesiumMg
        self.zincMg = zincMg
        self.vitaminDMcg = vitaminDMcg
        self.potassiumMg = potassiumMg
        self.vitaminCMg = vitaminCMg
    }
}

// MARK: - Health Log

@Model
class HealthLog {
    var id: UUID
    var date: Date
    var isFlareDay: Bool
    var jointPainLevel: Int       // 0–10
    var sleepHours: Double        // 3–10, 0.5 increments
    var energyLevel: Int          // 1=low, 2=ok, 3=high
    var notes: String
    var supplementsTaken: [String]
    var waterMl: Int = 0
    var profileId: UUID? = nil

    init(
        date: Date = .now,
        isFlareDay: Bool = false,
        jointPainLevel: Int = 0,
        sleepHours: Double = 7.0,
        energyLevel: Int = 2,
        notes: String = "",
        supplementsTaken: [String] = [],
        waterMl: Int = 0
    ) {
        self.id = UUID()
        self.date = date
        self.isFlareDay = isFlareDay
        self.jointPainLevel = jointPainLevel
        self.sleepHours = sleepHours
        self.energyLevel = energyLevel
        self.notes = notes
        self.supplementsTaken = supplementsTaken
        self.waterMl = waterMl
    }
}

// MARK: - Body Weight Log

@Model
class BodyWeightLog {
    var id: UUID
    var date: Date
    var weightKg: Double
    var profileId: UUID? = nil

    init(date: Date = .now, weightKg: Double) {
        self.id = UUID()
        self.date = date
        self.weightKg = weightKg
    }
}

// MARK: - Body Measurement Log
// Standard tape-measure points used across body-transformation apps —
// confirmed missing entirely from Paya despite the app's own hypertrophy/
// physique-goal framing explicitly caring about this (weekly-insight
// prompt already talks about "V-taper physique"). Weight alone doesn't
// show recomposition (losing fat while gaining muscle can show flat
// weight but real waist/chest/arm change).

@Model
class BodyMeasurementLog {
    var id: UUID
    var date: Date
    var profileId: UUID? = nil
    var neckCm: Double?
    var chestCm: Double?
    var waistCm: Double?
    var hipsCm: Double?
    var bicepCm: Double?
    var thighCm: Double?
    var calfCm: Double?

    init(date: Date = .now) {
        self.id = UUID()
        self.date = date
    }

    var hasAnyValue: Bool {
        neckCm != nil || chestCm != nil || waistCm != nil || hipsCm != nil
            || bicepCm != nil || thighCm != nil || calfCm != nil
    }
}

// MARK: - Progress Photo
// Stored with external storage so photo data doesn't bloat the SwiftData
// store file itself — SwiftData writes @Attribute(.externalStorage) blobs
// to separate files on disk, transparently, same DB semantics.

@Model
class ProgressPhoto {
    var id: UUID
    var date: Date
    var profileId: UUID? = nil
    var angleRaw: String   // "front", "side", "back"
    @Attribute(.externalStorage) var imageData: Data

    init(date: Date = .now, angleRaw: String, imageData: Data) {
        self.id = UUID()
        self.date = date
        self.angleRaw = angleRaw
        self.imageData = imageData
    }

    var angle: Angle {
        Angle(rawValue: angleRaw) ?? .front
    }

    enum Angle: String, CaseIterable, Identifiable {
        case front, side, back
        var id: String { rawValue }
        var displayName: String { rawValue.capitalized }
    }
}

// MARK: - Custom Meal Template (user saved)

@Model
class CustomMealTemplate {
    var id: UUID
    var name: String
    var food: String
    var protein: Double
    var calories: Double
    var createdAt: Date
    var useCount: Int
    var profileId: UUID? = nil

    init(
        name: String,
        food: String,
        protein: Double,
        calories: Double,
        createdAt: Date = .now,
        useCount: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.food = food
        self.protein = protein
        self.calories = calories
        self.createdAt = createdAt
        self.useCount = useCount
    }
}

// MARK: - Drink Type
// Water-only tracking couldn't answer "how much did I actually drink today,
// counting coffee and tea" — every liquid still counts toward the same
// running total (unchanged: WaterStore.todayTotal, the watch app, the
// widget, and CorrelationEngine's "waterMl" field all keep working exactly
// as before), this just tags WHAT was drunk so the log can also surface a
// caffeine-awareness note, which plain water totals never could.

enum DrinkType: String, Codable, CaseIterable, Identifiable {
    case water, coffee, espresso, tea, greenTea, energyDrink, juice, milk, soda, sparklingWater, proteinShake, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .water:         return "Water"
        case .coffee:        return "Coffee"
        case .espresso:      return "Espresso"
        case .tea:           return "Black Tea"
        case .greenTea:      return "Green Tea"
        case .energyDrink:   return "Energy Drink"
        case .juice:         return "Juice"
        case .milk:          return "Milk"
        case .soda:          return "Soda"
        case .sparklingWater: return "Sparkling"
        case .proteinShake:  return "Protein Shake"
        case .other:         return "Other"
        }
    }

    var icon: String {
        switch self {
        case .water:         return "drop.fill"
        case .coffee:        return "cup.and.saucer.fill"
        case .espresso:      return "cup.and.saucer.fill"
        case .tea:           return "mug.fill"
        case .greenTea:      return "leaf.fill"
        case .energyDrink:   return "bolt.fill"
        case .juice:         return "carrot.fill"
        case .milk:          return "cup.and.saucer.fill"
        case .soda:          return "bubbles.and.sparkles.fill"
        case .sparklingWater: return "bubbles.and.sparkles"
        case .proteinShake:  return "figure.strengthtraining.traditional"
        case .other:         return "waterbottle.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .water:         return "0891B2"
        case .coffee:        return "78350F"
        case .espresso:      return "451A03"
        case .tea:           return "92400E"
        case .greenTea:      return "166534"
        case .energyDrink:   return "DC2626"
        case .juice:         return "EA580C"
        case .milk:          return "6B7280"
        case .soda:          return "B91C1C"
        case .sparklingWater: return "0E7490"
        case .proteinShake:  return "7C3AED"
        case .other:         return "6B7280"
        }
    }

    /// USDA/Mayo Clinic averages per 250ml serving.
    var caffeineMgPer250ml: Double {
        switch self {
        case .water, .juice, .milk, .soda, .sparklingWater, .other: return 0
        case .coffee:        return 95
        case .espresso:      return 212
        case .tea:           return 47
        case .greenTea:      return 28
        case .energyDrink:   return 80
        case .proteinShake:  return 0
        }
    }

    /// Approximate kcal per 250ml (USDA).
    var caloriesPer250ml: Double {
        switch self {
        case .water, .sparklingWater: return 0
        case .coffee:        return 2
        case .espresso:      return 5
        case .tea, .greenTea: return 2
        case .energyDrink:   return 112
        case .juice:         return 112
        case .milk:          return 150
        case .soda:          return 105
        case .proteinShake:  return 160
        case .other:         return 0
        }
    }

    /// Approximate sugar grams per 250ml (USDA).
    var sugarGPer250ml: Double {
        switch self {
        case .water, .sparklingWater, .coffee, .espresso, .tea, .greenTea: return 0
        case .energyDrink:   return 27
        case .juice:         return 24
        case .milk:          return 12
        case .soda:          return 26
        case .proteinShake:  return 3
        case .other:         return 0
        }
    }

    /// Approximate protein grams per 250ml.
    var proteinGPer250ml: Double {
        switch self {
        case .milk:          return 8
        case .proteinShake:  return 25
        case .coffee:        return 0.3
        case .espresso:      return 0.1
        default:             return 0
        }
    }

    var calciumMgPer250ml: Double {
        switch self {
        case .milk:          return 300
        case .proteinShake:  return 200
        case .coffee:        return 5
        case .juice:         return 27
        default:             return 0
        }
    }

    var potassiumMgPer250ml: Double {
        switch self {
        case .milk:          return 350
        case .juice:         return 200
        case .coffee:        return 116
        case .tea, .greenTea: return 50
        case .proteinShake:  return 250
        default:             return 0
        }
    }

    var magnesiumMgPer250ml: Double {
        switch self {
        case .milk:          return 25
        case .coffee:        return 7
        case .proteinShake:  return 40
        default:             return 0
        }
    }

    var components: [(label: String, value: String, icon: String, hex: String)] {
        var result: [(String, String, String, String)] = []
        if caffeineMgPer250ml > 0 {
            result.append(("Caffeine", "\(Int(caffeineMgPer250ml))mg", "bolt.fill", "B45309"))
        }
        if caloriesPer250ml > 0 {
            result.append(("Calories", "\(Int(caloriesPer250ml))kcal", "flame.fill", "DC2626"))
        }
        if sugarGPer250ml > 0 {
            result.append(("Sugar", "\(Int(sugarGPer250ml))g", "cube.fill", "F59E0B"))
        }
        if proteinGPer250ml > 0 {
            result.append(("Protein", String(format: "%.1fg", proteinGPer250ml), "fish.fill", "2563EB"))
        }
        if calciumMgPer250ml > 0 {
            result.append(("Calcium", "\(Int(calciumMgPer250ml))mg", "bone.fill", "059669"))
        }
        if potassiumMgPer250ml > 0 {
            result.append(("Potassium", "\(Int(potassiumMgPer250ml))mg", "leaf.fill", "22C55E"))
        }
        if magnesiumMgPer250ml > 0 {
            result.append(("Magnesium", "\(Int(magnesiumMgPer250ml))mg", "sparkles", "8B5CF6"))
        }
        if result.isEmpty {
            result.append(("Pure hydration", "0 cal", "drop.fill", "0891B2"))
        }
        return result
    }
}

// MARK: - Water Event Log
// Timestamped per-glass liquid additions — the running daily total on
// HealthLog only tells you "how much today," not "when" or "what," which is
// what a hydration-timing/wearable correlation (and now a caffeine-
// awareness note) needs.

@Model
class WaterEventLog {
    var id: UUID
    var date: Date
    var ml: Int
    var drinkTypeRaw: String = DrinkType.water.rawValue
    var profileId: UUID? = nil

    init(date: Date = .now, ml: Int, drinkType: DrinkType = .water) {
        self.id = UUID()
        self.date = date
        self.ml = ml
        self.drinkTypeRaw = drinkType.rawValue
    }

    var drinkType: DrinkType {
        get { DrinkType(rawValue: drinkTypeRaw) ?? .water }
        set { drinkTypeRaw = newValue.rawValue }
    }
}

// MARK: - Environmental Reading
// One row per calendar day, captured opportunistically whenever the app is
// open (barometric pressure and air quality have no historical-lookup API
// the way weather does — CMAltimeter only reports live device readings, and
// Open-Meteo's air-quality endpoint is current/forecast-only) — so unlike
// every other correlation input, this one only starts building a history
// from whenever it first runs, not retroactively.

@Model
class EnvironmentalReading {
    var id: UUID
    var date: Date
    var barometricPressureKPa: Double?
    var airQualityIndex: Double?
    var profileId: UUID? = nil

    init(date: Date = .now, barometricPressureKPa: Double? = nil, airQualityIndex: Double? = nil) {
        self.id = UUID()
        self.date = date
        self.barometricPressureKPa = barometricPressureKPa
        self.airQualityIndex = airQualityIndex
    }
}

// MARK: - Wellness Insight Record
// Persists each day a WellnessCorrelationEngine insight fires, so repeated
// patterns can be reported as "this is the Nth time" instead of the engine
// re-discovering the same thing from scratch every day with no memory.

@Model
class WellnessInsightRecord {
    var id: UUID
    var date: Date
    var kind: String   // "mealHR" or "hydrationHR"
    var profileId: UUID? = nil

    init(date: Date = .now, kind: String) {
        self.id = UUID()
        self.date = date
        self.kind = kind
    }
}

// MARK: - Daily Check-In
// A morning wellness log — separate from post-session ReflectionSheet,
// which only fires after a workout. This is the missing "how do you feel
// today" input the biometric-only ReadinessEngine couldn't see: soreness,
// energy, and symptom flags feed the readiness composite directly and can
// override it (an illness/pain flag caps the band regardless of what HRV
// says, the same way a real coach would react to "I feel awful" over a
// good number on a screen).

@Model
class DailyCheckIn {
    var id: UUID
    var date: Date
    var soreness: Int          // 1 (none) – 5 (very sore)
    var energy: Int            // 1 (drained) – 3 (great) — same scale as post-session energyAfter
    var symptomTags: [String]  // reuses ReflectionSheet's tag vocabulary (e.g. "shoulder_pain", "feeling_unwell")
    var profileId: UUID? = nil

    init(date: Date = .now, soreness: Int, energy: Int, symptomTags: [String] = []) {
        self.id = UUID()
        self.date = date
        self.soreness = soreness
        self.energy = energy
        self.symptomTags = symptomTags
    }
}

// MARK: - Blood Pressure Log
//
// Manual entry (for anyone without a HealthKit-connected cuff) plus a
// HealthKit read path (BloodPressureStore.fetchFromHealthKit) for those who
// do — a genuinely absent dimension until now, despite the app already
// having a full correlation framework (CorrelationEngine) ready to receive
// it. Categories follow the American Heart Association's 2017 guideline
// (Whelton PK, et al. "2017 ACC/AHA Guideline for the Prevention,
// Detection, Evaluation, and Management of High Blood Pressure in Adults."
// Hypertension. 2018) — the current standard clinical classification, not
// this app's own invention.
@Model
class BloodPressureLog {
    var id: UUID
    var date: Date
    var systolic: Int
    var diastolic: Int
    var source: String   // "manual" or "healthKit"
    var profileId: UUID? = nil

    init(date: Date = .now, systolic: Int, diastolic: Int, source: String = "manual") {
        self.id = UUID()
        self.date = date
        self.systolic = systolic
        self.diastolic = diastolic
        self.source = source
    }
}

// MARK: - Outdoor Time Log
//
// Time-in-daylight (HealthKit) is a real signal but answers a different
// question than "how long was I actually outside" — you can be outdoors on
// an overcast day, or by a bright window indoors. No sensor on this app's
// current entitlements can infer that automatically (would need
// CoreLocation + barometric-altitude heuristics), so this is a deliberate
// manual log, same honesty tradeoff as blood pressure before a HealthKit
// cuff is connected: a real number you choose to record beats a proxy that
// quietly measures the wrong thing.
@Model
class OutdoorTimeLog {
    var id: UUID
    var date: Date
    var minutes: Double
    var profileId: UUID? = nil

    init(date: Date = .now, minutes: Double) {
        self.id = UUID()
        self.date = date
        self.minutes = minutes
    }
}

// MARK: - Soreness Region Log
//
// DailyCheckIn.soreness is a single 1-5 overall number — useful for trend
// lines, useless for answering "is today's soreness actually where I
// trained yesterday, or somewhere else." This captures WHICH body regions
// are sore today, independent of the once-a-day check-in flow, so it can be
// marked any time and compared directly against yesterday's per-region
// training effort (SorenessCorrelationEngine).
@Model
class SorenessRegionLog {
    var id: UUID
    var date: Date
    // "region:kind" pairs, comma-separated (e.g. "chest:doms,back:flare").
    // Bare region names with no ":kind" (the original format, before the
    // DOMS/flare distinction existed) are read as .doms for compatibility.
    var regionsRaw: String
    var profileId: UUID? = nil

    var entries: [(region: BodyRegion, kind: SorenessKind)] {
        get {
            regionsRaw.split(separator: ",").compactMap { token -> (BodyRegion, SorenessKind)? in
                let parts = token.split(separator: ":")
                guard let region = BodyRegion(rawValue: String(parts[0])) else { return nil }
                let kind = parts.count > 1 ? (SorenessKind(rawValue: String(parts[1])) ?? .doms) : .doms
                return (region, kind)
            }
        }
        set {
            regionsRaw = newValue.map { "\($0.region.rawValue):\($0.kind.rawValue)" }.joined(separator: ",")
        }
    }

    var regions: [BodyRegion] { entries.map(\.region) }

    init(date: Date = .now, entries: [(region: BodyRegion, kind: SorenessKind)] = []) {
        self.id = UUID()
        self.date = date
        self.regionsRaw = entries.map { "\($0.region.rawValue):\($0.kind.rawValue)" }.joined(separator: ",")
    }
}

enum SorenessKind: String {
    case doms      // expected post-training soreness
    case flare     // joint/chronic-condition pain, not training-related
}

// MARK: - Mobility Check-In
//
// A simplified self-assessment version of the three movement patterns most
// commonly screened before loaded training (shoulder overhead reach, hip
// hinge depth, ankle dorsiflexion) — the same three regions this app's
// isJointSensitive flagging already cares about. Cook G, et al. "Functional
// Movement Screening" (Int J Sports Phys Ther, 2014) established these as
// the movement-quality checkpoints most predictive of load-related issues
// under exercises this app is full of (squats, presses, lunges). This
// isn't a clinical FMS score — a 3-tap self-rating, not a graded test —
// but it's the same three checkpoints, tracked over time.
@Model
class MobilityCheckIn {
    var id: UUID
    var date: Date
    var shoulderScore: Int   // 1 (tight) – 3 (great range)
    var hipScore: Int
    var ankleScore: Int
    var profileId: UUID? = nil

    init(date: Date = .now, shoulderScore: Int, hipScore: Int, ankleScore: Int) {
        self.id = UUID()
        self.date = date
        self.shoulderScore = shoulderScore
        self.hipScore = hipScore
        self.ankleScore = ankleScore
    }
}

// MARK: - Symptom Log
//
// Timestamped symptom entries that can be logged at any point during the
// day — unlike DailyCheckIn's symptomTags which only capture morning state.
// The onsetDate records when the symptom actually started (user-selected),
// not when the log was created, so the correlation engine can pinpoint
// which hour-by-hour factors preceded it. Severity (1-3) and optional
// freeform notes round out the entry without adding friction — the whole
// sheet is a single tap + optional detail.
@Model
class SymptomLog {
    var id: UUID
    var date: Date
    var onsetDate: Date
    var tag: String
    var severity: Int       // 1 (mild) – 3 (severe)
    var notes: String
    var profileId: UUID? = nil

    init(tag: String, onsetDate: Date = .now, severity: Int = 2, notes: String = "") {
        self.id = UUID()
        self.date = .now
        self.onsetDate = onsetDate
        self.tag = tag
        self.severity = severity
        self.notes = notes
    }
}
