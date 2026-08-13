import SwiftUI
import SwiftData

// MARK: - Medications Card (Health tab entry point)

struct MedicationsCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var medications: [Medication] = []
    @State private var showFullView = false

    var dueCount: Int {
        medications.filter { MedicationStore.isDueToday($0, context: modelContext) }.count
    }

    var body: some View {
        Button {
            showFullView = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "DC2626").opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "pills.fill")
                        .foregroundColor(Color(hex: "DC2626"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Medications")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    if medications.isEmpty {
                        Text("Track treatment schedule & adherence")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else if dueCount > 0 {
                        Text("\(dueCount) due today")
                            .font(.caption2)
                            .foregroundColor(Color(hex: "DC2626"))
                    } else {
                        Text("\(medications.count) tracked — all caught up")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if dueCount > 0 {
                    Text("\(dueCount)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color(hex: "DC2626"))
                        .clipShape(Circle())
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .payaCard(padding: 14)
        }
        .buttonStyle(.plain)
        .onAppear { medications = MedicationStore.active(context: modelContext) }
        .sheet(isPresented: $showFullView, onDismiss: {
            medications = MedicationStore.active(context: modelContext)
        }) {
            MedicationsView()
        }
    }
}

// MARK: - Medications View (full list)

struct MedicationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var medications: [Medication] = []
    @State private var showAddSheet = false
    @State private var refreshTrigger = 0

    var body: some View {
        NavigationStack {
            List {
                if medications.isEmpty {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "pills")
                                .font(.system(size: 32))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("No medications tracked yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Add a biologic, DMARD, or any other treatment on a schedule — Paya will remind you when it's due and let you check whether it correlates with your flares.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(medications) { medication in
                            MedicationRow(medication: medication, refreshTrigger: $refreshTrigger)
                        }
                        .onDelete { indices in
                            for i in indices {
                                MedicationStore.delete(medications[i], context: modelContext)
                            }
                            reload()
                        }
                    }
                }
            }
            .navigationTitle("Medications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add medication")
                }
            }
            .sheet(isPresented: $showAddSheet, onDismiss: reload) {
                AddMedicationSheet()
            }
            .onAppear(perform: reload)
        }
    }

    private func reload() {
        medications = MedicationStore.all(context: modelContext)
    }
}

private struct MedicationRow: View {
    let medication: Medication
    @Binding var refreshTrigger: Int
    @Environment(\.modelContext) private var modelContext

    var takenToday: Bool {
        MedicationStore.takenToday(medication, context: modelContext)
    }
    var isDue: Bool {
        MedicationStore.isDueToday(medication, context: modelContext)
    }
    var nextDue: Date? {
        MedicationStore.nextDueDate(medication, context: modelContext)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(medication.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(medication.dose) · \(medication.frequency.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let nextDue, medication.frequency != .asNeeded {
                    Text(takenToday ? "Taken today" : (isDue ? "Due now" : "Next due \(nextDue.formatted(.relative(presentation: .named)))"))
                        .font(.caption2)
                        .foregroundColor(takenToday ? Color(hex: "059669") : (isDue ? Color(hex: "DC2626") : .secondary))
                }
            }
            Spacer()
            Button {
                MedicationStore.logDose(medication, context: modelContext)
                refreshTrigger += 1
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                Image(systemName: takenToday ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(takenToday ? Color(hex: "059669") : .secondary)
                    .frame(width: 44, height: 44)
            }
            .disabled(takenToday)
            .accessibilityLabel(takenToday ? "Already taken today" : "Mark \(medication.name) as taken")
        }
        .padding(.vertical, 4)
        .id(refreshTrigger)
    }
}

private struct AddMedicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var dose = ""
    @State private var frequency: MedicationFrequency = .weekly

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Name (e.g. Humira, Methotrexate)", text: $name)
                    TextField("Dose (e.g. 40mg)", text: $dose)
                }
                Section("Schedule") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(MedicationFrequency.allCases) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                }
            }
            .navigationTitle("Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty else { return }
                        MedicationStore.add(name: trimmedName, dose: dose, frequency: frequency, context: modelContext)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
