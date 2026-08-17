import SwiftUI
import SwiftData

// MARK: - Describe a Food (Gemini)
// Write or dictate (tap the keyboard's mic) a free-text food description —
// "two scrambled eggs and a slice of toast with butter" — and get an
// estimated protein/calorie breakdown back, without needing an exact
// product match in the barcode/search database.

struct DescribeFoodCard: View {
    var onOpen: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Pulse.ai.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .scaleEffect(pulse ? 1.06 : 1.0)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Pulse.ai)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Voice log")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Pulse.textPrimary)
                    Text("\"I had two eggs and toast\" — we estimate the rest")
                        .font(.caption2)
                        .foregroundColor(Pulse.textTertiary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Pulse.ai.opacity(0.6))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Pulse.ai.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Pulse.ai.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PulsePress())
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct DescribeFoodView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    var vm: NutritionViewModel

    @State private var description: String = ""
    @State private var isLoading = false
    @State private var estimate: GeminiFoodService.Estimate? = nil
    @State private var errorText: String? = nil
    @FocusState private var isFocused: Bool
    @State private var recorder = AudioRecorderService()
    @State private var isTranscribing = false
    @State private var micPulse = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if appState.geminiAPIKey.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "key.slash")
                            .font(.system(size: 32))
                            .foregroundColor(Pulse.textTertiary)
                        Text("Add a free Gemini API key in Settings to use this.")
                            .font(.subheadline)
                            .foregroundColor(Pulse.textTertiary)
                            .multilineTextAlignment(.center)
                        Text("Google AI Studio gives free API keys with a generous daily limit — no card required.")
                            .font(.caption2)
                            .foregroundColor(Pulse.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 24)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("What did you eat?")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button {
                                if recorder.isRecording {
                                    micPulse = false
                                    Task { await stopAndTranscribe() }
                                } else {
                                    isFocused = false
                                    Task {
                                        await recorder.start()
                                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                            micPulse = true
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if isTranscribing {
                                        SwiftUI.ProgressView().tint(Pulse.ai)
                                    } else {
                                        Image(systemName: recorder.isRecording ? "waveform" : "mic")
                                    }
                                    Text(isTranscribing ? "Processing…" : (recorder.isRecording ? "Tap to stop" : "Speak"))
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundColor(recorder.isRecording ? .white : Pulse.ai)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(recorder.isRecording ? Pulse.ai : Pulse.ai.opacity(0.12))
                                .clipShape(Capsule())
                                .scaleEffect(recorder.isRecording && micPulse ? 1.05 : 1.0)
                            }
                            .disabled(isTranscribing || isLoading)
                            .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Speak a food description, any language")
                        }
                        TextEditor(text: $description)
                            .frame(height: 90)
                            .payaCard(padding: 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(recorder.isRecording ? Pulse.ai : .clear, lineWidth: 2)
                            )
                            .focused($isFocused)
                        Text("Tap Speak and talk in any language, or type directly.")
                            .font(.caption2)
                            .foregroundColor(Pulse.textTertiary)
                        if let recorderError = recorder.errorText {
                            Text(recorderError)
                                .font(.caption2)
                                .foregroundColor(Pulse.critical)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Button {
                        Task { await runEstimate() }
                    } label: {
                        if isLoading {
                            SwiftUI.ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        } else {
                            Text("Estimate")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Pulse.ai)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    .padding(.horizontal, 16)

                    if let errorText {
                        Text(errorText)
                            .font(.caption)
                            .foregroundColor(Pulse.critical)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    if let estimate {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(estimate.foodName)
                                .font(.headline)
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(Int(estimate.proteinG))g")
                                        .font(.title3.bold())
                                        .foregroundColor(Pulse.hydration)
                                    Text("protein")
                                        .font(.caption2)
                                        .foregroundColor(Pulse.textTertiary)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(Int(estimate.calories))")
                                        .font(.title3.bold())
                                        .foregroundColor(Pulse.warning)
                                    Text("kcal")
                                        .font(.caption2)
                                        .foregroundColor(Pulse.textTertiary)
                                }
                            }
                            MicronutrientChips(estimate: estimate)

                            if !estimate.confidence.isEmpty {
                                Text(estimate.confidence)
                                    .font(.caption2)
                                    .foregroundColor(Pulse.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Button {
                                vm.addMeal(
                                    name: "Meal",
                                    food: estimate.foodName,
                                    protein: estimate.proteinG,
                                    calories: estimate.calories,
                                    context: modelContext,
                                    estimate: estimate
                                )
                                dismiss()
                            } label: {
                                Text("Log this")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Pulse.positive)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .payaCard(padding: 14)
                        .padding(.horizontal, 16)
                    }
                }

                Spacer()
            }
            .padding(.top, 8)
            .navigationTitle("Describe a Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            isFocused = true
        }
        .onDisappear { _ = recorder.stop() }
    }

    private func stopAndTranscribe() async {
        guard let audioData = recorder.stop() else { return }
        isTranscribing = true
        errorText = nil
        do {
            let transcript = try await GeminiFoodService.transcribe(audioData: audioData, apiKey: appState.geminiAPIKey)
            let separator = description.trimmingCharacters(in: .whitespaces).isEmpty ? "" : " "
            description += separator + transcript
            isTranscribing = false
            await runEstimate()
        } catch {
            errorText = error.localizedDescription
            isTranscribing = false
        }
    }

    private func runEstimate() async {
        isLoading = true
        errorText = nil
        estimate = nil
        do {
            estimate = try await GeminiFoodService.estimate(description: description, apiKey: appState.geminiAPIKey)
        } catch {
            errorText = error.localizedDescription
        }
        isLoading = false
    }
}
