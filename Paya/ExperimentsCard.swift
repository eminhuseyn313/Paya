import SwiftUI
import SwiftData

// MARK: - Experiments Card
//
// Closed-loop tracking entry point for the Health tab. Shows active
// user-declared experiments ("cutting dairy since Aug 20") each with a
// real before/after comparison, plus passive experiments auto-detected
// from medication start dates — the latter needs zero user action beyond
// having added the medication already.

struct ExperimentsCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var experiments: [Experiment] = []
    @State private var passive: [ExperimentEngine.PassiveExperiment] = []
    @State private var healthLogs: [HealthLog] = []
    @State private var showAdd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "flask.fill")
                    .font(.caption)
                    .foregroundColor(Pulse.ai)
                Text("Experiments")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Button { showAdd = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Pulse.ai)
                }
            }

            if experiments.isEmpty && passive.isEmpty {
                Text("Track whether something you tried actually worked — cutting a food, a new supplement, a sleep change — by comparing your own data before and after. Medications you've logged get checked automatically.")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    ForEach(experiments) { exp in
                        if let cmp = ExperimentEngine.compare(metric: exp.metric, startDate: exp.startDate, healthLogs: healthLogs) {
                            ExperimentRow(title: exp.title, startDate: exp.startDate, comparison: cmp) {
                                ExperimentStore.end(exp, context: modelContext)
                                load()
                            }
                        }
                    }
                    ForEach(passive) { p in
                        ExperimentRow(title: p.title, startDate: p.startDate, comparison: p.comparison, isPassive: true, onDismiss: nil)
                    }
                }
            }
        }
        .payaCard(padding: 14)
        .onAppear { load() }
        .sheet(isPresented: $showAdd) {
            AddExperimentSheet { load() }
        }
    }

    private func load() {
        experiments = ExperimentStore.active(context: modelContext)
        passive = ExperimentEngine.passiveExperiments(context: modelContext)
        let pid = ActiveProfile.id
        let descriptor = FetchDescriptor<HealthLog>(
            predicate: #Predicate<HealthLog> { $0.profileId == pid }
        )
        healthLogs = (try? modelContext.fetch(descriptor)) ?? []
    }
}

private struct ExperimentRow: View {
    let title: String
    let startDate: Date
    let comparison: ExperimentEngine.Comparison
    var isPassive: Bool = false
    var onDismiss: (() -> Void)?

    private var resultColor: Color {
        guard comparison.isReady else { return Pulse.textTertiary }
        if abs(comparison.percentChange) < 5 { return Pulse.textTertiary }
        return comparison.isImprovement ? Pulse.positive : Pulse.warning
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(resultColor.opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: comparison.metric.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(resultColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                    if isPassive {
                        Text("MEDICATION")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Pulse.textTertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Pulse.surfaceFallback)
                            .clipShape(Capsule())
                    }
                }
                Text(comparison.summary)
                    .font(.system(size: 11.5))
                    .foregroundColor(Pulse.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Since \(startDate.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.system(size: 10))
                    .foregroundColor(Pulse.textTertiary)
            }
            Spacer(minLength: 0)
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Pulse.textTertiary.opacity(0.6))
                }
            }
        }
    }
}

// MARK: - Add Experiment Sheet

struct AddExperimentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    var onSaved: () -> Void

    @State private var title = ""
    @State private var metric: ExperimentMetric = .flareFrequency
    @State private var startDate = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("What are you testing?") {
                    TextField("e.g. Cutting dairy", text: $title)
                }
                Section("Track against") {
                    Picker("Metric", selection: $metric) {
                        ForEach(ExperimentMetric.allCases) { m in
                            Label(m.displayName, systemImage: m.icon).tag(m)
                        }
                    }
                }
                Section("Started") {
                    DatePicker("Start date", selection: $startDate, in: ...Date(), displayedComponents: .date)
                }
                Section("Notes (optional)") {
                    TextField("Why you're trying this", text: $notes, axis: .vertical)
                }
                Section {
                    Text("Check back in about a week — the comparison needs enough days after the start date to mean anything.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("New Experiment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        ExperimentStore.add(title: title, metric: metric, startDate: startDate, notes: notes, context: modelContext)
                        onSaved()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
