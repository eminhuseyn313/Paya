import SwiftUI
import SwiftData
import HealthKit

// MARK: - Blood Pressure Category
// AHA 2017 guideline categories (Whelton PK, et al. Hypertension. 2018).

enum BloodPressureCategory: String {
    case normal = "Normal"
    case elevated = "Elevated"
    case stage1 = "Stage 1 Hypertension"
    case stage2 = "Stage 2 Hypertension"
    case crisis = "Hypertensive Crisis"

    var colorHex: String {
        switch self {
        case .normal: return "059669"
        case .elevated: return "84CC16"
        case .stage1: return "D97706"
        case .stage2: return "DC2626"
        case .crisis: return "991B1B"
        }
    }

    static func classify(systolic: Int, diastolic: Int) -> BloodPressureCategory {
        if systolic > 180 || diastolic > 120 { return .crisis }
        if systolic >= 140 || diastolic >= 90 { return .stage2 }
        if systolic >= 130 || diastolic >= 80 { return .stage1 }
        if systolic >= 120 { return .elevated }
        return .normal
    }
}

// MARK: - Blood Pressure Store

enum BloodPressureStore {
    @MainActor
    static func recent(daysBack: Int, context: ModelContext) -> [BloodPressureLog] {
        let pid = ActiveProfile.id
        let cutoff = Calendar.current.date(byAdding: .day, value: -daysBack, to: .now) ?? .now
        let descriptor = FetchDescriptor<BloodPressureLog>(
            predicate: #Predicate { $0.date >= cutoff && $0.profileId == pid },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    static func latest(context: ModelContext) -> BloodPressureLog? {
        recent(daysBack: 90, context: context).last
    }

    /// Pulls any HealthKit-sourced blood-pressure samples (a connected
    /// Withings/Omron cuff, etc.) into the same store manual entries live
    /// in, so BloodPressureCard shows one merged history instead of only
    /// ever seeing what was typed in by hand. Dedups against readings
    /// already imported for the same day + values, so this is safe to call
    /// on every app open.
    @MainActor
    static func syncFromHealthKit(daysBack: Int, context: ModelContext) async {
        let samples = await fetchFromHealthKit(daysBack: daysBack)
        guard !samples.isEmpty else { return }

        let existing = recent(daysBack: daysBack, context: context)
        let calendar = Calendar.current
        let existingKeys = Set(existing.map { "\(calendar.startOfDay(for: $0.date))_\($0.systolic)_\($0.diastolic)" })

        for sample in samples {
            let key = "\(calendar.startOfDay(for: sample.date))_\(sample.systolic)_\(sample.diastolic)"
            guard !existingKeys.contains(key) else { continue }
            let log = BloodPressureLog(date: sample.date, systolic: sample.systolic, diastolic: sample.diastolic, source: "healthKit")
            log.profileId = ActiveProfile.id
            context.insert(log)
        }
        try? context.save()
    }

    @MainActor
    static func save(systolic: Int, diastolic: Int, context: ModelContext) {
        let log = BloodPressureLog(systolic: systolic, diastolic: diastolic)
        log.profileId = ActiveProfile.id
        context.insert(log)
        try? context.save()
    }

    /// Reads any blood-pressure correlation samples HealthKit already has —
    /// for anyone with a connected cuff (Withings, Omron, etc.) syncing to
    /// Apple Health, so they don't have to re-enter what's already logged
    /// elsewhere.
    ///
    /// DISABLED: querying HKCorrelationType(.bloodPressure) via HKSampleQuery
    /// throws a hard, uncatchable NSException ("Authorization to read the
    /// following types is disallowed") on this device even after adding the
    /// type to HealthKitManager's read set and awaiting a fresh
    /// requestAuthorization() call immediately beforehand — the exception
    /// isn't delivered through the query's error callback, so nothing in
    /// Swift can catch it, and it froze/crashed the app on every launch.
    /// Likely a device-level HealthKit restriction (Screen Time/parental
    /// controls or an MDM profile), same category of issue as this app's
    /// blocked Family Controls entitlement. Returning empty unconditionally
    /// until this is root-caused — manual blood-pressure entry is
    /// unaffected and remains the primary path.
    static func fetchFromHealthKit(daysBack: Int) async -> [(date: Date, systolic: Int, diastolic: Int)] {
        []
    }
}

// MARK: - Blood Pressure Card

struct BloodPressureCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var latest: BloodPressureLog? = nil
    @State private var history: [BloodPressureLog] = []
    @State private var showEntry = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .foregroundColor(Color(hex: "DC2626"))
                Text("Blood Pressure")
                    .font(.subheadline.weight(.semibold))
                CardInfoButton(
                    title: "Blood Pressure",
                    explanation: "Categories follow the AHA's 2017 guideline: Normal <120/<80, Elevated 120-129/<80, Stage 1 130-139 or 80-89, Stage 2 ≥140 or ≥90, Crisis >180 or >120 (seek care immediately). This app is not a diagnostic device — log readings from your own cuff, or connect one that syncs to Apple Health."
                )
                Spacer()
                Button {
                    showEntry = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Color(hex: "DC2626"))
                }
            }

            if let latest {
                let category = BloodPressureCategory.classify(systolic: latest.systolic, diastolic: latest.diastolic)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(latest.systolic)/\(latest.diastolic)")
                        .font(.title2.bold())
                    Text("mmHg")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(category.rawValue)
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color(hex: category.colorHex))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: category.colorHex).opacity(0.12))
                        .clipShape(Capsule())
                }
                Text(latest.date.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                if category == .crisis {
                    Text("A reading this high warrants medical attention, not just app tracking.")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "991B1B"))
                }
                if history.count >= 2 {
                    trendChart
                }
            } else {
                Text("No readings yet — log one from your own cuff, or connect one that syncs to Apple Health.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .payaCard(padding: 14)
        .sheet(isPresented: $showEntry) {
            BloodPressureEntrySheet(onSaved: { load() })
        }
        .task {
            await BloodPressureStore.syncFromHealthKit(daysBack: 90, context: modelContext)
            load()
        }
    }

    private func load() {
        history = BloodPressureStore.recent(daysBack: 30, context: modelContext)
        latest = history.last
    }

    /// A short 30-day sparkline — a single reading can't say whether a
    /// Stage 1 number is a one-off or a real pattern; a trend can.
    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LAST 30 DAYS").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
            GeometryReader { geo in
                let systolics = history.map { Double($0.systolic) }
                let diastolics = history.map { Double($0.diastolic) }
                let minV = min(systolics.min() ?? 60, diastolics.min() ?? 60) - 5
                let maxV = max(systolics.max() ?? 140, diastolics.max() ?? 140) + 5
                let range = max(maxV - minV, 1)

                ZStack {
                    linePath(sparklinePoints(systolics, minV: minV, range: range, size: geo.size))
                        .stroke(Color(hex: "DC2626"), lineWidth: 2)
                    linePath(sparklinePoints(diastolics, minV: minV, range: range, size: geo.size))
                        .stroke(Color(hex: "DC2626").opacity(0.45), lineWidth: 1.5)
                }
            }
            .frame(height: 40)
            HStack {
                Text("Systolic").font(.system(size: 9)).foregroundColor(Color(hex: "DC2626"))
                Text("Diastolic").font(.system(size: 9)).foregroundColor(Color(hex: "DC2626").opacity(0.6))
                Spacer()
                Text("\(history.count) readings")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func sparklinePoints(_ values: [Double], minV: Double, range: Double, size: CGSize) -> [CGPoint] {
        values.enumerated().map { i, v in
            let x = values.count > 1 ? size.width * CGFloat(i) / CGFloat(values.count - 1) : size.width / 2
            let y = size.height * (1 - CGFloat((v - minV) / range))
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }
}

private struct BloodPressureEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var onSaved: () -> Void

    @State private var systolic: String = ""
    @State private var diastolic: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Reading") {
                    HStack {
                        TextField("Systolic", text: $systolic)
                            .keyboardType(.numberPad)
                        Text("/")
                            .foregroundColor(.secondary)
                        TextField("Diastolic", text: $diastolic)
                            .keyboardType(.numberPad)
                        Text("mmHg")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Log Blood Pressure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard let sys = Int(systolic), let dia = Int(diastolic) else { return }
                        BloodPressureStore.save(systolic: sys, diastolic: dia, context: modelContext)
                        onSaved()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(Int(systolic) == nil || Int(diastolic) == nil)
                }
            }
        }
        .presentationDetents([.height(220)])
    }
}
