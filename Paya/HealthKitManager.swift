import Foundation
import HealthKit
import SwiftUI

@MainActor
@Observable
class HealthKitManager {

    static let shared = HealthKitManager()

    let healthStore = HKHealthStore()
    var isAuthorized: Bool = false
    var authError: String? = nil

    // MARK: - Data we want to read

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []

        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        if let weight = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(weight)
        }
        if let height = HKObjectType.quantityType(forIdentifier: .height) {
            types.insert(height)
        }
        if let restingHR = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHR)
        }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let resp = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
            types.insert(resp)
        }
        if let noise = HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure) {
            types.insert(noise)
        }
        if let spo2 = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) {
            types.insert(spo2)
        }
        if let wristTemp = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
            types.insert(wristTemp)
        }
        if let steadiness = HKObjectType.quantityType(forIdentifier: .appleWalkingSteadiness) {
            types.insert(steadiness)
        }
        if let asymmetry = HKObjectType.quantityType(forIdentifier: .walkingAsymmetryPercentage) {
            types.insert(asymmetry)
        }
        if let hrRecovery = HKObjectType.quantityType(forIdentifier: .heartRateRecoveryOneMinute) {
            types.insert(hrRecovery)
        }
        if let vo2Max = HKObjectType.quantityType(forIdentifier: .vo2Max) {
            types.insert(vo2Max)
        }
        if let daylight = HKObjectType.quantityType(forIdentifier: .timeInDaylight) {
            types.insert(daylight)
        }
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            types.insert(mindful)
        }
        // NOTE: blood-pressure correlation/quantity types deliberately
        // excluded — requesting authorization for them hung indefinitely on
        // this device (the whole app's HealthKit authorization call blocked
        // forever, freezing every launch behind a white screen, since
        // Dashboard's load path awaits this same request). Likely a
        // device-level restriction (Screen Time/MDM), same category as this
        // app's blocked Family Controls entitlement. Blood pressure stays
        // manual-entry-only until this is safely root-caused.
        types.insert(HKObjectType.workoutType())

        return types
    }

    private var writeTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = []

        if let weight = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(weight)
        }
        types.insert(HKObjectType.workoutType())

        return types
    }

    // MARK: - Availability

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Request Authorization

    func requestAuthorization() async {
        guard isHealthDataAvailable else {
            authError = "Health data is not available on this device"
            return
        }

        do {
            try await healthStore.requestAuthorization(
                toShare: writeTypes,
                read: readTypes
            )
            isAuthorized = true
            authError = nil
        } catch {
            authError = error.localizedDescription
            isAuthorized = false
        }
    }

    // MARK: - Latest Body Weight (kg)

    func fetchLatestBodyWeight() async -> (weight: Double, date: Date)? {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: weightType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: (kg, sample.endDate))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Height (cm)

    func fetchHeight() async -> Double? {
        guard let heightType = HKObjectType.quantityType(forIdentifier: .height) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: heightType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: .meterUnit(with: .centi)))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Date of Birth

    func fetchDateOfBirth() async -> Date? {
        try? healthStore.dateOfBirthComponents().date
    }

    // MARK: - Biological Sex

    func fetchBiologicalSex() async -> String? {
        guard let bio = try? healthStore.biologicalSex().biologicalSex else { return nil }
        switch bio {
        case .female: return "female"
        case .male: return "male"
        case .other: return "other"
        default: return nil
        }
    }

    // MARK: - Resting Heart Rate (latest)

    func fetchRestingHR() async -> Int? {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: Int(bpm.rounded()))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Intraday heart rate samples
    // Time-stamped series (not just the latest value) — needed to correlate
    // heart-rate behavior against when meals/water were actually logged.

    func fetchHeartRateSamples(since start: Date, until end: Date = .now) async -> [(date: Date, bpm: Double)] {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                let readings = (samples as? [HKQuantitySample])?.map {
                    (date: $0.startDate, bpm: $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                } ?? []
                continuation.resume(returning: readings)
            }
            healthStore.execute(query)
        }
    }

    func fetchAverageHR(from start: Date, to end: Date) async -> Int? {
        let samples = await fetchHeartRateSamples(since: start, until: end)
        guard !samples.isEmpty else { return nil }
        let avg = samples.map(\.bpm).reduce(0, +) / Double(samples.count)
        return Int(avg.rounded())
    }

    // MARK: - Hourly steps (for the Personal Health Management timeline)

    /// Step count bucketed by hour-of-day (0-23) for a given calendar day —
    /// same "walked during sunny hours" question the weather correlation
    /// needs an answer to, at hourly granularity rather than a single
    /// daily total.
    func fetchHourlySteps(for date: Date) async -> [Int: Int] {
        guard let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return [:] }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [:] }

        var interval = DateComponents()
        interval.hour = 1

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepsType,
                quantitySamplePredicate: nil,
                options: .cumulativeSum,
                anchorDate: dayStart,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                var buckets: [Int: Int] = [:]
                results?.enumerateStatistics(from: dayStart, to: dayEnd) { stats, _ in
                    guard let sum = stats.sumQuantity() else { return }
                    let hour = calendar.component(.hour, from: stats.startDate)
                    buckets[hour] = Int(sum.doubleValue(for: .count()))
                }
                continuation.resume(returning: buckets)
            }
            healthStore.execute(query)
        }
    }

    /// Ambient environmental noise level (dBA SPL) bucketed by hour-of-day —
    /// recorded by the Watch's Noise app (or iPhone, when worn/carried) when
    /// the user has that HealthKit permission on. Averaged, not summed,
    /// since decibels don't add meaningfully across a window the way steps
    /// do. Returns nothing for hours with no samples rather than a
    /// misleading zero.
    func fetchHourlyEnvironmentalNoise(for date: Date) async -> [Int: Double] {
        guard let noiseType = HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure) else { return [:] }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [:] }

        var interval = DateComponents()
        interval.hour = 1

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: noiseType,
                quantitySamplePredicate: nil,
                options: .discreteAverage,
                anchorDate: dayStart,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                var buckets: [Int: Double] = [:]
                results?.enumerateStatistics(from: dayStart, to: dayEnd) { stats, _ in
                    guard let avg = stats.averageQuantity() else { return }
                    let hour = calendar.component(.hour, from: stats.startDate)
                    buckets[hour] = avg.doubleValue(for: HKUnit.decibelAWeightedSoundPressureLevel())
                }
                continuation.resume(returning: buckets)
            }
            healthStore.execute(query)
        }
    }

    /// Day-granularity version of fetchHourlyEnvironmentalNoise, for the
    /// correlation engine — one query covering the whole window rather than
    /// one call per day.
    func fetchDailyEnvironmentalNoise(daysBack: Int) async -> [Date: Double] {
        guard let noiseType = HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure) else { return [:] }
        let calendar = Calendar.current
        let dayEnd = calendar.startOfDay(for: .now)
        guard let dayStart = calendar.date(byAdding: .day, value: -daysBack, to: dayEnd) else { return [:] }

        var interval = DateComponents()
        interval.day = 1

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: noiseType,
                quantitySamplePredicate: nil,
                options: .discreteAverage,
                anchorDate: dayStart,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                var buckets: [Date: Double] = [:]
                results?.enumerateStatistics(from: dayStart, to: dayEnd) { stats, _ in
                    guard let avg = stats.averageQuantity() else { return }
                    buckets[calendar.startOfDay(for: stats.startDate)] = avg.doubleValue(for: HKUnit.decibelAWeightedSoundPressureLevel())
                }
                continuation.resume(returning: buckets)
            }
            healthStore.execute(query)
        }
    }

    /// Raw asleep-stage intervals overlapping a given calendar day — used
    /// to shade the sleep hours on the Personal Health Management timeline,
    /// not to compute a total (BiometricStore/HealthMetricsProvider own
    /// that, with proper multi-source overlap merging).
    func fetchSleepPeriods(for date: Date) async -> [(start: Date, end: Date)] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let calendar = Calendar.current
        let dayStart = calendar.date(byAdding: .hour, value: -6, to: calendar.startOfDay(for: date)) ?? date
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        let predicate = HKQuery.predicateForSamples(withStart: dayStart, end: dayEnd, options: [])

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let periods = (samples as? [HKCategorySample])?
                    .filter { asleepValues.contains($0.value) }
                    .map { (start: $0.startDate, end: $0.endDate) } ?? []
                continuation.resume(returning: periods)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - HRV (latest SDNN in ms)

    func fetchHRV() async -> Double? {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let ms = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
                continuation.resume(returning: ms)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Blood Oxygen (SpO2 %)

    func fetchBloodOxygen() async -> Double? {
        guard let spo2Type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: spo2Type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let pct = sample.quantity.doubleValue(for: .percent()) * 100
                continuation.resume(returning: pct)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Respiratory Rate (breaths/min)

    func fetchRespiratoryRate() async -> Double? {
        guard let respType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: respType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: bpm)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Today's Active Energy (kcal)

    func fetchTodayActiveEnergy() async -> Double? {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return nil
        }

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                guard let sum = statistics?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                let kcal = sum.doubleValue(for: .kilocalorie())
                continuation.resume(returning: kcal)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - VO2 Max (Cardio Fitness, latest reading — mL/(kg·min))
    // Apple derives this from outdoor walk/run/hike workouts using the
    // Watch's GPS + HR data; it updates every few days at most, so it's
    // tracked as a slow-moving fitness trend rather than a daily metric.

    func fetchVO2Max() async -> (value: Double, date: Date)? {
        guard let type = HKObjectType.quantityType(forIdentifier: .vo2Max) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let unit = HKUnit(from: "mL/(kg*min)")

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: (sample.quantity.doubleValue(for: unit), sample.endDate))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Heart Rate Recovery (1-minute post-exercise, latest — bpm drop)
    // A validated autonomic-fitness marker: how fast heart rate falls in
    // the first minute after peak exertion. Recorded automatically by the
    // Watch during outdoor workouts (iOS 16+/watchOS 9+).

    func fetchHeartRateRecovery() async -> (value: Double, date: Date)? {
        guard let type = HKObjectType.quantityType(forIdentifier: .heartRateRecoveryOneMinute) else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let unit = HKUnit.count().unitDivided(by: .minute())

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: (sample.quantity.doubleValue(for: unit), sample.endDate))
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Time in Daylight (minutes/day) — Apple's ambient-light-sensor
    // based daylight metric (watchOS 9+ / iOS 17+), a direct sensor reading
    // rather than the weather+steps inference PersonalHealthTimelineEngine
    // previously had to rely on.

    func fetchDailyTimeInDaylight(daysBack: Int) async -> [Date: Double] {
        guard let type = HKObjectType.quantityType(forIdentifier: .timeInDaylight) else { return [:] }
        let calendar = Calendar.current
        let dayEnd = calendar.startOfDay(for: .now)
        guard let dayStart = calendar.date(byAdding: .day, value: -daysBack, to: dayEnd) else { return [:] }

        var interval = DateComponents()
        interval.day = 1

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: nil,
                options: .cumulativeSum,
                anchorDate: dayStart,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, results, _ in
                var buckets: [Date: Double] = [:]
                results?.enumerateStatistics(from: dayStart, to: dayEnd) { stats, _ in
                    guard let sum = stats.sumQuantity() else { return }
                    buckets[calendar.startOfDay(for: stats.startDate)] = sum.doubleValue(for: .minute())
                }
                continuation.resume(returning: buckets)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Mindful minutes (trailing 7 days)

    func fetchWeeklyMindfulMinutes() async -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .mindfulSession) else { return 0 }
        let start = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let minutes = (samples as? [HKCategorySample])?.reduce(0.0) {
                    $0 + $1.endDate.timeIntervalSince($1.startDate) / 60.0
                } ?? 0
                continuation.resume(returning: minutes)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Recent External Workouts (Zepp/Apple Watch, not written by this app)

    /// Workouts recorded by another source (Zepp, watchOS Workout app, etc.) —
    /// excludes anything Paya itself wrote via `saveWorkout`.
    func fetchRecentExternalWorkouts(daysBack: Int = 7) async -> [HKWorkout] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -daysBack, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: Date(),
            options: .strictStartDate
        )
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )

        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }
            healthStore.execute(query)
        }

        let ownBundleId = Bundle.main.bundleIdentifier
        return workouts.filter { $0.sourceRevision.source.bundleIdentifier != ownBundleId }
    }

    // MARK: - Write body weight to Apple Health

    func saveBodyWeight(_ kg: Double, date: Date = Date()) async -> Bool {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            return false
        }

        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(
            type: weightType,
            quantity: quantity,
            start: date,
            end: date
        )

        do {
            try await healthStore.save(sample)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Write workout to Apple Health

    func saveWorkout(
        startDate: Date,
        endDate: Date,
        totalEnergyKcal: Double? = nil
    ) async -> Bool {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())

        do {
            try await builder.beginCollection(at: startDate)
            if let totalEnergyKcal {
                let energySample = HKQuantitySample(
                    type: HKQuantityType(.activeEnergyBurned),
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: totalEnergyKcal),
                    start: startDate,
                    end: endDate
                )
                try await builder.addSamples([energySample])
            }
            try await builder.endCollection(at: endDate)
            try await builder.finishWorkout()
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Recovery Score (helper)

extension HealthKitManager {
    /// Returns a simple 0–100 recovery score based on sleep, HRV trend and resting HR.
    /// Higher = better recovery.
    func computeRecoveryScore(
        sleepHours: Double?,
        hrvMs: Double?,
        restingHR: Int?
    ) -> Int? {
        guard sleepHours != nil || hrvMs != nil || restingHR != nil else { return nil }

        var score = 0.0
        var components = 0.0

        if let sleep = sleepHours {
            let sleepScore = min(100, (sleep / 8.0) * 100)
            score += sleepScore
            components += 1
        }

        if let hrv = hrvMs {
            let hrvScore = min(100, (hrv / 60.0) * 100)
            score += hrvScore
            components += 1
        }

        if let hr = restingHR {
            let hrScore = max(0, min(100, 100 - Double(max(0, hr - 50)) * 2))
            score += hrScore
            components += 1
        }

        guard components > 0 else { return nil }
        return Int((score / components).rounded())
    }
}
