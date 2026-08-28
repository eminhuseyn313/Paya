import SwiftUI

// MARK: - Health Profile Summary
//
// Read-only view of the user's completed Health Journey data and active
// contraindication rules. Shown when tapping the "Health profile active"
// badge on the dashboard — instead of reopening the full questionnaire.
//
// Provides a clear overview of what the app knows about the user's health
// and how it's affecting their nutrition/exercise/supplement recommendations.

struct HealthProfileSummaryView: View {

    @Environment(\.dismiss) private var dismiss
    var profile: PersonProfile
    var onRetakeJourney: () -> Void

    private var report: HealthContraindicationEngine.ContraindicationReport {
        HealthContraindicationEngine.generate(for: profile)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Status hero
                    statusHero

                    // Profile data sections
                    if !profile.chronicConditionsRaw.isEmpty {
                        profileSection(
                            icon: "heart.text.clipboard",
                            title: "Chronic Conditions",
                            items: profile.chronicConditionsRaw,
                            color: Pulse.critical
                        )
                    }

                    if !profile.geneticDisordersRaw.isEmpty {
                        profileSection(
                            icon: "dna",
                            title: "Genetic History",
                            items: profile.geneticDisordersRaw,
                            color: Pulse.ai
                        )
                    }

                    if !profile.allergiesRaw.isEmpty {
                        profileSection(
                            icon: "allergens.fill",
                            title: "Allergies & Intolerances",
                            items: profile.allergiesRaw,
                            color: Pulse.warning
                        )
                    }

                    if !profile.medicationsRaw.isEmpty {
                        profileSection(
                            icon: "pill.fill",
                            title: "Medications",
                            items: profile.medicationsRaw,
                            color: Pulse.hydration
                        )
                    }

                    // Active rules
                    if !report.isEmpty {
                        activeRulesSection
                    }

                    // Lifestyle snapshot
                    lifestyleSnapshot

                    // Update button
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onRetakeJourney()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Update Health Profile")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(Pulse.ai)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Pulse.ai.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Pulse.ai.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                    }
                    .padding(.horizontal, 20)

                    if let date = profile.healthJourneyCompletedAt {
                        Text("Completed \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.system(size: 10))
                            .foregroundColor(Pulse.textTertiary)
                    }

                    Spacer().frame(height: 30)
                }
                .padding(.top, 8)
            }
            .background(Pulse.canvasFallback.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("Health Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Status Hero

    private var statusHero: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Pulse.positive.opacity(0.1))
                    .frame(width: 56, height: 56)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Pulse.positive)
            }

            Text("Health Profile Active")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Pulse.textPrimary)

            Text("\(report.totalCount) personalized rules are guiding your recommendations")
                .font(.system(size: 12))
                .foregroundColor(Pulse.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
    }

    // MARK: - Profile Section

    private func profileSection(icon: String, title: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Pulse.textPrimary)
            }

            FlowLayout(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(color.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .payaCard(padding: 14)
        .padding(.horizontal, 20)
    }

    // MARK: - Active Rules

    private var activeRulesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "shield.checkered")
                    .foregroundColor(Pulse.warning)
                Text("Active Safety Rules")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Pulse.textPrimary)
            }

            ForEach(report.allWarnings.sorted(by: { $0.severity > $1.severity }).prefix(8)) { warning in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: severityIcon(warning.severity))
                        .font(.system(size: 11))
                        .foregroundColor(severityColor(warning.severity))
                        .frame(width: 16, alignment: .center)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(warning.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Pulse.textPrimary)
                        Text(warning.detail)
                            .font(.system(size: 10))
                            .foregroundColor(Pulse.textSecondary)
                        Text(warning.source)
                            .font(.system(size: 9))
                            .foregroundColor(Pulse.textTertiary)
                    }
                    Spacer()
                }
                .padding(.vertical, 3)
            }
        }
        .payaCard(padding: 14)
        .padding(.horizontal, 20)
    }

    private func severityIcon(_ severity: HealthContraindicationEngine.Warning.Severity) -> String {
        switch severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .caution: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private func severityColor(_ severity: HealthContraindicationEngine.Warning.Severity) -> Color {
        switch severity {
        case .critical: return Pulse.critical
        case .warning: return Pulse.warning
        case .caution: return Pulse.nutrition
        case .info: return Pulse.hydration
        }
    }

    // MARK: - Lifestyle Snapshot

    private var lifestyleSnapshot: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .foregroundColor(Pulse.recovery)
                Text("Lifestyle")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Pulse.textPrimary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                lifestyleItem(icon: "🩸", label: "Blood Type", value: profile.bloodTypeRaw.isEmpty ? "—" : profile.bloodTypeRaw)
                lifestyleItem(icon: "💼", label: "Activity", value: occupationLabel)
                lifestyleItem(icon: "🚬", label: "Smoking", value: profile.smokingStatusRaw.capitalized)
                lifestyleItem(icon: "🍷", label: "Alcohol", value: profile.alcoholFrequencyRaw.capitalized)
            }
        }
        .payaCard(padding: 14)
        .padding(.horizontal, 20)
    }

    private func lifestyleItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(icon)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Pulse.textTertiary)
                Text(value)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Pulse.textPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
    }

    private var occupationLabel: String {
        switch profile.occupationTypeRaw {
        case "active": return "Active"
        case "veryActive": return "Very Active"
        case "shiftWork": return "Shift Work"
        default: return "Sedentary"
        }
    }
}

// FlowLayout is defined in ReflectionSheet.swift — reused here for tag chips.
