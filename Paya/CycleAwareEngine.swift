import Foundation
import HealthKit
import SwiftData

// MARK: - Cycle-Aware Adaptation Engine
//
// Uses menstrual cycle tracking from Apple Health (self-reported flow +
// wrist temperature trends) to periodize training intensity and tailor
// nutrition across cycle phases. Only activates for users with
// sex = female and ≥1 menstrual data point in HealthKit.
//
// HealthKit data sources:
//   • HKCategoryType(.menstrualFlow) — self-reported via Health, Flo,
//     Clue, Natural Cycles, or any app that writes to Apple Health.
//   • HKQuantityType(.appleSleepingWristTemperature) — used to detect
//     the post-ovulatory thermogenic shift (biphasic temp pattern).
//
// Phase model (28-day reference, adjusted per user's actual cycle):
//   1. Menstrual (days 1-5): Period. Lower blood volume, potential iron
//      loss. Moderate intensity preferred. Estrogen + progesterone low.
//   2. Follicular (days 6-13): Rising estrogen. Peak strength window.
//      Higher pain tolerance. Best time for PRs/progressive overload.
//   3. Ovulatory (days 14-16): Estrogen peak. Highest energy but also
//      peak ACL injury risk (Hewett 2007, Am J Sports Med).
//   4. Luteal (days 17-28): Rising progesterone → higher core temp,
//      increased RPE at same workload, higher fat oxidation. Reduce
//      HIIT volume, favor steady-state. Carb needs increase ~100-300
//      kcal/day (Barr et al. 1995, Med Sci Sports Exerc).
//
// Research grounding:
//   • McNulty et al. 2020, Sports Med (meta-analysis of 78 studies):
//     "Exercise performance may be trivially reduced during the early
//     follicular phase" — but individual variation is huge.
//   • Oosthuyse & Bosch 2010, Sports Med: "The menstrual cycle affects
//     substrate utilisation: higher fat oxidation in the luteal phase."
//   • Hewett et al. 2007, Am J Sports Med: ACL injury risk is 2-3×
//     higher during the ovulatory phase (days 10-14) due to estrogen's
//     effect on ligament laxity.
//   • Barr et al. 1995, Med Sci Sports Exerc: Basal metabolic rate
//     increases 5-10% during the luteal phase; estimated +100-300
//     kcal/day depending on individual.
//   • De Jonge 2003, Sports Med: comprehensive review confirming
//     individualized responses — the engine shows YOUR pattern, not
//     population averages.

enum CycleAwareEngine {

    // MARK: - Types

    enum CyclePhase: String, CaseIterable {
        case menstrual   = "Menstrual"
        case follicular  = "Follicular"
        case ovulatory   = "Ovulatory"
        case luteal      = "Luteal"
        case unknown     = "Unknown"

        var icon: String {
            switch self {
            case .menstrual:  return "drop.fill"
            case .follicular: return "arrow.up.right"
            case .ovulatory:  return "sparkles"
            case .luteal:     return "moon.fill"
            case .unknown:    return "questionmark.circle"
            }
        }

        var color: String {
            switch self {
            case .menstrual:  return "FF5A8A"
            case .follicular: return "4AE68A"
            case .ovulatory:  return "FFB547"
            case .luteal:     return "7B61FF"
            case .unknown:    return "888888"
            }
        }
    }

    struct CycleDay {
        let date: Date
        let phase: CyclePhase
        let dayOfCycle: Int         // 1-based
        let cycleLength: Int        // estimated total cycle length
    }

    struct PhaseRecommendation: Identifiable {
        let id = UUID()
        let category: Category
        let title: String
        let detail: String
        let icon: String

        enum Category: String {
            case training  = "Training"
            case nutrition = "Nutrition"
            case recovery  = "Recovery"
            case caution   = "Caution"
        }
    }

    struct CycleOverview {
        let isAvailable: Bool       // false if no menstrual data or not female
        let currentPhase: CyclePhase
        let currentDay: CycleDay?
        let estimatedCycleLength: Int
        let recommendations: [PhaseRecommendation]
        let recentCycles: [CycleSummary]
        let tempTrend: TempTrend?
    }

    struct CycleSummary: Identifiable {
        let id = UUID()
        let startDate: Date
        let length: Int
    }

    struct TempTrend {
        let hasShift: Bool          // detected biphasic shift
        let avgFollicular: Double   // °C
        let avgLuteal: Double       // °C
        let shift: Double           // luteal - follicular
    }

    // MARK: - HealthKit

    private static let healthStore = HKHealthStore()

    static func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        guard let menstrualType = HKCategoryType.categoryType(forIdentifier: .menstrualFlow) else { return false }

        var readTypes: Set<HKObjectType> = [menstrualType]
        if let wristTemp = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
            readTypes.insert(wristTemp)
        }

        return await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(toShare: [], read: readTypes) { ok, _ in
                continuation.resume(returning: ok)
            }
        }
    }

    /// Fetch menstrual flow samples from HealthKit.
    private static func fetchMenstrualFlowDates(daysBack: Int) async -> [Date] {
        guard let menstrualType = HKCategoryType.categoryType(forIdentifier: .menstrualFlow) else { return [] }
        let start = Calendar.current.date(byAdding: .day, value: -daysBack, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: menstrualType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, _ in
                guard let samples = results as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }
                // Filter to actual flow days (not "none" or predicted)
                let flowDates = samples
                    .filter { $0.value != HKCategoryValueVaginalBleeding.none.rawValue }
                    .map(\.startDate)
                continuation.resume(returning: flowDates)
            }
            healthStore.execute(query)
        }
    }

    /// Fetch wrist temperature deviations to detect ovulation shift.
    private static func fetchWristTemps(daysBack: Int) async -> [(date: Date, value: Double)] {
        guard let tempType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) else { return [] }
        let start = Calendar.current.date(byAdding: .day, value: -daysBack, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: tempType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, _ in
                guard let samples = results as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                let mapped = samples.map { sample in
                    (date: sample.endDate, value: sample.quantity.doubleValue(for: .degreeCelsius()))
                }
                continuation.resume(returning: mapped)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Compute

    static func compute(sexRaw: String) async -> CycleOverview {
        let unavailable = CycleOverview(isAvailable: false, currentPhase: .unknown, currentDay: nil, estimatedCycleLength: 28, recommendations: [], recentCycles: [], tempTrend: nil)

        // Only activate for female users
        guard sexRaw.lowercased() == "female" else { return unavailable }

        let authorized = await requestAuthorization()
        guard authorized else { return unavailable }

        // Fetch 6 months of menstrual data
        let flowDates = await fetchMenstrualFlowDates(daysBack: 180)
        guard !flowDates.isEmpty else { return unavailable }

        // Detect cycle starts (first flow day of each cycle, with ≥20 day gap)
        let cycleStarts = detectCycleStarts(flowDates: flowDates)
        guard !cycleStarts.isEmpty else { return unavailable }

        // Compute cycle lengths
        let cycleLengths = computeCycleLengths(cycleStarts: cycleStarts)
        let avgCycleLength = cycleLengths.isEmpty ? 28 : Int(Double(cycleLengths.reduce(0, +)) / Double(cycleLengths.count))

        // Build recent cycle summaries
        let recentCycles = zip(cycleStarts, cycleLengths).map { start, length in
            CycleSummary(startDate: start, length: length)
        }

        // Determine current phase
        let (phase, dayOfCycle) = currentPhase(lastCycleStart: cycleStarts.last!, avgLength: avgCycleLength)

        let currentDay = CycleDay(
            date: .now,
            phase: phase,
            dayOfCycle: dayOfCycle,
            cycleLength: avgCycleLength
        )

        // Fetch wrist temp for biphasic detection
        let wristTemps = await fetchWristTemps(daysBack: 90)
        let tempTrend = detectTempShift(wristTemps: wristTemps, cycleStarts: cycleStarts, avgLength: avgCycleLength)

        // Generate phase-specific recommendations
        let recommendations = generateRecommendations(phase: phase, dayOfCycle: dayOfCycle)

        return CycleOverview(
            isAvailable: true,
            currentPhase: phase,
            currentDay: currentDay,
            estimatedCycleLength: avgCycleLength,
            recommendations: recommendations,
            recentCycles: recentCycles,
            tempTrend: tempTrend
        )
    }

    // MARK: - Cycle Detection

    private static func detectCycleStarts(flowDates: [Date]) -> [Date] {
        let calendar = Calendar.current
        var starts: [Date] = []
        var lastStart: Date? = nil

        for date in flowDates.sorted() {
            let dayStart = calendar.startOfDay(for: date)
            if let last = lastStart {
                let gap = calendar.dateComponents([.day], from: last, to: dayStart).day ?? 0
                // New cycle if gap is ≥20 days (flow after a non-flow gap)
                if gap >= 20 {
                    starts.append(dayStart)
                    lastStart = dayStart
                }
            } else {
                starts.append(dayStart)
                lastStart = dayStart
            }
        }
        return starts
    }

    private static func computeCycleLengths(cycleStarts: [Date]) -> [Int] {
        let calendar = Calendar.current
        var lengths: [Int] = []
        for i in 1..<cycleStarts.count {
            let days = calendar.dateComponents([.day], from: cycleStarts[i-1], to: cycleStarts[i]).day ?? 28
            if days >= 20 && days <= 45 { // physiologically plausible range
                lengths.append(days)
            }
        }
        return lengths
    }

    private static func currentPhase(lastCycleStart: Date, avgLength: Int) -> (CyclePhase, Int) {
        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: lastCycleStart, to: .now).day ?? 0
        let dayOfCycle = (daysSinceStart % max(1, avgLength)) + 1

        // Phase boundaries (proportional to cycle length for irregular cycles)
        let menstrualEnd = 5
        let follicularEnd = Int(Double(avgLength) * 0.46)  // ~day 13 in 28-day
        let ovulatoryEnd = Int(Double(avgLength) * 0.57)   // ~day 16 in 28-day

        let phase: CyclePhase
        switch dayOfCycle {
        case 1...menstrualEnd:        phase = .menstrual
        case (menstrualEnd+1)...follicularEnd: phase = .follicular
        case (follicularEnd+1)...ovulatoryEnd: phase = .ovulatory
        default:                      phase = .luteal
        }

        return (phase, dayOfCycle)
    }

    // MARK: - Temperature Shift Detection

    private static func detectTempShift(
        wristTemps: [(date: Date, value: Double)],
        cycleStarts: [Date],
        avgLength: Int
    ) -> TempTrend? {
        guard wristTemps.count >= 14 else { return nil }
        guard let lastStart = cycleStarts.last else { return nil }

        let calendar = Calendar.current

        // Separate temps into follicular (days 1-14) and luteal (days 15+)
        var follicularTemps: [Double] = []
        var lutealTemps: [Double] = []

        for temp in wristTemps {
            let daysSince = calendar.dateComponents([.day], from: lastStart, to: temp.date).day ?? 0
            let day = (daysSince % max(1, avgLength)) + 1
            if day <= avgLength / 2 {
                follicularTemps.append(temp.value)
            } else {
                lutealTemps.append(temp.value)
            }
        }

        guard !follicularTemps.isEmpty && !lutealTemps.isEmpty else { return nil }

        let avgF = follicularTemps.reduce(0, +) / Double(follicularTemps.count)
        let avgL = lutealTemps.reduce(0, +) / Double(lutealTemps.count)
        let shift = avgL - avgF

        // Biphasic shift: typically 0.2-0.6°C (Barron & Fehring 2005)
        return TempTrend(
            hasShift: shift >= 0.1,
            avgFollicular: avgF,
            avgLuteal: avgL,
            shift: shift
        )
    }

    // MARK: - Recommendations

    private static func generateRecommendations(phase: CyclePhase, dayOfCycle: Int) -> [PhaseRecommendation] {
        switch phase {
        case .menstrual:
            return [
                PhaseRecommendation(
                    category: .training,
                    title: "Moderate intensity preferred",
                    detail: "Estrogen and progesterone are at their lowest. Focus on technique-heavy work at moderate loads. Deload if energy is low — this is physiologically normal, not weakness (McNulty et al. 2020, Sports Med).",
                    icon: "figure.walk"
                ),
                PhaseRecommendation(
                    category: .nutrition,
                    title: "Iron-rich foods",
                    detail: "Menstrual blood loss depletes iron stores. Prioritize red meat, lentils, spinach, or fortified cereals. Pair with vitamin C for absorption. Consider iron supplementation if fatigued (ACOG 2015).",
                    icon: "leaf.fill"
                ),
                PhaseRecommendation(
                    category: .recovery,
                    title: "Prioritize sleep and hydration",
                    detail: "Prostaglandins driving cramps can disrupt sleep. Magnesium (300-400mg) may help with both cramps and sleep quality (Parazzini et al. 2017, Magnes Res).",
                    icon: "bed.double.fill"
                )
            ]

        case .follicular:
            return [
                PhaseRecommendation(
                    category: .training,
                    title: "Your strength window",
                    detail: "Rising estrogen enhances neuromuscular function, pain tolerance, and muscle repair. This is your best window for heavy lifts, PRs, and progressive overload (Wikström-Frisén et al. 2017, J Sports Med Phys Fitness).",
                    icon: "flame.fill"
                ),
                PhaseRecommendation(
                    category: .training,
                    title: "Higher volume tolerated",
                    detail: "Estrogen's anti-catabolic effect means you recover faster from muscle damage during this phase. Add an extra working set or increase frequency.",
                    icon: "chart.bar.fill"
                ),
                PhaseRecommendation(
                    category: .nutrition,
                    title: "Standard macro split",
                    detail: "No major metabolic shifts — follow your normal protein/carb/fat targets. Insulin sensitivity is highest now, making carb utilization most efficient.",
                    icon: "fork.knife"
                )
            ]

        case .ovulatory:
            return [
                PhaseRecommendation(
                    category: .training,
                    title: "Peak energy, peak caution",
                    detail: "Estrogen peaks — you'll feel strongest. But ACL injury risk is 2-3× higher due to increased ligament laxity (Hewett et al. 2007, Am J Sports Med). Warm up thoroughly, especially for plyometrics.",
                    icon: "bolt.fill"
                ),
                PhaseRecommendation(
                    category: .caution,
                    title: "Joint stability awareness",
                    detail: "Estrogen relaxes connective tissue. Avoid maximal plyometrics or uncontrolled cutting/pivoting. Focus on controlled, heavy compound lifts instead.",
                    icon: "exclamationmark.triangle.fill"
                ),
                PhaseRecommendation(
                    category: .nutrition,
                    title: "Anti-inflammatory focus",
                    detail: "Ovulation triggers a minor inflammatory response. Omega-3 rich foods (salmon, walnuts) and antioxidant-dense vegetables support recovery.",
                    icon: "leaf.fill"
                )
            ]

        case .luteal:
            return [
                PhaseRecommendation(
                    category: .training,
                    title: "Reduce HIIT, favor steady-state",
                    detail: "Rising progesterone increases core temperature and perceived exertion at the same workload. Fat oxidation is higher — steady-state cardio is more efficient. Reduce interval intensity by 10-15% (Oosthuyse & Bosch 2010, Sports Med).",
                    icon: "figure.cooldown"
                ),
                PhaseRecommendation(
                    category: .nutrition,
                    title: "Increase calories +100-300 kcal",
                    detail: "BMR rises 5-10% in the luteal phase (Barr et al. 1995, Med Sci Sports Exerc). Your body needs more fuel — fighting this creates unnecessary cortisol. Add complex carbs; cravings are metabolic, not weakness.",
                    icon: "plus.circle.fill"
                ),
                PhaseRecommendation(
                    category: .recovery,
                    title: "Expect higher RPE",
                    detail: "The same weights will feel harder. This is hormonal, not a fitness drop. Don't chase intensity — maintain weights but reduce volume 10-20% if needed (De Jonge 2003, Sports Med).",
                    icon: "heart.fill"
                ),
                PhaseRecommendation(
                    category: .nutrition,
                    title: "Magnesium and B6",
                    detail: "Progesterone depletes magnesium. 200-400mg magnesium glycinate + B6 can reduce PMS symptoms by up to 40% (Fathizadeh et al. 2010, Iran J Nurs Midwifery Res).",
                    icon: "pills.fill"
                )
            ]

        case .unknown:
            return [
                PhaseRecommendation(
                    category: .training,
                    title: "Log your cycle for personalized guidance",
                    detail: "Track menstrual flow in Apple Health or a connected app (Flo, Clue, Natural Cycles). After 2+ cycles, Paya will adapt your training and nutrition to your phases.",
                    icon: "calendar.badge.plus"
                )
            ]
        }
    }
}
