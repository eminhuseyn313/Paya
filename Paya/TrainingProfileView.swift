import SwiftUI
import SwiftData

// MARK: - Training Profile
// Experience, equipment access, and injury areas — feeds
// PersonalizationEngine to pick equipment-appropriate exercises, avoid
// flagged injury areas where a safer alternative exists, and scale starting
// weights to the individual instead of a generic template baseline.

struct TrainingProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var profile: PersonProfile? = nil
    @State private var experience: ExperienceLevel = .beginner
    @State private var equipment: EquipmentAccess = .fullGym
    @State private var injuries: Set<InjuryArea> = []
    @State private var daysPerWeek: Int = 3
    @State private var dietPreference: DietPreference = .omnivore
    @State private var sleepTargetHours: Double = 8
    @State private var stressLevel: Int = 2
    @State private var priorityMuscle: MusclePriority = .none
    @State private var goal: TrainingGoal = .hypertrophy

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Days per week", selection: $daysPerWeek) {
                        ForEach(Array(TrainingScienceEngine.allowedDaysRange), id: \.self) { n in
                            Text("\(n)×").tag(n)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    SectionHeader(title: "Availability", icon: "calendar")
                } footer: {
                    Text("The split shape (full body, upper/lower, push/pull/legs) is chosen from this, not your experience — capped at 5, since 6+ days rarely beats 5 well-recovered ones.")
                }

                Section {
                    ForEach(ExperienceLevel.allCases) { level in
                        Button {
                            experience = level
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(level.displayName.capitalized)
                                        .foregroundColor(.primary)
                                    Text(level == .beginner ? "0–1 year" : level == .intermediate ? "1–3 years" : "3+ years")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if experience == level {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(hex: "2563EB"))
                                }
                            }
                        }
                    }
                } header: {
                    SectionHeader(title: "Experience", icon: "chart.line.uptrend.xyaxis")
                } footer: {
                    Text("Scales your starting weights so the plan doesn't assume everyone lifts the same amount.")
                }

                if goal == .hypertrophy {
                    Section {
                        Picker("Focus muscle", selection: $priorityMuscle) {
                            ForEach(MusclePriority.allCases) { m in
                                Text(m.displayName).tag(m)
                            }
                        }
                    } header: {
                        SectionHeader(title: "Muscle focus", icon: "figure.arms.open")
                    } footer: {
                        Text("Hypertrophy only — adds one extra exercise for this muscle on top of full-body coverage, without bloating the session.")
                    }
                }

                Section {
                    ForEach(EquipmentAccess.allCases) { access in
                        Button {
                            equipment = access
                        } label: {
                            HStack(spacing: 12) {
                                SettingsIcon(icon: access.icon, color: Color(hex: "059669"))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(access.displayName)
                                        .foregroundColor(.primary)
                                    Text(access.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if equipment == access {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Color(hex: "059669"))
                                }
                            }
                        }
                    }
                } header: {
                    SectionHeader(title: "Equipment", icon: "dumbbell.fill")
                } footer: {
                    Text("Exercises that need equipment you don't have are swapped for a listed alternative where one fits.")
                }

                Section {
                    ForEach(InjuryArea.allCases) { area in
                        Toggle(area.displayName, isOn: Binding(
                            get: { injuries.contains(area) },
                            set: { isOn in
                                if isOn { injuries.insert(area) } else { injuries.remove(area) }
                            }
                        ))
                    }
                } header: {
                    SectionHeader(title: "Areas to go easy on", icon: "bandage.fill")
                } footer: {
                    Text("Not medical advice — this only prefers a gentler listed alternative when one exists. Talk to a professional about training around an injury.")
                }

                Section {
                    ForEach(DietPreference.allCases) { pref in
                        Button {
                            dietPreference = pref
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pref.displayName).foregroundColor(.primary)
                                    Text(pref.subtitle).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                if dietPreference == pref {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(Color(hex: "059669"))
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Sleep target")
                            Spacer()
                            Text("\(sleepTargetHours, specifier: "%.1f")h").foregroundColor(.secondary)
                        }
                        Slider(value: $sleepTargetHours, in: 5...10, step: 0.5)
                    }
                    Picker("Typical stress", selection: $stressLevel) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    SectionHeader(title: "Lifestyle", icon: "sparkles")
                } footer: {
                    Text("Feeds your AI-generated nutrition, supplement, and recovery plan in Nutrition.")
                }
            }
            .navigationTitle("Training Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear { load() }
    }

    private func load() {
        guard let current = ProfileStore.current(context: modelContext) else { return }
        profile = current
        experience = current.experienceLevel
        equipment = current.equipmentAccess
        injuries = current.injuryFlags
        daysPerWeek = current.preferredTrainingDaysPerWeek
        dietPreference = current.dietPreference
        sleepTargetHours = current.sleepTargetHours
        stressLevel = current.stressLevel
        priorityMuscle = current.priorityMuscle
        goal = current.goal
    }

    private func save() {
        guard let profile else { dismiss(); return }
        profile.experienceLevel = experience
        profile.equipmentAccess = equipment
        profile.injuryFlags = injuries
        profile.preferredTrainingDaysPerWeek = daysPerWeek
        profile.dietPreference = dietPreference
        profile.sleepTargetHours = sleepTargetHours
        profile.stressLevel = stressLevel
        profile.priorityMuscle = priorityMuscle
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
