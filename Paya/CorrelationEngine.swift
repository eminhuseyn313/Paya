import Foundation
import SwiftData
import HealthKit

// MARK: - Correlation Engine
//
// Generalizes the hand-built pairwise checks scattered across
// WellnessCorrelationEngine and PersonalHealthTimelineEngine (meal timing
// vs HR, sunny hours vs steps) into one framework that computes real
// Pearson correlation coefficients across every pair of daily metrics the
// app collects, rather than only the specific pairs someone thought to
// hand-code. Existing hand-built insights stay — they're often more
// specific/actionable ("your last meal was late") than a bare correlation
// coefficient can be — this adds the "what did I not think to check"
// layer on top.
//
// Correlation, not causation: every surfaced insight says so explicitly.
// A low sample size or weak coefficient is filtered out rather than shown
// with false confidence.

enum CorrelationEngine {

    struct DailyMetrics {
        let date: Date
        var steps: Double?
        var sleepHours: Double?
        var restingHR: Double?
        var hrv: Double?
        var avgNoiseDb: Double?
        var waterMl: Double?
        var mealCount: Double?
        var trainingVolumeKg: Double?
        var checkInEnergy: Double?
        var checkInSoreness: Double?
        var bloodOxygen: Double?
        var wristTemp: Double?
        var walkingSteadiness: Double?
        var timeInDaylightMin: Double?
        var barometricPressureKPa: Double?
        var airQualityIndex: Double?
        var medicationTaken: Double?   // 1.0/0.0 — any tracked medication logged that day
        var sleepDeepHours: Double?
        var sleepREMHours: Double?
        var jointPain: Double?
        var bpSystolic: Double?
        var bpDiastolic: Double?
        var supplementAdherence: Double?   // 0-100, % of that day's active stack actually taken
        var timeOutdoorMin: Double?

        // CGM glucose (from GlucoseEngine via HealthKit)
        var glucoseMean: Double?           // mg/dL, daily mean glucose
        var glucoseCV: Double?             // %, coefficient of variation (Danne 2017: <36% stable)
        var glucoseTimeInRange: Double?    // %, time in 70-180 mg/dL (Battelino 2019)

        // Behavior tags (1.0 if tagged, 0.0 if not)
        var behaviorAlcohol: Double?
        var behaviorColdShower: Double?
        var behaviorStretching: Double?
        var behaviorMeditation: Double?
        var behaviorLateScreen: Double?
        var behaviorOutdoor: Double?
        var behaviorHighStress: Double?
    }

    struct Metric: Identifiable {
        let id: String
        let label: String
        let unit: String
        let keyPath: (DailyMetrics) -> Double?
    }

    static let metrics: [Metric] = [
        Metric(id: "steps", label: "Steps", unit: "steps", keyPath: { $0.steps }),
        Metric(id: "sleep", label: "Sleep", unit: "hours", keyPath: { $0.sleepHours }),
        Metric(id: "restingHR", label: "Resting HR", unit: "bpm", keyPath: { $0.restingHR }),
        Metric(id: "hrv", label: "HRV", unit: "ms", keyPath: { $0.hrv }),
        Metric(id: "noise", label: "Ambient noise", unit: "dB", keyPath: { $0.avgNoiseDb }),
        Metric(id: "water", label: "Water intake", unit: "ml", keyPath: { $0.waterMl }),
        Metric(id: "meals", label: "Meals logged", unit: "meals", keyPath: { $0.mealCount }),
        Metric(id: "volume", label: "Training volume", unit: "kg", keyPath: { $0.trainingVolumeKg }),
        Metric(id: "energy", label: "Felt energy", unit: "1-3", keyPath: { $0.checkInEnergy }),
        Metric(id: "soreness", label: "Soreness", unit: "1-5", keyPath: { $0.checkInSoreness }),
        Metric(id: "spo2", label: "Blood oxygen", unit: "%", keyPath: { $0.bloodOxygen }),
        Metric(id: "wristTemp", label: "Wrist temperature", unit: "°C", keyPath: { $0.wristTemp }),
        Metric(id: "steadiness", label: "Walking steadiness", unit: "%", keyPath: { $0.walkingSteadiness }),
        Metric(id: "daylight", label: "Time in daylight", unit: "min", keyPath: { $0.timeInDaylightMin }),
        Metric(id: "pressure", label: "Barometric pressure", unit: "kPa", keyPath: { $0.barometricPressureKPa }),
        Metric(id: "aqi", label: "Air quality index", unit: "AQI", keyPath: { $0.airQualityIndex }),
        Metric(id: "medication", label: "Medication taken", unit: "yes/no", keyPath: { $0.medicationTaken }),
        Metric(id: "deepSleep", label: "Deep sleep", unit: "hours", keyPath: { $0.sleepDeepHours }),
        Metric(id: "remSleep", label: "REM sleep", unit: "hours", keyPath: { $0.sleepREMHours }),
        Metric(id: "jointPain", label: "Joint pain", unit: "0-10", keyPath: { $0.jointPain }),
        Metric(id: "bpSystolic", label: "Systolic BP", unit: "mmHg", keyPath: { $0.bpSystolic }),
        Metric(id: "bpDiastolic", label: "Diastolic BP", unit: "mmHg", keyPath: { $0.bpDiastolic }),
        Metric(id: "supplementAdherence", label: "Supplement adherence", unit: "%", keyPath: { $0.supplementAdherence }),
        Metric(id: "timeOutdoor", label: "Time outdoors", unit: "min", keyPath: { $0.timeOutdoorMin }),

        // CGM glucose
        Metric(id: "glucoseMean", label: "Avg glucose", unit: "mg/dL", keyPath: { $0.glucoseMean }),
        Metric(id: "glucoseCV", label: "Glucose variability", unit: "CV%", keyPath: { $0.glucoseCV }),
        Metric(id: "glucoseTIR", label: "Time in range", unit: "%", keyPath: { $0.glucoseTimeInRange }),

        // Behavior tags
        Metric(id: "behaviorAlcohol", label: "Alcohol", unit: "yes/no", keyPath: { $0.behaviorAlcohol }),
        Metric(id: "behaviorColdShower", label: "Cold shower", unit: "yes/no", keyPath: { $0.behaviorColdShower }),
        Metric(id: "behaviorStretching", label: "Stretching", unit: "yes/no", keyPath: { $0.behaviorStretching }),
        Metric(id: "behaviorMeditation", label: "Meditation", unit: "yes/no", keyPath: { $0.behaviorMeditation }),
        Metric(id: "behaviorLateScreen", label: "Late screen time", unit: "yes/no", keyPath: { $0.behaviorLateScreen }),
        Metric(id: "behaviorOutdoor", label: "30+ min outdoors", unit: "yes/no", keyPath: { $0.behaviorOutdoor }),
        Metric(id: "behaviorHighStress", label: "High-stress day", unit: "yes/no", keyPath: { $0.behaviorHighStress })
    ]

    struct Insight: Identifiable {
        var id: String { "\(metricA.id)_\(metricB.id)" }
        let metricA: Metric
        let metricB: Metric
        let r: Double
        let sampleSize: Int
        let text: String
    }

    // |r| >= 0.35 clears Cohen's "moderate" effect-size band (Cohen J.
    // "Statistical Power Analysis for the Behavioral Sciences." 2nd ed.
    // 1988 — r ~0.30 is his moderate threshold; 0.35 sets the bar a touch
    // higher given the small, noisy N typical of daily self-tracked data).
    // The minimum-8-days gate is this app's own choice, not from Cohen —
    // below that, a correlation coefficient is too unstable to report as a
    // pattern rather than noise.
    private static let minSampleSize = 8
    private static let minAbsR = 0.35

    // MARK: - Gather

    @MainActor
    static func gatherDailyMetrics(daysBack: Int = 30, context: ModelContext) async -> [DailyMetrics] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let windowStart = calendar.date(byAdding: .day, value: -daysBack, to: today) else { return [] }
        let pid = ActiveProfile.id

        let biometrics = BiometricStore.shared
        if biometrics.history.isEmpty {
            await biometrics.loadHistory(daysBack: daysBack)
        }

        async let noiseByDay = HealthKitManager.shared.fetchDailyEnvironmentalNoise(daysBack: daysBack)
        async let daylightByDay = HealthKitManager.shared.fetchDailyTimeInDaylight(daysBack: daysBack)

        let waterDescriptor = FetchDescriptor<WaterEventLog>(
            predicate: #Predicate<WaterEventLog> { $0.date >= windowStart && $0.profileId == pid }
        )
        let waterEvents = (try? context.fetch(waterDescriptor)) ?? []

        let nutritionDescriptor = FetchDescriptor<NutritionLog>(
            predicate: #Predicate<NutritionLog> { $0.date >= windowStart && $0.profileId == pid }
        )
        let nutritionLogs = (try? context.fetch(nutritionDescriptor)) ?? []

        let sessionDescriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.date >= windowStart && $0.profileId == pid && $0.isCompleted == true }
        )
        let sessions = (try? context.fetch(sessionDescriptor)) ?? []

        let checkInDescriptor = FetchDescriptor<DailyCheckIn>(
            predicate: #Predicate<DailyCheckIn> { $0.date >= windowStart && $0.profileId == pid }
        )
        let checkIns = (try? context.fetch(checkInDescriptor)) ?? []

        let envDescriptor = FetchDescriptor<EnvironmentalReading>(
            predicate: #Predicate<EnvironmentalReading> { $0.date >= windowStart && $0.profileId == pid }
        )
        let envReadings = (try? context.fetch(envDescriptor)) ?? []

        let healthLogDescriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.date >= windowStart && $0.profileId == pid }
        )
        let healthLogs = (try? context.fetch(healthLogDescriptor)) ?? []

        let bpDescriptor = FetchDescriptor<BloodPressureLog>(
            predicate: #Predicate<BloodPressureLog> { $0.date >= windowStart && $0.profileId == pid }
        )
        let bpLogs = (try? context.fetch(bpDescriptor)) ?? []

        let outdoorDescriptor = FetchDescriptor<OutdoorTimeLog>(
            predicate: #Predicate<OutdoorTimeLog> { $0.date >= windowStart && $0.profileId == pid }
        )
        let outdoorLogs = (try? context.fetch(outdoorDescriptor)) ?? []

        // Only meaningful with an active stack to check against — otherwise
        // every day would read 0%, which is "nothing to take," not a miss.
        let activeSupplementNames = Set(UserSupplementStore.active(context: context).map(\.name))

        // Only meaningful once at least one medication is actually tracked —
        // otherwise every day would show "not taken," which is missing data
        // (nothing to take), not a real adherence miss.
        let hasAnyMedication = !MedicationStore.all(context: context).isEmpty
        let doseDescriptor = FetchDescriptor<MedicationDoseLog>(
            predicate: #Predicate<MedicationDoseLog> { $0.takenAt >= windowStart && $0.profileId == pid }
        )
        let doseLogs = hasAnyMedication ? ((try? context.fetch(doseDescriptor)) ?? []) : []
        let daysWithDose = Set(doseLogs.map { calendar.startOfDay(for: $0.takenAt) })

        let noise = await noiseByDay
        let daylight = await daylightByDay

        var byDay: [Date: DailyMetrics] = [:]
        for summary in biometrics.history {
            let day = calendar.startOfDay(for: summary.date)
            var m = byDay[day] ?? DailyMetrics(date: day)
            m.steps = summary.steps.map(Double.init)
            m.sleepHours = summary.sleepHours
            m.restingHR = summary.restingHR
            m.hrv = summary.hrv
            m.bloodOxygen = summary.bloodOxygen
            m.wristTemp = summary.wristTemp
            m.walkingSteadiness = summary.walkingSteadiness
            m.sleepDeepHours = summary.sleepDeep
            m.sleepREMHours = summary.sleepREM
            byDay[day] = m
        }
        for (day, db) in noise {
            var m = byDay[day] ?? DailyMetrics(date: day)
            m.avgNoiseDb = db
            byDay[day] = m
        }
        for (day, minutes) in daylight {
            var m = byDay[day] ?? DailyMetrics(date: day)
            m.timeInDaylightMin = minutes
            byDay[day] = m
        }
        for reading in envReadings {
            let day = calendar.startOfDay(for: reading.date)
            var m = byDay[day] ?? DailyMetrics(date: day)
            m.barometricPressureKPa = reading.barometricPressureKPa
            m.airQualityIndex = reading.airQualityIndex
            byDay[day] = m
        }
        for log in healthLogs {
            let day = calendar.startOfDay(for: log.date)
            var m = byDay[day] ?? DailyMetrics(date: day)
            m.jointPain = Double(log.jointPainLevel)
            if !activeSupplementNames.isEmpty {
                let taken = activeSupplementNames.intersection(log.supplementsTaken)
                m.supplementAdherence = (Double(taken.count) / Double(activeSupplementNames.count)) * 100
            }
            byDay[day] = m
        }
        for log in outdoorLogs {
            let day = calendar.startOfDay(for: log.date)
            var m = byDay[day] ?? DailyMetrics(date: day)
            m.timeOutdoorMin = (m.timeOutdoorMin ?? 0) + log.minutes
            byDay[day] = m
        }
        for log in bpLogs {
            let day = calendar.startOfDay(for: log.date)
            var m = byDay[day] ?? DailyMetrics(date: day)
            m.bpSystolic = Double(log.systolic)
            m.bpDiastolic = Double(log.diastolic)
            byDay[day] = m
        }
        for event in waterEvents {
            let day = calendar.startOfDay(for: event.date)
            var m = byDay[day] ?? DailyMetrics(date: day)
            m.waterMl = (m.waterMl ?? 0) + Double(event.ml)
            byDay[day] = m
        }
        for log in nutritionLogs {
            let day = calendar.startOfDay(for: log.date)
            var m = byDay[day] ?? DailyMetrics(date: day)
            m.mealCount = Double(log.meals.count)
            byDay[day] = m
        }
        for session in sessions {
            let day = calendar.startOfDay(for: session.date)
            let volume = session.exercises.reduce(0.0) { total, ex in
                total + ex.sets.filter { $0.isCompleted }.reduce(0.0) { $0 + ($1.weightKg * Double($1.reps)) }
            }
            var m = byDay[day] ?? DailyMetrics(date: day)
            m.trainingVolumeKg = (m.trainingVolumeKg ?? 0) + volume
            byDay[day] = m
        }
        for checkIn in checkIns {
            let day = calendar.startOfDay(for: checkIn.date)
            var m = byDay[day] ?? DailyMetrics(date: day)
            m.checkInEnergy = Double(checkIn.energy)
            m.checkInSoreness = Double(checkIn.soreness)
            byDay[day] = m
        }

        // Behavior tags
        let behaviorDescriptor = FetchDescriptor<BehaviorLog>(
            predicate: #Predicate<BehaviorLog> { $0.date >= windowStart && $0.profileId == pid }
        )
        let behaviorLogs = (try? context.fetch(behaviorDescriptor)) ?? []
        for blog in behaviorLogs {
            let day = calendar.startOfDay(for: blog.date)
            var m = byDay[day] ?? DailyMetrics(date: day)
            m.behaviorAlcohol = blog.tagIds.contains("alcohol") ? 1.0 : 0.0
            m.behaviorColdShower = blog.tagIds.contains("cold_shower") ? 1.0 : 0.0
            m.behaviorStretching = blog.tagIds.contains("stretching") ? 1.0 : 0.0
            m.behaviorMeditation = blog.tagIds.contains("meditation") ? 1.0 : 0.0
            m.behaviorLateScreen = blog.tagIds.contains("late_screen") ? 1.0 : 0.0
            m.behaviorOutdoor = blog.tagIds.contains("outdoor_time") ? 1.0 : 0.0
            m.behaviorHighStress = blog.tagIds.contains("high_stress") ? 1.0 : 0.0
            byDay[day] = m
        }

        if hasAnyMedication {
            var day = windowStart
            while day <= today {
                var m = byDay[day] ?? DailyMetrics(date: day)
                m.medicationTaken = daysWithDose.contains(day) ? 1.0 : 0.0
                byDay[day] = m
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }

        // CGM glucose daily stats — from GlucoseEngine (HealthKit reads).
        // Only fetches if the user has a CGM writing to Apple Health;
        // empty result → all glucose fields stay nil → no spurious correlations.
        let glucoseSamples = await GlucoseEngine.fetchGlucoseSamples(from: windowStart)
        if !glucoseSamples.isEmpty {
            let grouped = Dictionary(grouping: glucoseSamples) { calendar.startOfDay(for: $0.date) }
            for (day, daySamples) in grouped where daySamples.count >= 3 {
                let values = daySamples.map(\.value)
                let mean = values.reduce(0, +) / Double(values.count)
                let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
                let cv = mean > 0 ? (sqrt(variance) / mean) * 100 : 0
                let tir = Double(values.filter { $0 >= 70 && $0 <= 180 }.count) / Double(values.count) * 100

                var m = byDay[day] ?? DailyMetrics(date: day)
                m.glucoseMean = mean
                m.glucoseCV = cv
                m.glucoseTimeInRange = tir
                byDay[day] = m
            }
        }

        return byDay.values.sorted { $0.date < $1.date }
    }

    // MARK: - Correlate

    static func discoverInsights(from days: [DailyMetrics]) -> [Insight] {
        var results: [Insight] = []
        for i in 0..<metrics.count {
            for j in (i + 1)..<metrics.count {
                let a = metrics[i]
                let b = metrics[j]
                let pairs = days.compactMap { day -> (Double, Double)? in
                    guard let x = a.keyPath(day), let y = b.keyPath(day) else { return nil }
                    return (x, y)
                }
                guard pairs.count >= minSampleSize, let r = pearsonR(pairs), abs(r) >= minAbsR else { continue }

                let direction = r > 0 ? "more" : "less"
                let text = "\(a.label) and \(b.label) tend to move together: on days with more \(a.label.lowercased()), you tend to have \(direction) \(b.label.lowercased()) (r=\(String(format: "%.2f", r)), \(pairs.count) days). Correlation, not proof of cause."
                results.append(Insight(metricA: a, metricB: b, r: r, sampleSize: pairs.count, text: text))
            }
        }
        return results.sorted { abs($0.r) > abs($1.r) }
    }

    // MARK: - Manual builder

    struct ManualResult {
        let metricA: Metric
        let metricB: Metric
        let pairs: [(x: Double, y: Double, date: Date)]
        let r: Double?
        var sampleSize: Int { pairs.count }

        // Cohen J. "Statistical Power Analysis for the Behavioral
        // Sciences." 2nd ed. 1988 — the same source behind
        // CorrelationEngine's auto-discovery cutoff, but the manual builder
        // shows every band rather than filtering below "moderate," since
        // the user picked this pair on purpose and a weak/negligible result
        // is itself a useful answer to "is there a link here or not."
        var strengthLabel: String {
            guard let r else { return "Not enough data yet" }
            switch abs(r) {
            case 0.5...: return "Strong"
            case 0.3..<0.5: return "Moderate"
            case 0.1..<0.3: return "Weak"
            default: return "Negligible"
            }
        }
    }

    /// Correlates exactly the two metrics the user chose, with no
    /// strength/sample-size filtering — unlike discoverInsights, a weak or
    /// data-poor result is a real answer here, not noise to hide.
    static func correlate(_ a: Metric, _ b: Metric, days: [DailyMetrics]) -> ManualResult {
        let pairs = days.compactMap { day -> (x: Double, y: Double, date: Date)? in
            guard let x = a.keyPath(day), let y = b.keyPath(day) else { return nil }
            return (x, y, day.date)
        }
        let r = pairs.count > 1 ? pearsonR(pairs.map { ($0.x, $0.y) }) : nil
        return ManualResult(metricA: a, metricB: b, pairs: pairs, r: r)
    }

    // MARK: - Lagged Cross-Domain Insights
    //
    // The key insight no competitor surfaces: TODAY's nutrition/behavior
    // affects TOMORROW's biometrics. A same-day correlation misses these
    // causal pathways because the effect hasn't materialized yet.
    //
    // Dietary Inflammatory Index research (Shivappa et al. 2014, 65 studies):
    // dietary patterns causally affect inflammatory biomarkers measurable
    // via HRV/RHR with a 12–36 hour lag. Sleep architecture responds to
    // meal timing within one sleep cycle (St-Onge et al. 2016, AJCN).

    /// Metrics that are plausibly "causes" — things you DO today.
    private static let laggedCauses: [Metric] = metrics.filter {
        ["water", "meals", "volume", "energy", "soreness",
         "medication", "supplementAdherence", "timeOutdoor", "daylight",
         "behaviorAlcohol", "behaviorColdShower", "behaviorStretching",
         "behaviorMeditation", "behaviorLateScreen", "behaviorOutdoor",
         "behaviorHighStress"].contains($0.id)
    }

    /// Metrics that are plausibly "effects" — things you MEASURE tomorrow.
    private static let laggedEffects: [Metric] = metrics.filter {
        ["sleep", "deepSleep", "remSleep", "restingHR", "hrv",
         "spo2", "wristTemp", "steadiness", "energy", "soreness",
         "steps", "jointPain",
         "glucoseMean", "glucoseCV", "glucoseTIR"].contains($0.id)
    }

    struct LaggedInsight: Identifiable {
        var id: String { "\(cause.id)_lag\(lagDays)_\(effect.id)" }
        let cause: Metric         // e.g. "Alcohol"
        let effect: Metric        // e.g. "HRV"
        let lagDays: Int          // 1 = "today → tomorrow"
        let r: Double
        let sampleSize: Int
        let text: String
    }

    /// Discovers lagged correlations: "What I did on day N" vs "What I measured
    /// on day N+lag." Default lag = 1 day (the strongest causal window for most
    /// nutrition/behavior → biometric pathways).
    static func discoverLaggedInsights(from days: [DailyMetrics], lag: Int = 1) -> [LaggedInsight] {
        guard days.count > lag + minSampleSize else { return [] }
        let calendar = Calendar.current
        let byDate: [Date: DailyMetrics] = Dictionary(
            days.map { (calendar.startOfDay(for: $0.date), $0) },
            uniquingKeysWith: { _, last in last }
        )

        var results: [LaggedInsight] = []
        for cause in laggedCauses {
            for effect in laggedEffects {
                // Skip same-metric lag (e.g. "energy today → energy tomorrow"
                // is autocorrelation, not a cross-domain insight)
                guard cause.id != effect.id else { continue }

                var pairs: [(Double, Double)] = []
                for day in days {
                    guard let causeVal = cause.keyPath(day),
                          let futureDate = calendar.date(byAdding: .day, value: lag, to: calendar.startOfDay(for: day.date)),
                          let futureDay = byDate[futureDate],
                          let effectVal = effect.keyPath(futureDay) else { continue }
                    pairs.append((causeVal, effectVal))
                }

                guard pairs.count >= minSampleSize,
                      let r = pearsonR(pairs),
                      abs(r) >= minAbsR else { continue }

                let direction = r > 0 ? "higher" : "lower"
                let lagLabel = lag == 1 ? "the next day" : "\(lag) days later"
                let text = "When your \(cause.label.lowercased()) is higher, your \(effect.label.lowercased()) tends to be \(direction) \(lagLabel) (r=\(String(format: "%.2f", r)), \(pairs.count) days). This suggests a delayed effect worth watching."
                results.append(LaggedInsight(
                    cause: cause, effect: effect, lagDays: lag,
                    r: r, sampleSize: pairs.count, text: text
                ))
            }
        }
        return results.sorted { abs($0.r) > abs($1.r) }
    }

    private static func pearsonR(_ pairs: [(Double, Double)]) -> Double? {
        let n = Double(pairs.count)
        guard n > 1 else { return nil }
        let xs = pairs.map(\.0)
        let ys = pairs.map(\.1)
        let meanX = xs.reduce(0, +) / n
        let meanY = ys.reduce(0, +) / n
        var covXY = 0.0, varX = 0.0, varY = 0.0
        for (x, y) in pairs {
            covXY += (x - meanX) * (y - meanY)
            varX += (x - meanX) * (x - meanX)
            varY += (y - meanY) * (y - meanY)
        }
        guard varX > 0, varY > 0 else { return nil }
        return covXY / (varX.squareRoot() * varY.squareRoot())
    }
}
