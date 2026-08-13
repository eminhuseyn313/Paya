import Foundation
import HealthKit
import CoreMotion

// MARK: - Health Metrics Provider
// Robust sleep + steps with fallbacks:
// - Sleep: counts asleep stages; falls back to inBed samples (Zepp-style);
//   merges overlapping intervals; never double-counts multi-source data.
// - Steps: HealthKit first; falls back to the iPhone's CoreMotion pedometer
//   (works even if HealthKit read permission was denied).

final class HealthMetricsProvider {

    static let shared = HealthMetricsProvider()
    private let healthStore = HKHealthStore()
    private let pedometer = CMPedometer()
    private let motionActivityManager = CMMotionActivityManager()

    private init() {}

    // MARK: - Sleep

    /// HealthKit first (real asleep/inBed data); on nights with zero HealthKit
    /// sleep data, falls back to a CoreMotion-derived estimate (longest
    /// overnight stationary stretch) so the user still sees a number.
    func fetchSleepRobust() async -> Double? {
        if let fromHealthKit = await fetchSleepFromHealthKit() {
            return fromHealthKit
        }
        return await fetchSleepFallbackFromMotion()
    }

    private func fetchSleepFromHealthKit() async -> Double? {
        guard HKHealthStore.isHealthDataAvailable(),
              let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        // Window: 6pm yesterday → 2pm today (covers late nights and lie-ins)
        let windowStart = calendar.date(byAdding: .hour, value: -6, to: startOfToday) ?? startOfToday
        let windowEnd = min(now, calendar.date(byAdding: .hour, value: 14, to: startOfToday) ?? now)

        let predicate = HKQuery.predicateForSamples(
            withStart: windowStart,
            end: windowEnd,
            options: []            // no strictStartDate — include samples spanning the boundary
        )

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            healthStore.execute(query)
        }

        guard !samples.isEmpty else { return nil }

        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]
        let inBedValue = HKCategoryValueSleepAnalysis.inBed.rawValue

        // Prefer real asleep stages; fall back to inBed (Zepp writes these)
        var relevant = samples.filter { asleepValues.contains($0.value) }
        if relevant.isEmpty {
            relevant = samples.filter { $0.value == inBedValue }
        }
        guard !relevant.isEmpty else { return nil }

        // Merge overlapping intervals (prevents multi-source double count)
        let intervals = relevant
            .map { (start: $0.startDate, end: $0.endDate) }
            .sorted { $0.start < $1.start }

        var merged: [(start: Date, end: Date)] = []
        for interval in intervals {
            if var last = merged.last, interval.start <= last.end {
                last.end = max(last.end, interval.end)
                merged[merged.count - 1] = last
            } else {
                merged.append(interval)
            }
        }

        let totalSeconds = merged.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
        let hours = min(totalSeconds / 3600.0, 16.0)   // sanity clamp
        return hours > 0.5 ? hours : nil
    }

    /// CoreMotion-derived sleep estimate for nights with zero HealthKit data:
    /// the longest continuous "stationary" stretch in the overnight window.
    /// Not real sleep-stage detection — a rough proxy from device stillness.
    private func fetchSleepFallbackFromMotion() async -> Double? {
        guard CMMotionActivityManager.isActivityAvailable(),
              CMMotionActivityManager.authorizationStatus() != .denied else {
            return nil
        }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .hour, value: -6, to: startOfToday) ?? startOfToday
        let windowEnd = min(now, calendar.date(byAdding: .hour, value: 14, to: startOfToday) ?? now)

        let activities: [CMMotionActivity] = await withCheckedContinuation { continuation in
            motionActivityManager.queryActivityStarting(
                from: windowStart, to: windowEnd, to: .main
            ) { activities, _ in
                continuation.resume(returning: activities ?? [])
            }
        }
        guard activities.count >= 2 else { return nil }

        var longestDuration: TimeInterval = 0
        var runStart: Date? = nil

        for activity in activities {
            let isStationary = activity.stationary && activity.confidence != .low
            if isStationary {
                if runStart == nil { runStart = activity.startDate }
            } else {
                if let start = runStart {
                    longestDuration = max(longestDuration, activity.startDate.timeIntervalSince(start))
                }
                runStart = nil
            }
        }
        if let start = runStart {
            longestDuration = max(longestDuration, windowEnd.timeIntervalSince(start))
        }

        let hours = longestDuration / 3600.0
        // Require a plausible sleep-length stretch, not just sitting still at a desk.
        guard hours >= 3.0 && hours <= 11.0 else { return nil }
        return hours
    }

    // MARK: - Steps

    func fetchStepsRobust() async -> Int? {
        // 1st: HealthKit (aggregates iPhone + watch + Zepp)
        if let hkSteps = await fetchHealthKitSteps(), hkSteps > 0 {
            return hkSteps
        }
        // Fallback: iPhone's own pedometer (no HealthKit permission needed)
        return await fetchPedometerSteps()
    }

    private func fetchHealthKitSteps() async -> Int? {
        guard HKHealthStore.isHealthDataAvailable(),
              let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
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
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                guard let sum = statistics?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: Int(sum.doubleValue(for: .count())))
            }
            healthStore.execute(query)
        }
    }

    private func fetchPedometerSteps() async -> Int? {
        guard CMPedometer.isStepCountingAvailable() else { return nil }
        let startOfDay = Calendar.current.startOfDay(for: Date())

        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: startOfDay, to: Date()) { data, _ in
                continuation.resume(returning: data.map { $0.numberOfSteps.intValue })
            }
        }
    }
};//
//  HealthMetricsProvider.swift
//  Paya
//
//  Created by Emin Huseynzade on 16.07.26.
//

