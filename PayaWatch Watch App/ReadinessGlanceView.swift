import SwiftUI
import HealthKit
import WatchKit

// MARK: - Readiness Glance (Watch)
//
// A simplified readiness score computed locally on the watch from
// HealthKit data. This does NOT replicate the full ReadinessEngine
// (which runs on the phone with SwiftData context) — instead it
// pulls the most recent HRV and resting HR from HealthKit directly
// and produces a quick-look score.
//
// The user gets an at-a-glance "how recovered am I?" without opening
// the phone app — the primary use case for wrist-bound recovery data.

struct ReadinessGlanceView: View {

    @State private var wc = WatchConnectivityManager.shared
    @State private var score: Int?
    @State private var band: String = ""
    @State private var hrv: Double?
    @State private var rhr: Double?
    @State private var sleepHours: Double?
    @State private var isLoading = true
    /// True when the score came from the phone's baseline-relative engine
    /// rather than the local absolute-threshold fallback.
    @State private var isPhoneScore = false

    private let green = Color(hex: "059669")
    private let lime = Color(hex: "84CC16")
    private let amber = Color(hex: "F59E0B")
    private let red = Color(hex: "DC2626")

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .padding(.top, 20)
                    Text("Reading vitals…")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if let score = score {
                    scoreView(score)
                } else {
                    unavailableView
                }
            }
            .padding(.horizontal, 4)
        }
        .onAppear { fetchData() }
    }

    // MARK: - Score View

    private func scoreView(_ score: Int) -> some View {
        VStack(spacing: 6) {
            Text("READINESS")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)

            ZStack {
                Circle()
                    .stroke(bandColor.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: Double(score) / 100.0)
                    .stroke(bandColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text(band)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(bandColor)
                }
            }
            .frame(width: 90, height: 90)

            // Recommendation (from phone's ReadinessEngine)
            if isPhoneScore, let rec = wc.phoneReadinessRecommendation, !rec.isEmpty {
                Text(rec.components(separatedBy: ".").first ?? rec)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
            }

            // Driver badges
            VStack(spacing: 4) {
                if let hrv = hrv {
                    metricRow(icon: "waveform.path.ecg", label: "HRV", value: String(format: "%.0fms", hrv))
                }
                if let rhr = rhr {
                    metricRow(icon: "heart.fill", label: "RHR", value: String(format: "%.0fbpm", rhr))
                }
                if let sleep = sleepHours {
                    metricRow(icon: "moon.fill", label: "Sleep", value: String(format: "%.1fh", sleep))
                }
            }
        }
    }

    private func metricRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .semibold))
        }
        .padding(.horizontal, 8)
    }

    private var unavailableView: some View {
        VStack(spacing: 6) {
            Image(systemName: "heart.text.clipboard")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("No data yet")
                .font(.subheadline.weight(.semibold))
            Text("Wear your watch overnight to build a readiness baseline.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    // MARK: - Band

    private var bandColor: Color {
        guard let s = score else { return .secondary }
        switch s {
        case 80...: return green
        case 60..<80: return lime
        case 40..<60: return amber
        default: return red
        }
    }

    // MARK: - Fetch

    private func fetchData() {
        // Prefer the phone's baseline-relative ReadinessEngine score when
        // available and recent (< 6 hours). The phone computes z-scores
        // against a 30-day personal baseline; the local fallback uses
        // population-average HRV/RHR thresholds which can be wildly off
        // for individuals.
        if let phoneScore = wc.phoneReadinessScore,
           let phoneBand = wc.phoneReadinessBand,
           let ts = wc.phoneReadinessTimestamp,
           Date().timeIntervalSince(ts) < 6 * 3600 {
            score = phoneScore
            band = phoneBand
            isPhoneScore = true
            // Still fetch local vitals to show the driver badges
            fetchLocalVitals { isLoading = false }
            return
        }

        // Fallback: compute locally from HealthKit with absolute thresholds
        fetchLocalVitals {
            computeScore()
            isLoading = false
        }
    }

    private func fetchLocalVitals(completion: @escaping () -> Void) {
        let store = HKHealthStore()
        let types: Set<HKQuantityType> = [
            .quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            .quantityType(forIdentifier: .restingHeartRate)!,
            .quantityType(forIdentifier: .appleExerciseTime)!
        ]
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        var allTypes = Set<HKSampleType>(types)
        allTypes.insert(sleepType)

        store.requestAuthorization(toShare: nil, read: allTypes) { _, _ in
            let group = DispatchGroup()
            var fetchedHRV: Double?
            var fetchedRHR: Double?
            var fetchedSleep: Double?

            // HRV
            group.enter()
            fetchLatest(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli), store: store) { val in
                fetchedHRV = val
                group.leave()
            }

            // RHR
            group.enter()
            fetchLatest(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), store: store) { val in
                fetchedRHR = val
                group.leave()
            }

            // Sleep
            group.enter()
            fetchSleepHours(store: store) { val in
                fetchedSleep = val
                group.leave()
            }

            group.notify(queue: .main) {
                hrv = fetchedHRV
                rhr = fetchedRHR
                sleepHours = fetchedSleep
                completion()
            }
        }
    }

    private func computeScore() {
        var components: [(score: Double, weight: Double)] = []

        // HRV: baseline assumed ~40ms (population average for adults)
        // Better HRV = higher score
        if let h = hrv {
            let s = min(100, max(20, 50 + (h - 40) * 1.5))
            components.append((s, 0.4))
        }

        // RHR: lower = better. Baseline ~65bpm
        if let r = rhr {
            let s = min(100, max(20, 50 + (65 - r) * 2.5))
            components.append((s, 0.3))
        }

        // Sleep: 7-9h = good
        if let sl = sleepHours {
            let s: Double
            if sl >= 7 && sl <= 9 { s = 90 }
            else if sl >= 6 { s = 70 }
            else { s = max(30, 50 - (6 - sl) * 15) }
            components.append((s, 0.3))
        }

        guard !components.isEmpty else {
            score = nil
            return
        }

        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let composite = components.reduce(0) { $0 + $1.score * $1.weight } / totalWeight
        let s = Int(composite.rounded())
        score = s

        switch s {
        case 80...: band = "Primed"
        case 60..<80: band = "Steady"
        case 40..<60: band = "Go easier"
        default: band = "Recovery"
        }
    }

    // MARK: - HealthKit Helpers

    private func fetchLatest(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, store: HKHealthStore, completion: @escaping (Double?) -> Void) {
        let type = HKQuantityType.quantityType(forIdentifier: identifier)!
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
            let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
            completion(value)
        }
        store.execute(query)
    }

    private func fetchSleepHours(store: HKHealthStore, completion: @escaping (Double?) -> Void) {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictEndDate)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            guard let samples = samples as? [HKCategorySample] else {
                completion(nil)
                return
            }
            // Sum asleep time (excluding in-bed but awake)
            let asleepValues: Set<Int> = [
                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
            ]
            let totalSeconds = samples
                .filter { asleepValues.contains($0.value) }
                .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            completion(totalSeconds > 0 ? totalSeconds / 3600 : nil)
        }
        store.execute(query)
    }
}
