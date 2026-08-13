import Foundation
import HealthKit
import SwiftUI

// MARK: - Biometric Source

enum BiometricSource: String, Codable, CaseIterable {
    case appleWatch
    case iPhone
    case amazfit
    case fitbit
    case whoop
    case oura
    case garmin
    case polar
    case withings
    case manual
    case unknown

    var displayName: String {
        switch self {
        case .appleWatch: return "Apple Watch"
        case .iPhone: return "iPhone"
        case .amazfit: return "Amazfit"
        case .fitbit: return "Fitbit"
        case .whoop: return "WHOOP"
        case .oura: return "Oura"
        case .garmin: return "Garmin"
        case .polar: return "Polar"
        case .withings: return "Withings"
        case .manual: return "Manual"
        case .unknown: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .appleWatch: return "applewatch"
        case .iPhone: return "iphone"
        case .amazfit: return "watch.analog"
        case .fitbit: return "figure.walk"
        case .whoop: return "waveform.path.ecg"
        case .oura: return "circle.circle"
        case .garmin: return "location.north.circle"
        case .polar: return "heart.text.square"
        case .withings: return "scalemass"
        case .manual: return "square.and.pencil"
        case .unknown: return "questionmark.circle"
        }
    }

    /// Detect source from a HealthKit sample's source bundle identifier
    static func from(bundleId: String?) -> BiometricSource {
        guard let bundle = bundleId?.lowercased() else { return .unknown }

        if bundle.contains("com.apple.health") || bundle.contains("apple.health") {
            return .iPhone
        }
        if bundle.contains("com.apple.healthkit") {
            return .appleWatch
        }
        if bundle.contains("apple") && (bundle.contains("watch") || bundle.contains("nano")) {
            return .appleWatch
        }
        if bundle.contains("amazfit") || bundle.contains("zepp") || bundle.contains("huami") {
            return .amazfit
        }
        if bundle.contains("fitbit") {
            return .fitbit
        }
        if bundle.contains("whoop") {
            return .whoop
        }
        if bundle.contains("oura") {
            return .oura
        }
        if bundle.contains("garmin") {
            return .garmin
        }
        if bundle.contains("polar") {
            return .polar
        }
        if bundle.contains("withings") {
            return .withings
        }
        return .unknown
    }
}

// MARK: - Biometric Type

enum BiometricType: String, Codable {
    case restingHR
    case hrv
    case sleepHours
    case sleepDeep
    case sleepREM
    case respiratoryRate
    case bloodOxygen
    case steps
    case activeEnergy
    case weight
    case wristTemp
    case walkingSteadiness
}

// MARK: - Biometric Sample

struct BiometricSample: Identifiable, Codable {
    let id: UUID
    let type: BiometricType
    let value: Double
    let date: Date
    let source: BiometricSource

    init(
        type: BiometricType,
        value: Double,
        date: Date,
        source: BiometricSource
    ) {
        self.id = UUID()
        self.type = type
        self.value = value
        self.date = date
        self.source = source
    }
}

// MARK: - Daily Summary

struct DailySummary: Identifiable {
    let id = UUID()
    let date: Date
    var restingHR: Double? = nil
    var hrv: Double? = nil
    var sleepHours: Double? = nil
    var sleepDeep: Double? = nil
    var sleepREM: Double? = nil
    var respiratoryRate: Double? = nil
    var bloodOxygen: Double? = nil
    var steps: Int? = nil
    var activeEnergy: Double? = nil
    var weight: Double? = nil
    var wristTemp: Double? = nil          // °C, overnight sleeping wrist temperature
    var walkingSteadiness: Double? = nil  // % — Apple's gait-stability score
    var sources: Set<BiometricSource> = []
}

// MARK: - Biometric Store

@MainActor
@Observable
class BiometricStore {

    static let shared = BiometricStore()

    let healthStore = HKHealthStore()

    var isLoading: Bool = false
    var history: [DailySummary] = []
    var sourcesDetected: Set<BiometricSource> = []

    // MARK: - Load history from HealthKit

    func loadHistory(daysBack: Int = 30) async {
        isLoading = true
        defer { isLoading = false }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: endDate) ?? endDate

        var summaries: [Date: DailySummary] = [:]
        let calendar = Calendar.current

        // Helper to ensure a summary exists for a given day
        func daySummary(for date: Date) -> DailySummary {
            let dayStart = calendar.startOfDay(for: date)
            return summaries[dayStart] ?? DailySummary(date: dayStart)
        }
        func store(_ summary: DailySummary) {
            let dayStart = calendar.startOfDay(for: summary.date)
            summaries[dayStart] = summary
        }

        // Fetch each metric
        async let hrSamples = fetchSamples(
            type: .quantityType(forIdentifier: .restingHeartRate),
            unit: HKUnit.count().unitDivided(by: .minute()),
            startDate: startDate
        )
        async let hrvSamples = fetchSamples(
            type: .quantityType(forIdentifier: .heartRateVariabilitySDNN),
            unit: .secondUnit(with: .milli),
            startDate: startDate
        )
        async let respSamples = fetchSamples(
            type: .quantityType(forIdentifier: .respiratoryRate),
            unit: HKUnit.count().unitDivided(by: .minute()),
            startDate: startDate
        )
        async let spo2Samples = fetchSamples(
            type: .quantityType(forIdentifier: .oxygenSaturation),
            unit: .percent(),
            startDate: startDate
        )
        async let weightSamples = fetchSamples(
            type: .quantityType(forIdentifier: .bodyMass),
            unit: .gramUnit(with: .kilo),
            startDate: startDate
        )
        async let stepsSamples = fetchSamples(
            type: .quantityType(forIdentifier: .stepCount),
            unit: .count(),
            startDate: startDate
        )
        async let energySamples = fetchSamples(
            type: .quantityType(forIdentifier: .activeEnergyBurned),
            unit: .kilocalorie(),
            startDate: startDate
        )
        async let sleepData = fetchSleepSamples(startDate: startDate)
        async let wristTempSamples = fetchSamples(
            type: .quantityType(forIdentifier: .appleSleepingWristTemperature),
            unit: .degreeCelsius(),
            startDate: startDate
        )
        async let steadinessSamples = fetchSamples(
            type: .quantityType(forIdentifier: .appleWalkingSteadiness),
            unit: .percent(),
            startDate: startDate
        )

        let hr = await hrSamples
        let hrv = await hrvSamples
        let resp = await respSamples
        let spo2 = await spo2Samples
        let weight = await weightSamples
        let steps = await stepsSamples
        let energy = await energySamples
        let sleep = await sleepData
        let wristTemp = await wristTempSamples
        let steadiness = await steadinessSamples

        // Aggregate per day
        for sample in hr {
            var s = daySummary(for: sample.date)
            s.restingHR = sample.value
            s.sources.insert(sample.source)
            sourcesDetected.insert(sample.source)
            store(s)
        }
        for sample in hrv {
            var s = daySummary(for: sample.date)
            s.hrv = sample.value
            s.sources.insert(sample.source)
            sourcesDetected.insert(sample.source)
            store(s)
        }
        for sample in resp {
            var s = daySummary(for: sample.date)
            s.respiratoryRate = sample.value
            s.sources.insert(sample.source)
            sourcesDetected.insert(sample.source)
            store(s)
        }
        for sample in spo2 {
            var s = daySummary(for: sample.date)
            s.bloodOxygen = sample.value * 100
            s.sources.insert(sample.source)
            sourcesDetected.insert(sample.source)
            store(s)
        }
        for sample in weight {
            var s = daySummary(for: sample.date)
            s.weight = sample.value
            s.sources.insert(sample.source)
            sourcesDetected.insert(sample.source)
            store(s)
        }
        for (dayStart, stepCount) in aggregateDaily(steps) {
            var s = summaries[dayStart] ?? DailySummary(date: dayStart)
            s.steps = Int(stepCount)
            store(s)
        }
        for (dayStart, kcal) in aggregateDaily(energy) {
            var s = summaries[dayStart] ?? DailySummary(date: dayStart)
            s.activeEnergy = kcal
            store(s)
        }
        for (dayStart, sleepInfo) in sleep {
            var s = summaries[dayStart] ?? DailySummary(date: dayStart)
            s.sleepHours = sleepInfo.total
            s.sleepDeep = sleepInfo.deep
            s.sleepREM = sleepInfo.rem
            for source in sleepInfo.sources {
                s.sources.insert(source)
                sourcesDetected.insert(source)
            }
            store(s)
        }
        for sample in wristTemp {
            var s = daySummary(for: sample.date)
            s.wristTemp = sample.value
            s.sources.insert(sample.source)
            sourcesDetected.insert(sample.source)
            store(s)
        }
        for sample in steadiness {
            var s = daySummary(for: sample.date)
            s.walkingSteadiness = sample.value * 100
            s.sources.insert(sample.source)
            sourcesDetected.insert(sample.source)
            store(s)
        }

        history = Array(summaries.values).sorted { $0.date > $1.date }
    }

    // MARK: - Fetch quantity samples

    private func fetchSamples(
        type: HKQuantityType?,
        unit: HKUnit,
        startDate: Date
    ) async -> [BiometricSample] {
        guard let type = type else { return [] }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: Date(),
            options: []
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                let mapped: [BiometricSample] = samples.map { sample in
                    let source = BiometricSource.from(
                        bundleId: sample.sourceRevision.source.bundleIdentifier
                    )
                    let value = sample.quantity.doubleValue(for: unit)
                    let biometricType: BiometricType = {
                        switch type.identifier {
                        case HKQuantityTypeIdentifier.restingHeartRate.rawValue: return .restingHR
                        case HKQuantityTypeIdentifier.heartRateVariabilitySDNN.rawValue: return .hrv
                        case HKQuantityTypeIdentifier.respiratoryRate.rawValue: return .respiratoryRate
                        case HKQuantityTypeIdentifier.oxygenSaturation.rawValue: return .bloodOxygen
                        case HKQuantityTypeIdentifier.bodyMass.rawValue: return .weight
                        case HKQuantityTypeIdentifier.stepCount.rawValue: return .steps
                        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue: return .activeEnergy
                        case HKQuantityTypeIdentifier.appleSleepingWristTemperature.rawValue: return .wristTemp
                        case HKQuantityTypeIdentifier.appleWalkingSteadiness.rawValue: return .walkingSteadiness
                        default: return .restingHR
                        }
                    }()
                    return BiometricSample(
                        type: biometricType,
                        value: value,
                        date: sample.endDate,
                        source: source
                    )
                }
                continuation.resume(returning: mapped)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Sleep aggregation

    private func fetchSleepSamples(startDate: Date) async -> [Date: (total: Double, deep: Double?, rem: Double?, sources: Set<BiometricSource>)] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return [:]
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: Date(),
            options: []
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [:])
                    return
                }

                let calendar = Calendar.current

                // Group raw intervals by wake-up day first, split into real
                // asleep-stage intervals vs. inBed-only intervals, and
                // separately track per-sample deep/rem hours and sources —
                // matching HealthMetricsProvider.fetchSleepRobust's logic so
                // the two pipelines agree instead of silently diverging
                // (this one previously summed every sample's duration
                // directly with no overlap handling, so two overlapping
                // sources — e.g. Watch + iPhone, or Watch + a third-party
                // band — double-counted the same sleep; it also had no
                // inBed fallback, so a device that only logs "in bed" time
                // showed zero sleep here while the Dashboard's figure,
                // sourced from the other pipeline, showed a real number).
                var asleepIntervalsByDay: [Date: [(start: Date, end: Date)]] = [:]
                var inBedIntervalsByDay: [Date: [(start: Date, end: Date)]] = [:]
                var deepByDay: [Date: Double] = [:]
                var remByDay: [Date: Double] = [:]
                var sourcesByDay: [Date: Set<BiometricSource>] = [:]

                for sample in samples {
                    let hoursDelta = sample.endDate.timeIntervalSince(sample.startDate) / 3600.0
                    let dayStart = calendar.startOfDay(for: sample.endDate)
                    let source = BiometricSource.from(bundleId: sample.sourceRevision.source.bundleIdentifier)
                    sourcesByDay[dayStart, default: []].insert(source)

                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                         HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        asleepIntervalsByDay[dayStart, default: []].append((sample.startDate, sample.endDate))
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        asleepIntervalsByDay[dayStart, default: []].append((sample.startDate, sample.endDate))
                        deepByDay[dayStart, default: 0] += hoursDelta
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        asleepIntervalsByDay[dayStart, default: []].append((sample.startDate, sample.endDate))
                        remByDay[dayStart, default: 0] += hoursDelta
                    case HKCategoryValueSleepAnalysis.inBed.rawValue:
                        inBedIntervalsByDay[dayStart, default: []].append((sample.startDate, sample.endDate))
                    default:
                        break
                    }
                }

                var result: [Date: (total: Double, deep: Double?, rem: Double?, sources: Set<BiometricSource>)] = [:]
                let allDays = Set(asleepIntervalsByDay.keys).union(inBedIntervalsByDay.keys)
                for day in allDays {
                    let asleep = asleepIntervalsByDay[day] ?? []
                    let totalHours = asleep.isEmpty
                        ? Self.mergedHours(inBedIntervalsByDay[day] ?? [])
                        : Self.mergedHours(asleep)
                    result[day] = (
                        total: totalHours,
                        deep: deepByDay[day],
                        rem: remByDay[day],
                        sources: sourcesByDay[day] ?? []
                    )
                }
                continuation.resume(returning: result)
            }
            healthStore.execute(query)
        }
    }

    /// Merges overlapping/adjacent time intervals before summing so two
    /// sources logging the same stretch of sleep don't double-count it.
    private nonisolated static func mergedHours(_ intervals: [(start: Date, end: Date)]) -> Double {
        guard !intervals.isEmpty else { return 0 }
        let sorted = intervals.sorted { $0.start < $1.start }
        var merged: [(start: Date, end: Date)] = [sorted[0]]
        for interval in sorted.dropFirst() {
            if interval.start <= merged[merged.count - 1].end {
                merged[merged.count - 1].end = max(merged[merged.count - 1].end, interval.end)
            } else {
                merged.append(interval)
            }
        }
        return merged.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) / 3600.0 }
    }

    // MARK: - Daily aggregation for cumulative samples

    private func aggregateDaily(_ samples: [BiometricSample]) -> [Date: Double] {
        let calendar = Calendar.current
        var result: [Date: Double] = [:]
        for s in samples {
            let day = calendar.startOfDay(for: s.date)
            result[day] = (result[day] ?? 0) + s.value
        }
        return result
    }

    // MARK: - Convenience accessors

    var today: DailySummary? {
        let today = Calendar.current.startOfDay(for: Date())
        return history.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    var yesterday: DailySummary? {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else {
            return nil
        }
        return history.first { Calendar.current.isDate($0.date, inSameDayAs: yesterday) }
    }

    // MARK: - Baseline calculation

    struct Baseline {
        var mean: Double
        var stdDev: Double
        var samples: Int
    }

    /// Computes user's baseline for a metric over the last `days` days.
    func baseline(for type: BiometricType, days: Int = 14) -> Baseline? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let values = history
            .filter { $0.date >= cutoff }
            .compactMap { day -> Double? in
                switch type {
                case .restingHR:       return day.restingHR
                case .hrv:             return day.hrv
                case .sleepHours:      return day.sleepHours
                case .sleepDeep:       return day.sleepDeep
                case .sleepREM:        return day.sleepREM
                case .respiratoryRate: return day.respiratoryRate
                case .bloodOxygen:     return day.bloodOxygen
                case .weight:          return day.weight
                case .steps:           return day.steps.map(Double.init)
                case .activeEnergy:    return day.activeEnergy
                case .wristTemp:       return day.wristTemp
                case .walkingSteadiness: return day.walkingSteadiness
                }
            }

        guard values.count >= 3 else { return nil }

        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        let stdDev = sqrt(variance)

        return Baseline(mean: mean, stdDev: stdDev, samples: values.count)
    }

    /// Returns the z-score of today's value for a metric (how many stddevs from baseline).
    func zScoreToday(for type: BiometricType) -> Double? {
        guard let today = today,
              let baseline = baseline(for: type),
              baseline.stdDev > 0 else { return nil }

        let value: Double? = {
            switch type {
            case .restingHR:       return today.restingHR
            case .hrv:             return today.hrv
            case .sleepHours:      return today.sleepHours
            case .sleepDeep:       return today.sleepDeep
            case .sleepREM:        return today.sleepREM
            case .respiratoryRate: return today.respiratoryRate
            case .bloodOxygen:     return today.bloodOxygen
            case .weight:          return today.weight
            case .steps:           return today.steps.map(Double.init)
            case .activeEnergy:    return today.activeEnergy
            case .wristTemp:       return today.wristTemp
            case .walkingSteadiness: return today.walkingSteadiness
            }
        }()

        guard let v = value else { return nil }
        return (v - baseline.mean) / baseline.stdDev
    }
}
