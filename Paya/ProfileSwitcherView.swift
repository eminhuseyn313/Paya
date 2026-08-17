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
                                        .background(Pulse.surfaceElevatedFallback)
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
                        .foregroundColor(Pulse.hydration)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Pulse.hydration.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(PulsePress())

                    Text("Data scoping per profile arrives in the next update — right now profiles share training days and logs.")
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
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

    @State private var hasAppeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                Pulse.canvasFallback.ignoresSafeArea()
                BreathingOrb(color: profile.color, size: 200)
                    .offset(y: -320)
                    .opacity(0.3)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // Avatar header
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(profile.color.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                Text(profile.initials)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(profile.color)
                            }
                            .shadow(color: profile.color.opacity(0.2), radius: 16)
                            Text(profile.name.isEmpty ? "New Profile" : profile.name)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(Pulse.textPrimary)
                        }
                        .padding(.top, 12)
                        .opacity(hasAppeared ? 1 : 0)
                        .scaleEffect(hasAppeared ? 1 : 0.9)

                        // Basics
                        PulseEditorSection(title: "Basics", icon: "person.fill", color: Pulse.hydration) {
                            PulseTextField(label: "Name", text: $profile.name)
                            PulseStepperRow(label: "Age", value: $profile.age, range: 12...90, unit: "years")
                                .onChange(of: profile.age) { _, newAge in
                                    profile.birthYear = Calendar.current.component(.year, from: Date()) - newAge
                                }
                            PulsePickerRow(label: "Sex", selection: $profile.sexRaw, options: [("male", "Male"), ("female", "Female")])
                        }

                        // Body
                        PulseEditorSection(title: "Body", icon: "figure.stand", color: Pulse.recovery) {
                            PulseNumberRow(label: "Height", value: $profile.heightCm, unit: "cm")
                            PulseNumberRow(label: "Weight", value: $profile.currentWeightKg, unit: "kg")
                            PulseNumberRow(label: "Goal weight", value: $profile.bodyWeightGoalKg, unit: "kg")
                        }

                        // Training goal
                        PulseEditorSection(title: "Training Goal", icon: "target", color: Pulse.energy) {
                            Picker("Goal", selection: Binding(
                                get: { profile.goal },
                                set: { profile.goal = $0 }
                            )) {
                                ForEach(TrainingGoal.allCases, id: \.self) { goal in
                                    Text(goal.displayName).tag(goal)
                                }
                            }
                            .tint(Pulse.energy)

                            Button {
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
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 11))
                                    Text("Recompute targets")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundColor(Pulse.energy)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Pulse.energy.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: Pulse.Radius.sm))
                            }
                            .buttonStyle(PulsePress())
                        }

                        // Chronic condition
                        PulseEditorSection(title: "Condition Tracking", icon: "heart.text.clipboard", color: Pulse.vitals) {
                            Toggle(isOn: $profile.hasInflammatoryCondition) {
                                Text("Chronic condition")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Pulse.textPrimary)
                            }
                            .tint(Pulse.vitals)

                            if profile.hasInflammatoryCondition {
                                Picker("Condition", selection: Binding(
                                    get: { profile.chronicCondition },
                                    set: { profile.chronicCondition = $0 }
                                )) {
                                    ForEach(ChronicCondition.allCases) { condition in
                                        Text(condition.displayName).tag(condition)
                                    }
                                }
                                .tint(Pulse.vitals)
                            }

                            Text("Enables flare-risk detection and flare-day load reductions — watches HRV, sleep, joint pain across arthritis, lupus, fibromyalgia, ME/CFS, and more.")
                                .font(.system(size: 10))
                                .foregroundColor(Pulse.textTertiary)
                        }

                        // Targets summary
                        PulseEditorSection(title: "Targets", icon: "chart.bar.fill", color: Pulse.nutrition) {
                            HStack {
                                PulseTargetPill(label: "Protein", value: "\(Int(profile.proteinTargetG))g", color: Pulse.nutrition)
                                PulseTargetPill(label: "Train day", value: "\(Int(profile.trainingDayCalories))", color: Pulse.energy)
                                PulseTargetPill(label: "Rest day", value: "\(Int(profile.restDayCalories))", color: Pulse.recovery)
                            }
                        }

                        Spacer().frame(height: 30)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(.dark)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Edit Profile")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(Pulse.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        try? modelContext.save()
                        onSaved()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(profile.color)
                }
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.5).delay(0.1)) { hasAppeared = true } }
    }
}

// MARK: - Pulse Editor Components

private struct PulseEditorSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Pulse.textTertiary)
            }
            content()
        }
        .payaCard(padding: 14)
    }
}

private struct PulseTextField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Pulse.textPrimary)
            Spacer()
            TextField(label, text: $text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Pulse.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct PulseNumberRow: View {
    let label: String
    @Binding var value: Double
    let unit: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Pulse.textPrimary)
            Spacer()
            TextField(unit, value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(Pulse.textPrimary)
                .frame(width: 70)
            Text(unit)
                .font(.system(size: 12))
                .foregroundColor(Pulse.textTertiary)
        }
    }
}

private struct PulseStepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    var body: some View {
        Stepper(value: $value, in: range) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Pulse.textPrimary)
                Spacer()
                Text("\(value) \(unit)")
                    .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundColor(Pulse.textPrimary)
            }
        }
        .tint(Pulse.hydration)
    }
}

private struct PulsePickerRow: View {
    let label: String
    @Binding var selection: String
    let options: [(value: String, display: String)]

    var body: some View {
        Picker(selection: $selection) {
            ForEach(options, id: \.value) { opt in
                Text(opt.display).tag(opt.value)
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Pulse.textPrimary)
        }
        .tint(Pulse.hydration)
    }
}

private struct PulseTargetPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Pulse.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Pulse.Radius.sm))
    }
}//
//  ProfileSwitcherView.swift
//  Paya
//
//  Created by Emin Huseynzade on 11.07.26.
//

