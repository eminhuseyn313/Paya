import SwiftUI
import SwiftData

// MARK: - AI Training Coach
// Reads plateau flags, weekly volume-landmark zones, and deload status —
// all already computed elsewhere in the app — and asks AI to turn that into
// a short, specific recommendation. Rebuilding the program itself runs back
// through TrainingScienceEngine/ProgramAssembler (see TrainingCoachEngine),
// not through anything the AI writes directly.

struct TrainingCoachCard: View {
    var profile: PersonProfile
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "2563EB").opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(Color(hex: "2563EB"))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.cachedCoachRecommendation == nil ? "Get an AI training review" : "Your training review")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(profile.cachedCoachRecommendation == nil
                         ? "Reads your plateaus, volume, and recovery to recommend what to change"
                         : "Tap to review or regenerate")
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

struct TrainingCoachView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var profile: PersonProfile
    var onProgramRebuilt: () -> Void

    @State private var isGenerating = false
    @State private var errorText: String? = nil
    @State private var isRebuilding = false
    @State private var rebuiltMessage: String? = nil
    @State private var didRebuild = false

    private var suggestedMuscle: MusclePriority? {
        let pid = ActiveProfile.id
        let weekAgo = Calendar.current.date(byAdding: .day, value: -35, to: .now) ?? .now
        let descriptor = FetchDescriptor<TrainingSession>(
            predicate: #Predicate<TrainingSession> { $0.isCompleted == true && $0.date >= weekAgo && $0.profileId == pid }
        )
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        return TrainingCoachEngine.suggestedPriorityMuscle(sessions: sessions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if profile.cachedCoachRecommendation == nil && !isGenerating {
                        VStack(spacing: 10) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 36))
                                .foregroundColor(Color(hex: "2563EB"))
                            Text("Reads your stalled lifts, weekly volume per muscle, and deload status — grounded in the same data driving the rest of the app.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 30)

                        Button {
                            Task { await generate() }
                        } label: {
                            Text("Review my training")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(hex: "2563EB"))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.top, 8)
                    } else if isGenerating {
                        VStack(spacing: 12) {
                            SwiftUI.ProgressView()
                            Text("Reviewing your recent training…")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 60)
                    } else if let recommendation = profile.cachedCoachRecommendation {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 6) {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(Color(hex: "2563EB"))
                                Text("Training review")
                                    .font(.subheadline.weight(.bold))
                            }
                            Text(recommendation)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .payaCard(padding: 14)

                        if let suggestedMuscle {
                            rebuildCard(target: suggestedMuscle)
                        }

                        if let rebuiltMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(hex: "059669"))
                                Text(rebuiltMessage)
                                    .font(.caption)
                                    .foregroundColor(Color(hex: "059669"))
                            }

                            Button {
                                dismiss()
                            } label: {
                                Text("Done")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: "059669"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.top, 4)
                        }

                        Button {
                            Task { await generate() }
                        } label: {
                            Text("Regenerate")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(Color(hex: "2563EB"))
                        }
                        .padding(.top, 4)
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.caption)
                            .foregroundColor(Color(hex: "DC2626"))
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .navigationTitle("AI Training Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onDisappear {
                if didRebuild { onProgramRebuilt() }
            }
        }
    }

    private func rebuildCard(target: MusclePriority) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(Color(hex: "B45309"))
                Text("\(target.displayName) is under your minimum effective weekly volume")
                    .font(.caption.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Rebuilding adds a \(target.displayName.lowercased())-focused slot to your program using the same generator onboarding uses — your logged history and PRs aren't affected.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                rebuild(target: target)
            } label: {
                if isRebuilding {
                    SwiftUI.ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                } else {
                    Text("Rebuild program with \(target.displayName) focus")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color(hex: "B45309"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .disabled(isRebuilding)
        }
        .padding(14)
        .background(Color(hex: "B45309").opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "B45309").opacity(0.2), lineWidth: 1))
    }

    private func generate() async {
        isGenerating = true
        errorText = nil
        let result = await TrainingCoachEngine.generateRecommendation(
            profile: profile, context: modelContext, apiKey: appState.anthropicAPIKey
        )
        if result == nil {
            errorText = AIService.shared.lastError ?? "Couldn't generate a recommendation right now."
        }
        try? modelContext.save()
        isGenerating = false
    }

    private func rebuild(target: MusclePriority) {
        isRebuilding = true
        TrainingCoachEngine.rebuildProgram(profile: profile, context: modelContext, priorityMuscle: target)
        try? modelContext.save()
        isRebuilding = false
        rebuiltMessage = "Program rebuilt with \(target.displayName) focus."
        didRebuild = true
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
