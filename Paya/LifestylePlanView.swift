import SwiftUI
import SwiftData

// MARK: - Lifestyle Plan
// The AI synthesis of every questionnaire answer — nutrition, supplements,
// and lifestyle guidance as one coherent, personalized narrative rather
// than three disconnected static lookups.

struct LifestylePlanCard: View {
    var profile: PersonProfile
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "8B5CF6").opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkles")
                        .foregroundColor(Color(hex: "8B5CF6"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.cachedLifestylePlan == nil ? "Get your lifestyle plan" : "Your lifestyle plan")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(profile.cachedLifestylePlan == nil
                         ? "AI-generated nutrition, supplements & recovery guidance from your profile"
                         : "Nutrition, supplements & recovery — tap to review or regenerate")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .payaCard(padding: 14)
        }
        .buttonStyle(.plain)
    }
}

struct LifestylePlanView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var profile: PersonProfile

    @State private var isGenerating = false
    @State private var errorText: String? = nil

    var sections: [(title: String, icon: String, color: String, body: String)] {
        guard let plan = profile.cachedLifestylePlan else { return [] }
        var result: [(String, String, String, String)] = []
        let markers: [(String, String, String, String)] = [
            ("NUTRITION:", "Nutrition", "059669", "fork.knife"),
            ("SUPPLEMENTS:", "Supplements", "D97706", "pills.fill"),
            ("LIFESTYLE:", "Lifestyle", "2563EB", "moon.stars.fill")
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
                    if profile.cachedLifestylePlan == nil && !isGenerating {
                        VStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 36))
                                .foregroundColor(Color(hex: "8B5CF6"))
                            Text("Your goal, experience, equipment, diet, sleep, and stress — synthesized into one plan.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 30)
                        .padding(.horizontal, 24)
                    }

                    if isGenerating {
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Thinking through your profile…")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.caption)
                            .foregroundColor(Color(hex: "DC2626"))
                            .padding(.horizontal, 20)
                    }

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
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .payaCard(padding: 14)
                        .padding(.horizontal, 20)
                    }

                    if let date = profile.lifestylePlanGeneratedAt {
                        let daysSince = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
                        Text("Generated \(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if daysSince >= 7 {
                            Text("A week of real logging has happened since — regenerate to reflect it")
                                .font(.caption2)
                                .foregroundColor(Color(hex: "B45309"))
                        }
                    }

                    Button {
                        Task { await generate() }
                    } label: {
                        Text(profile.cachedLifestylePlan == nil ? "Generate my plan" : "Regenerate")
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(isGenerating ? Color.secondary.opacity(0.4) : Color(hex: "8B5CF6"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isGenerating)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)

                    Spacer().frame(height: 20)
                }
                .padding(.top, 10)
            }
            .navigationTitle("Lifestyle Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func generate() async {
        isGenerating = true
        errorText = nil
        let result = await LifestylePlanEngine.generate(profile: profile, context: modelContext, apiKey: appState.anthropicAPIKey)
        if result != nil {
            try? modelContext.save()
        } else {
            errorText = AIService.shared.lastError ?? "Couldn't generate a plan right now — check your connection or Apple Intelligence availability."
        }
        isGenerating = false
    }
}
