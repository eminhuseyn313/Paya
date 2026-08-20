import SwiftUI
import SwiftData

// MARK: - Symptom Diet Plan
//
// AI-generated anti-inflammatory diet recommendations based on the
// user's actual logged symptoms, flare days, joint pain, digestive
// patterns, and current nutrition. Card triggers the full sheet view.

struct SymptomDietCard: View {
    var profile: PersonProfile
    var onOpen: () -> Void

    private var hasSymptomData: Bool {
        profile.hasInflammatoryCondition || profile.cachedSymptomDietPlan != nil
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Pulse.recovery.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "leaf.fill")
                        .foregroundColor(Pulse.recovery)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.cachedSymptomDietPlan == nil ? "Get your diet plan" : "Your diet plan")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Pulse.textPrimary)
                    Text(profile.cachedSymptomDietPlan == nil
                         ? "AI anti-inflammatory diet guidance based on your symptom logs"
                         : "Anti-inflammatory foods, meals & timing — tap to review or regenerate")
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Pulse.textTertiary)
            }
            .payaCard(padding: 14)
        }
        .buttonStyle(PulsePress())
    }
}

// MARK: - Full View

struct SymptomDietPlanView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var profile: PersonProfile

    @State private var isGenerating = false
    @State private var errorText: String? = nil

    private var sections: [(title: String, icon: String, color: String, body: String)] {
        guard let plan = profile.cachedSymptomDietPlan else { return [] }
        var result: [(String, String, String, String)] = []
        let markers: [(String, String, String, String)] = [
            ("ANTI-INFLAMMATORY FOODS:", "Prioritize", "059669", "leaf.fill"),
            ("FOODS TO LIMIT:", "Limit", "DC2626", "xmark.circle.fill"),
            ("MEAL IDEAS:", "Meals", "2563EB", "fork.knife"),
            ("TIMING & HABITS:", "Timing", "D97706", "clock.fill")
        ]
        for (index, marker) in markers.enumerated() {
            guard let range = plan.range(of: marker.0) else { continue }
            let start = range.upperBound
            let end = markers[(index + 1)...].compactMap { plan.range(of: $0.0)?.lowerBound }.first ?? plan.endIndex
            let body = String(plan[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }
            result.append((marker.1, marker.3, marker.2, body))
        }
        return result.map { (title: $0.0, icon: $0.1, color: $0.2, body: $0.3) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Empty state
                    if profile.cachedSymptomDietPlan == nil && !isGenerating {
                        VStack(spacing: 10) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 36))
                                .foregroundColor(Pulse.recovery)
                            Text("Your symptoms, flare history, joint pain, and nutrition — analyzed for personalized anti-inflammatory diet guidance.")
                                .font(.subheadline)
                                .foregroundColor(Pulse.textTertiary)
                                .multilineTextAlignment(.center)

                            // Data snapshot
                            symptomDataSnapshot
                        }
                        .padding(.top, 30)
                        .padding(.horizontal, 24)
                    }

                    // Loading
                    if isGenerating {
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Analyzing your symptom patterns…")
                                .font(.caption)
                                .foregroundColor(Pulse.textTertiary)
                        }
                        .padding(.top, 40)
                    }

                    // Error
                    if let errorText {
                        Text(errorText)
                            .font(.caption)
                            .foregroundColor(Pulse.critical)
                            .padding(.horizontal, 20)
                    }

                    // Sections
                    ForEach(sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: section.icon)
                                    .foregroundColor(Color(hex: section.color))
                                Text(section.title)
                                    .font(.subheadline.weight(.bold))
                            }
                            Text(section.body)
                                .font(.subheadline)
                                .foregroundColor(Pulse.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .payaCard(padding: 14)
                        .padding(.horizontal, 20)
                    }

                    // Disclaimer
                    if profile.cachedSymptomDietPlan != nil {
                        Text("This is nutrition guidance, not medical advice. Consult your healthcare provider for condition-specific dietary treatment.")
                            .font(.system(size: 10))
                            .foregroundColor(Pulse.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }

                    // Timestamp
                    if let date = profile.symptomDietPlanGeneratedAt {
                        let daysSince = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
                        Text("Generated \(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundColor(Pulse.textTertiary)
                        if daysSince >= 7 {
                            Text("New symptom data since then — regenerate for updated guidance")
                                .font(.caption2)
                                .foregroundColor(Pulse.warning)
                        }
                    }

                    // Generate button
                    Button {
                        Task { await generate() }
                    } label: {
                        Text(profile.cachedSymptomDietPlan == nil ? "Generate my diet plan" : "Regenerate")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(isGenerating ? Color.secondary.opacity(0.4) : Pulse.recovery)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isGenerating)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)

                    Spacer().frame(height: 20)
                }
                .padding(.top, 10)
            }
            .background(Pulse.canvasFallback.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("Diet Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Data Snapshot

    /// Shows the user what data the engine will use, so they know
    /// the recommendation isn't arbitrary.
    @ViewBuilder
    private var symptomDataSnapshot: some View {
        let symptoms = SymptomStore.recent(daysBack: 14, context: modelContext)
        let hasSymptoms = !symptoms.isEmpty

        VStack(spacing: 8) {
            HStack(spacing: 16) {
                dataChip(
                    icon: "heart.text.clipboard",
                    label: "\(symptoms.count) symptoms",
                    color: hasSymptoms ? Pulse.recovery : Pulse.textTertiary
                )
                if profile.hasInflammatoryCondition {
                    dataChip(
                        icon: "flame.fill",
                        label: "Inflammatory",
                        color: Pulse.warning
                    )
                }
            }
            if !hasSymptoms && !profile.hasInflammatoryCondition {
                Text("Log symptoms in the Health tab to get more personalized results")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Pulse.textTertiary)
            }
        }
        .padding(.top, 8)
    }

    private func dataChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Generate

    private func generate() async {
        isGenerating = true
        errorText = nil
        let result = await SymptomDietEngine.generate(profile: profile, context: modelContext, apiKey: appState.anthropicAPIKey)
        if result != nil {
            try? modelContext.save()
        } else {
            errorText = AIService.shared.lastError ?? "Couldn't generate a diet plan right now — check your connection or Apple Intelligence availability."
        }
        isGenerating = false
    }
}
