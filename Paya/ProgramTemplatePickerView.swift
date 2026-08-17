import SwiftUI
import SwiftData

struct ProgramTemplatePickerView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    var onInstalled: () -> Void

    @State private var selectedTier: ProgramTier = .intermediate
    @State private var templateToInstall: ProgramTemplate? = nil
    @State private var showConfirm = false
    @State private var personProfile: PersonProfile? = nil

    private var goalTemplates: [ProgramTemplate] {
        ProgramTemplates.templates(for: appState.profile.goal, tier: selectedTier)
    }

    private var otherTemplates: [ProgramTemplate] {
        ProgramTemplates.all.filter {
            $0.tier == selectedTier && $0.goal != appState.profile.goal
        }
    }

    private var recommendation: TrainingScienceEngine.Recommendation? {
        guard let p = personProfile else { return nil }
        return TrainingScienceEngine.recommend(
            goal: p.goal,
            experience: p.experienceLevel,
            equipment: p.equipmentAccess,
            injuries: p.injuryFlags,
            daysPerWeek: p.preferredTrainingDaysPerWeek,
            priorityMuscle: p.priorityMuscle,
            sexRaw: p.sexRaw
        )
    }

    private func install(_ template: ProgramTemplate) {
        let adjustment = personProfile.map {
            TrainingScienceEngine.recommend(
                goal: template.goal,
                experience: $0.experienceLevel,
                equipment: $0.equipmentAccess,
                injuries: $0.injuryFlags,
                daysPerWeek: template.daysPerWeek,
                priorityMuscle: $0.priorityMuscle,
                sexRaw: $0.sexRaw
            )?.volumeAdjustment
        } ?? nil
        ProgramInstaller.install(template, context: modelContext, volumeAdjustment: adjustment ?? nil)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onInstalled()
        dismiss()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {

                    if let rec = recommendation {
                        RecommendedProgramCard(recommendation: rec, profile: personProfile, onInstall: { install(rec.template) })
                    }

                    HStack {
                        Text("Browse all programs")
                            .font(.caption.weight(.bold))
                            .foregroundColor(Pulse.textTertiary)
                        Spacer()
                    }
                    .padding(.top, recommendation != nil ? 4 : 0)

                    // Tier selector
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            ForEach(ProgramTier.allCases) { tier in
                                Button {
                                    withAnimation(.spring(response: 0.25)) {
                                        selectedTier = tier
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    VStack(spacing: 3) {
                                        Image(systemName: tier.icon)
                                            .font(.caption)
                                        Text(tier.displayName)
                                            .font(.caption.weight(.semibold))
                                    }
                                    .foregroundColor(selectedTier == tier ? .white : .primary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedTier == tier
                                        ? Pulse.hydration
                                        : Pulse.surfaceFallback)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        Text(selectedTier.subtitle)
                            .font(.caption2)
                            .foregroundColor(Pulse.textTertiary)
                    }

                    // Goal-matched templates
                    if !goalTemplates.isEmpty {
                        HStack {
                            Image(systemName: appState.profile.goal.icon)
                                .foregroundColor(appState.profile.goal.color)
                            Text("For your goal · \(appState.profile.goal.displayName)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(Pulse.textTertiary)
                            Spacer()
                        }
                        ForEach(goalTemplates) { template in
                            TemplateCardV2(template: template) {
                                templateToInstall = template
                                showConfirm = true
                            }
                        }
                    } else {
                        Text("No \(selectedTier.displayName.lowercased()) template for \(appState.profile.goal.displayName) yet — check another tier.")
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }

                    // Other goals at this tier
                    if !otherTemplates.isEmpty {
                        HStack {
                            Text("Other goals")
                                .font(.caption.weight(.bold))
                                .foregroundColor(Pulse.textTertiary)
                            Spacer()
                        }
                        .padding(.top, 8)
                        ForEach(otherTemplates) { template in
                            TemplateCardV2(template: template) {
                                templateToInstall = template
                                showConfirm = true
                            }
                        }
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Programs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                personProfile = ProfileStore.current(context: modelContext)
            }
            .alert("Install \(templateToInstall?.name ?? "program")?", isPresented: $showConfirm) {
                Button("Cancel", role: .cancel) { templateToInstall = nil }
                Button("Install", role: .destructive) {
                    if let template = templateToInstall {
                        install(template)
                    }
                }
            } message: {
                Text("This replaces your current training days and exercise compositions. Session history is kept.")
            }
        }
    }
}

// MARK: - Recommended Program Card

struct RecommendedProgramCard: View {
    let recommendation: TrainingScienceEngine.Recommendation
    let profile: PersonProfile?
    let onInstall: () -> Void

    @State private var showWhy = false
    @State private var showScience = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(Pulse.ai)
                Text("Recommended for you")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Pulse.ai)
                Spacer()
                if !recommendation.exactDayMatch {
                    Text("closest fit")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(Pulse.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Pulse.surfaceElevatedFallback)
                        .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(recommendation.template.name)
                    .font(.headline.weight(.bold))
                Text("\(recommendation.daysPerWeek)×/week · \(recommendation.template.goal.displayName)")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
            }

            Button {
                withAnimation(.spring(response: 0.3)) { showWhy.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text(showWhy ? "Hide reasoning" : "Why this plan?")
                    Image(systemName: showWhy ? "chevron.up" : "chevron.down")
                }
                .font(.caption.weight(.semibold))
                .foregroundColor(Pulse.ai)
            }

            if showWhy {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(recommendation.rationale, id: \.self) { line in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Pulse.ai)
                                .padding(.top, 2)
                            Text(line)
                                .font(.caption)
                                .foregroundColor(Pulse.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(10)
                .background(Pulse.ai.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 8) {
                if profile != nil {
                    Button {
                        showScience = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile.fill")
                                .font(.system(size: 11))
                            Text("The science")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(Pulse.ai)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Pulse.ai.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                Button(action: onInstall) {
                    Text("Use this plan")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Pulse.ai)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .payaCard(padding: 14)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Pulse.ai.opacity(0.3), lineWidth: 1.5)
        )
        .sheet(isPresented: $showScience) {
            if let profile {
                ProgramScienceView(recommendation: recommendation, profile: profile)
            }
        }
    }
}

// MARK: - Template Card

struct TemplateCardV2: View {
    let template: ProgramTemplate
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(template.goal.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: template.goal.icon)
                        .foregroundColor(template.goal.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.subheadline.weight(.bold))
                    HStack(spacing: 6) {
                        Text("\(template.daysPerWeek)×/week")
                            .font(.caption)
                            .foregroundColor(Pulse.textTertiary)
                        Text("·")
                            .foregroundColor(Pulse.textTertiary)
                        HStack(spacing: 3) {
                            Image(systemName: template.tier.icon)
                                .font(.system(size: 9))
                            Text(template.tier.displayName)
                                .font(.caption)
                        }
                        .foregroundColor(template.goal.color)
                    }
                }
                Spacer()
            }

            // Day chips
            HStack(spacing: 6) {
                ForEach(template.days, id: \.code) { day in
                    Text(day.code)
                        .font(.caption2.weight(.bold))
                        .foregroundColor(Color(hex: day.colorHex))
                        .frame(width: 26, height: 26)
                        .background(Color(hex: day.colorHex).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                Spacer()
                Text("\(template.days.reduce(0) { $0 + $1.exercises.count }) exercises")
                    .font(.caption2)
                    .foregroundColor(Pulse.textTertiary)
            }

            Text(template.summary)
                .font(.caption)
                .foregroundColor(Pulse.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onApply) {
                Text("Apply this program")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(template.goal.color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .payaCard(padding: 14)
    }
}
