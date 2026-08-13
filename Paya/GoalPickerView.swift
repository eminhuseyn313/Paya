import SwiftUI
import SwiftData

struct GoalPickerView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var selected: TrainingGoal = .hypertrophy

    var previewTargets: GoalEngine.Targets {
        GoalEngine.targets(
            goal: selected,
            bodyWeightKg: appState.profile.currentWeightKg,
            age: appState.profile.age,
            heightCm: appState.profile.heightCm,
            sexRaw: appState.profile.sexRaw
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {

                    ForEach(TrainingGoal.allCases, id: \.self) { goal in
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                selected = goal
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(goal.color.opacity(0.15))
                                        .frame(width: 46, height: 46)
                                    Image(systemName: goal.icon)
                                        .font(.title3)
                                        .foregroundColor(goal.color)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(goal.displayName)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(.primary)
                                    Text(goal.summary)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: selected == goal
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .font(.title3)
                                    .foregroundColor(selected == goal ? goal.color : .secondary.opacity(0.4))
                            }
                            .payaCard(padding: 14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(selected == goal ? goal.color : .clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Live preview of derived targets
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your targets on this goal")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            TargetPill(
                                label: "PROTEIN",
                                value: "\(Int(previewTargets.proteinG))g",
                                colorHex: "2563EB"
                            )
                            TargetPill(
                                label: "TRAIN DAY",
                                value: "\(Int(previewTargets.trainingDayCalories)) kcal",
                                colorHex: "059669"
                            )
                            TargetPill(
                                label: "REST DAY",
                                value: "\(Int(previewTargets.restDayCalories)) kcal",
                                colorHex: "D97706"
                            )
                        }

                        if previewTargets.dailyStepTarget != nil || previewTargets.weeklyZone2Minutes != nil {
                            HStack(spacing: 8) {
                                if let steps = previewTargets.dailyStepTarget {
                                    TargetPill(label: "STEPS/DAY", value: "\(steps)", colorHex: "8B5CF6")
                                }
                                if let z2 = previewTargets.weeklyZone2Minutes {
                                    TargetPill(label: "ZONE 2/WK", value: "\(z2)m", colorHex: "0891B2")
                                }
                            }
                        }

                        Text("Effort measured by: \(selected.effortLevers)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .payaCard(padding: 14)

                    Button {
                        apply()
                    } label: {
                        Text("Set goal: \(selected.displayName)")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(selected.color)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Training Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            selected = appState.profile.goal
        }
    }

    private func apply() {
        let targets = GoalEngine.targets(
            goal: selected,
            bodyWeightKg: appState.profile.currentWeightKg,
            age: appState.profile.age,
            heightCm: appState.profile.heightCm,
            sexRaw: appState.profile.sexRaw
        )
        let goalChanged = appState.profile.goal != selected
        appState.profile.goal = selected
        appState.profile.proteinTargetG = targets.proteinG
        appState.profile.trainingDayCalories = targets.trainingDayCalories
        appState.profile.restDayCalories = targets.restDayCalories

        // Write through to the persisted PersonProfile too — appState.profile
        // is only an in-memory mirror; without this, every other screen that
        // reads PersonProfile directly (ProfileSwitcherView, the AI lifestyle
        // plan, AdaptiveCalorieEngine) kept showing the pre-change goal, and
        // the change was silently reverted on next launch.
        if let persisted = ProfileStore.current(context: modelContext) {
            persisted.goal = selected
            persisted.proteinTargetG = targets.proteinG
            persisted.trainingDayCalories = targets.trainingDayCalories
            persisted.restDayCalories = targets.restDayCalories
            try? modelContext.save()
        }

        if goalChanged {
            UserSupplementStore.syncForGoal(selected, context: modelContext)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

struct TargetPill: View {
    let label: String
    let value: String
    let colorHex: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundColor(Color(hex: colorHex))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(hex: colorHex).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}//
//  GoalPickerView.swift
//  Paya
//
//  Created by Emin Huseynzade on 11.07.26.
//

