import SwiftUI
import WatchKit
import HealthKit

// MARK: - Stress Resilience: Breathwork
//
// Guided breathing session on Apple Watch with HRV measurement
// before and after. Proves the physiological effect of breathwork
// to the user with their own data.
//
// Research basis:
// - Laborde et al. (2017), "Heart Rate Variability and Cardiac
//   Vagal Tone in Psychophysiological Research" — slow breathing
//   at 6 breaths/min maximizes HRV via respiratory sinus arrhythmia.
// - Lehrer & Gevirtz (2014), "Heart rate variability biofeedback:
//   How and why does it work?" — resonance frequency breathing
//   (~5.5-6 breaths/min) amplifies baroreflex gain.
// - Ma et al. (2017), "The Effect of Diaphragmatic Breathing on
//   Attention, Negative Affect and Stress" — 8 weeks of practice
//   reduces cortisol and improves sustained attention.

struct BreathworkView: View {

    @State private var phase: BreathPhase = .ready
    @State private var breathCount = 0
    @State private var totalBreaths = 12  // ~2 min at 6 breaths/min
    @State private var ringProgress: Double = 0
    @State private var isInhaling = true
    @State private var preHRV: Double?
    @State private var postHRV: Double?
    @State private var timer: Timer?

    private let inhaleSeconds: Double = 4
    private let exhaleSeconds: Double = 6  // longer exhale = parasympathetic activation
    private let breathColor = Color(hex: "0891B2")

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                switch phase {
                case .ready:
                    readyView
                case .measuring:
                    measuringView
                case .breathing:
                    breathingView
                case .postMeasure:
                    measuringView
                case .complete:
                    completeView
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Ready

    private var readyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "wind")
                .font(.system(size: 28))
                .foregroundColor(breathColor)

            Text("Breathwork")
                .font(.headline)

            Text("2-min guided breathing.\n4s in, 6s out — optimal for HRV.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                startPreMeasurement()
            } label: {
                Text("Begin")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(breathColor)

            Picker("Duration", selection: $totalBreaths) {
                Text("1 min").tag(6)
                Text("2 min").tag(12)
                Text("3 min").tag(18)
            }
            .pickerStyle(.wheel)
            .frame(height: 40)
        }
        .padding(.top, 8)
    }

    // MARK: - Measuring HRV

    private var measuringView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .tint(breathColor)

            Text(phase == .measuring ? "Measuring baseline HRV…" : "Measuring post HRV…")
                .font(.caption.weight(.semibold))

            Text("Stay still for 15 seconds")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }

    // MARK: - Breathing

    private var breathingView: some View {
        VStack(spacing: 6) {
            Text(isInhaling ? "BREATHE IN" : "BREATHE OUT")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(breathColor)

            ZStack {
                Circle()
                    .stroke(breathColor.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(breathColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(breathColor.opacity(isInhaling ? 0.15 : 0.05))
                    .scaleEffect(isInhaling ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: isInhaling ? inhaleSeconds : exhaleSeconds), value: isInhaling)

                VStack(spacing: 0) {
                    Text("\(breathCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("of \(totalBreaths)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            if let pre = preHRV {
                Text(String(format: "Baseline: %.0fms", pre))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Button {
                stopBreathing()
                phase = .ready
            } label: {
                Text("Stop")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Complete

    private var completeView: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(Color(hex: "059669"))

            Text("Session complete")
                .font(.headline)

            if let pre = preHRV, let post = postHRV {
                VStack(spacing: 4) {
                    HStack {
                        Text("Before:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.0f ms", pre))
                            .font(.caption.weight(.bold))
                    }
                    HStack {
                        Text("After:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.0f ms", post))
                            .font(.caption.weight(.bold))
                            .foregroundColor(post > pre ? Color(hex: "059669") : .primary)
                    }

                    let delta = post - pre
                    let pct = pre > 0 ? abs(delta) / pre * 100 : 0
                    HStack(spacing: 4) {
                        Image(systemName: delta >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.system(size: 12))
                        Text(String(format: "%+.0f ms (%.0f%%)", delta, pct))
                            .font(.caption.weight(.bold))
                    }
                    .foregroundColor(delta >= 0 ? Color(hex: "059669") : Color(hex: "F59E0B"))
                    .padding(.top, 2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.darkGray).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("HRV data unavailable — wear watch snugly for accurate readings.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                phase = .ready
                breathCount = 0
                preHRV = nil
                postHRV = nil
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 4)
    }

    // MARK: - Logic

    private func startPreMeasurement() {
        phase = .measuring
        WKInterfaceDevice.current().play(.start)
        measureHRV { value in
            preHRV = value
            startBreathing()
        }
    }

    private func startBreathing() {
        phase = .breathing
        breathCount = 0
        isInhaling = true
        ringProgress = 0
        runBreathCycle()
    }

    private func runBreathCycle() {
        guard breathCount < totalBreaths, phase == .breathing else {
            // Done breathing — measure post HRV
            stopBreathing()
            phase = .postMeasure
            measureHRV { value in
                postHRV = value
                phase = .complete
                WKInterfaceDevice.current().play(.success)
            }
            return
        }

        // Inhale
        isInhaling = true
        WKInterfaceDevice.current().play(.click)
        withAnimation(.linear(duration: inhaleSeconds)) {
            ringProgress = Double(breathCount) / Double(totalBreaths) + 0.5 / Double(totalBreaths)
        }

        timer = Timer.scheduledTimer(withTimeInterval: inhaleSeconds, repeats: false) { _ in
            DispatchQueue.main.async {
                guard phase == .breathing else { return }
                // Exhale
                isInhaling = false
                WKInterfaceDevice.current().play(.click)
                withAnimation(.linear(duration: exhaleSeconds)) {
                    ringProgress = Double(breathCount + 1) / Double(totalBreaths)
                }

                timer = Timer.scheduledTimer(withTimeInterval: exhaleSeconds, repeats: false) { _ in
                    DispatchQueue.main.async {
                        breathCount += 1
                        runBreathCycle()
                    }
                }
            }
        }
    }

    private func stopBreathing() {
        timer?.invalidate()
        timer = nil
    }

    private func measureHRV(completion: @escaping (Double?) -> Void) {
        // Query the most recent HRV sample from HealthKit
        let healthStore = HKHealthStore()
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            completion(nil)
            return
        }

        healthStore.requestAuthorization(toShare: nil, read: [hrvType]) { _, _ in
            let predicate = HKQuery.predicateForSamples(
                withStart: Date().addingTimeInterval(-60),
                end: Date(),
                options: .strictEndDate
            )
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))

                // Wait 15 seconds for measurement
                DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                    if let value = value {
                        completion(value)
                    } else {
                        // Try again after the wait
                        let retryQuery = HKSampleQuery(
                            sampleType: hrvType,
                            predicate: HKQuery.predicateForSamples(
                                withStart: Date().addingTimeInterval(-30),
                                end: Date(),
                                options: .strictEndDate
                            ),
                            limit: 1,
                            sortDescriptors: [sort]
                        ) { _, samples, _ in
                            let retryValue = (samples?.first as? HKQuantitySample)?
                                .quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                            DispatchQueue.main.async {
                                completion(retryValue)
                            }
                        }
                        healthStore.execute(retryQuery)
                    }
                }
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - Phase

private enum BreathPhase {
    case ready
    case measuring      // pre-breathwork HRV
    case breathing
    case postMeasure    // post-breathwork HRV
    case complete
}
