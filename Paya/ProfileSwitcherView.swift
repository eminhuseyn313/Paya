import SwiftUI
import SwiftData

// MARK: - Profile Switcher + Editor

struct ProfileSwitcherView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var profiles: [PersonProfile] = []
    @State private var profileToEdit: PersonProfile? = nil
    @State private var showAddSheet = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {

                    ForEach(profiles, id: \.id) { profile in
                        Button {
                            select(profile)
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(profile.color.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                    Text(profile.initials)
                                        .font(.headline.bold())
                                        .foregroundColor(profile.color)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(profile.name)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(.primary)
                                    Text(profile.goal.displayName)
                                        .font(.caption)
                                        .foregroundColor(profile.goal.color)
                                }
                                Spacer()
                                if appState.currentProfileId == profile.id {
                                    Text("Active")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(profile.color)
                                        .clipShape(Capsule())
                                }
                                Button {
                                    profileToEdit = profile
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 32, height: 32)
                                        .background(Color(.tertiarySystemBackground))
                                        .clipShape(Circle())
                                }
                            }
                            .payaCard(padding: 12)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        showAddSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Add profile")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundColor(Color(hex: "2563EB"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "2563EB").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Text("Data scoping per profile arrives in the next update — right now profiles share training days and logs.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $profileToEdit) { profile in
                ProfileEditorView(profile: profile, onSaved: {
                    reload()
                    if appState.currentProfileId == profile.id {
                        appState.syncFromPersonProfile(profile)
                    }
                })
            }
            .alert("New profile", isPresented: $showAddSheet) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) { newName = "" }
                Button("Create") {
                    let trimmed = newName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    let p = ProfileStore.add(name: trimmed, context: modelContext)
                    newName = ""
                    reload()
                    profileToEdit = p
                }
            }
        }
        .onAppear { reload() }
    }

    private func reload() {
        profiles = ProfileStore.all(context: modelContext)
    }

    private func select(_ profile: PersonProfile) {
        ProfileStore.setCurrent(profile)
        appState.syncFromPersonProfile(profile)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

// MARK: - Profile Editor

struct ProfileEditorView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var profile: PersonProfile
    var onSaved: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Name", text: $profile.name)
                    Stepper("Age: \(profile.currentAge)", value: $profile.age, in: 12...90)
                        .onChange(of: profile.age) { _, newAge in
                            profile.birthYear = Calendar.current.component(.year, from: Date()) - newAge
                        }
                    Picker("Sex", selection: $profile.sexRaw) {
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                    }
                }

                Section("Body") {
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("cm", value: $profile.heightCm, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("cm").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("kg", value: $profile.currentWeightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("kg").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Goal weight")
                        Spacer()
                        TextField("kg", value: $profile.bodyWeightGoalKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Text("kg").foregroundColor(.secondary)
                    }
                }

                Section("Training goal") {
                    Picker("Goal", selection: Binding(
                        get: { profile.goal },
                        set: { profile.goal = $0 }
                    )) {
                        ForEach(TrainingGoal.allCases, id: \.self) { goal in
                            Text(goal.displayName).tag(goal)
                        }
                    }
                    Button("Recompute nutrition targets from goal") {
                        let t = GoalEngine.targets(
                            goal: profile.goal,
                            bodyWeightKg: profile.currentWeightKg,
                            age: profile.currentAge,
                            heightCm: profile.heightCm,
                            sexRaw: profile.sexRaw
                        )
                        profile.proteinTargetG = t.proteinG
                        profile.trainingDayCalories = t.trainingDayCalories
                        profile.restDayCalories = t.restDayCalories
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }

                Section {
                    Toggle("Chronic condition tracking", isOn: $profile.hasInflammatoryCondition)
                    if profile.hasInflammatoryCondition {
                        Picker("Condition", selection: Binding(
                            get: { profile.chronicCondition },
                            set: { profile.chronicCondition = $0 }
                        )) {
                            ForEach(ChronicCondition.allCases) { condition in
                                Text(condition.displayName).tag(condition)
                            }
                        }
                    }
                } footer: {
                    Text("Enables flare-risk detection and flare-day load reductions for this profile — the biometric signals it watches (heart rate, HRV, sleep, joint pain) apply across arthritis, lupus, fibromyalgia, ME/CFS, and other fatigue-driving conditions, not only rheumatoid arthritis.")
                }

                Section("Targets") {
                    LabeledContent("Protein", value: "\(Int(profile.proteinTargetG))g")
                    LabeledContent("Training day", value: "\(Int(profile.trainingDayCalories)) kcal")
                    LabeledContent("Rest day", value: "\(Int(profile.restDayCalories)) kcal")
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        try? modelContext.save()
                        onSaved()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}//
//  ProfileSwitcherView.swift
//  Paya
//
//  Created by Emin Huseynzade on 11.07.26.
//

