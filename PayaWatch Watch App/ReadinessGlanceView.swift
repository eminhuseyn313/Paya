import SwiftUI
import HealthKit
import WatchKit

struct ReadinessGlanceView: View {

    @State private var wc = WatchConnectivityManager.shared
    @State private var score: Int?
    @State private var band: String = ""
    @State private var hrv: Double?
    @State private var rhr: Double?
    @State private var sleepHours: Double?
    @State private var isLoading = true
    @State private var isPhoneScore = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                if isLoading {
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(WatchPulse.ai)
                        Text("Reading vitals…")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(WatchPulse.textSecondary)
                    }
                    .padding(.top, 20)
                } else if let score = score {
                    scoreView(score)
                } else {
                    unavailableView
                }
            }
            .padding(.horizontal, 4)
        }
        .background(WatchPulse.canvas)
        .onAppear { fetchData() }
    }

    // MARK: - Score View

    private func scoreView(_ score: Int) -> some View {
        VStack(spacing: 6) {
            Text("READINESS")
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundColor(WatchPulse.textTertiary)
                .tracking(1)

            ZStack {
                Circle()
                    .fill(WatchPulse.surface)
                Circle()
                    .stroke(bandColor.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: Double(score) / 100.0)
                    .stroke(
                        AngularGradient(
                            colors: [bandColor.opacity(0.6), bandColor],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + 360 * Double(score) / 100.0)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(score)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(WatchPulse.textPrimary)
                    Text(band)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(bandColor)
                }
            }
            .frame(width: 94, height: 94)

            if isPhoneScore, let rec = wc.phoneReadinessRecommendation, !rec.isEmpty {
                Text(rec.components(separatedBy: ".").first ?? rec)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(WatchPulse.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
            }

            // Driver metrics
            VStack(spacing: 6) {
                if let hrv = hrv {
                    metricRow(icon: "waveform.path.ecg", label: "HRV", value: String(format: "%.0fms", hrv), color: WatchPulse.recovery)
                }
                if let rhr = rhr {
                    metricRow(icon: "heart.fill", label: "RHR", value: String(format: "%.0fbpm", rhr), color: WatchPulse.vitals)
                }
                if let sleep = sleepHours {
                    metricRow(icon: "moon.fill", label: "Sleep", value: String(format: "%.1fh", sleep), color: WatchPulse.ai)
                }
            }
            .padding(.top, 2)
        }
    }

    private func metricRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(color)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(WatchPulse.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(WatchPulse.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(WatchPulse.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var unavailableView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(WatchPulse.surface)
                    .frame(width: 52, height: 52)
                Image(systemName: "heart.text.clipboard")
                    .font(.system(size: 22))
                    .foregroundColor(WatchPulse.textTertiary)
            }
            Text("No data yet")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(WatchPulse.textPrimary)
            Text("Wear your watch overnight to build a baseline.")
                .font(.system(size: 11))
                .foregroundColor(WatchPulse.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    // MARK: - Band

    private var bandColor: Color {
        guard let s = score else { return WatchPulse.textTertiary }
        switch s {
        case 80...: return WatchPulse.positive
        case 60..<80: return Color(hex: "84CC16")
        case 40..<60: return WatchPulse.warning
        default: return WatchPulse.critical
        }
    }

    // MARK: - Fetch

    private func fetchData() {
        if let phoneScore = wc.phoneReadinessScore,
           let phoneBand = wc.phoneReadinessBand,
           let ts = wc.phoneReadinessTimestamp,
           Date().timeIntervalSince(ts) < 6 * 3600 {
            score = phoneScore
            band = phoneBand
            isPhoneScore = true
            fetchLocalVitals { isLoading = false }
            return
        }

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

            group.enter()
            fetchLatest(.heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli), store: store) { val in
                fetchedHRV = val
                group.leave()
            }

            group.enter()
            fetchLatest(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), store: store) { val in
                fetchedRHR = val
                group.leave()
            }

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

    // Baseline: population average HRV ~40ms, RHR ~65bpm (Nunan et al. 2010)
    private func computeScore() {
        var components: [(score: Double, weight: Double)] = []

        if let h = hrv {
            let s = min(100, max(20, 50 + (h - 40) * 1.5))
            components.append((s, 0.4))
        }

        if let r = rhr {
            let s = min(100, max(20, 50 + (65 - r) * 2.5))
            components.append((s, 0.3))
        }

        if let sl = sleepHours {
            // Watson et al. 2015: 7-9h optimal for adults
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
