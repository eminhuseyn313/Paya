import SwiftUI
import SwiftData

// MARK: - Ask Paya
//
// Conversational entry point over the user's own data — see
// AskPayaEngine.swift for the context assembly and AI routing.

struct AskPayaView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var messages: [AskPayaEngine.ChatMessage] = []
    @State private var inputText = ""
    @State private var isThinking = false
    @State private var speech = SpeechDictationService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if messages.isEmpty {
                    emptyState
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(messages) { message in
                                    bubble(message)
                                        .id(message.id)
                                }
                                if isThinking {
                                    HStack(spacing: 8) {
                                        ProgressView().tint(Pulse.ai)
                                        Text("Thinking…")
                                            .font(.caption)
                                            .foregroundColor(Pulse.textTertiary)
                                    }
                                    .padding(.leading, 4)
                                }
                            }
                            .padding(16)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let last = messages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }
                }

                inputBar
            }
            .background(Pulse.canvasFallback.ignoresSafeArea())
            .navigationTitle("Ask Paya")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: speech.isRecording) { _, recording in
            if !recording, !inputText.isEmpty {
                // Recognition finalized — leave the transcribed text in the
                // field for the user to review/edit before sending, rather
                // than auto-sending on stop.
            }
        }
        .onAppear {
            speech.onTranscriptUpdate = { text in inputText = text }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(Pulse.ai)
            Text("Ask about your own data")
                .font(.headline)
            Text("\"Why do I feel worse on Mondays?\" · \"Is my sleep actually improving?\" · \"Should I train today?\"")
                .font(.caption)
                .foregroundColor(Pulse.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
            Spacer()
        }
    }

    private func bubble(_ message: AskPayaEngine.ChatMessage) -> some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }
            Text(message.text)
                .font(.subheadline)
                .foregroundColor(message.isUser ? .white : Pulse.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.isUser ? Pulse.ai : Pulse.surfaceFallback)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            if !message.isUser { Spacer(minLength: 40) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            Button {
                speech.toggle()
            } label: {
                Image(systemName: speech.isRecording ? "mic.fill" : "mic")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(speech.isRecording ? .white : Pulse.ai)
                    .frame(width: 36, height: 36)
                    .background(speech.isRecording ? Pulse.ai : Pulse.ai.opacity(0.12))
                    .clipShape(Circle())
            }

            TextField("Ask something…", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Pulse.surfaceFallback)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? Pulse.textTertiary : Pulse.ai)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
        }
        .padding(12)
    }

    private func send() {
        let question = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        if speech.isRecording { speech.stop() }
        inputText = ""

        let userMessage = AskPayaEngine.ChatMessage(isUser: true, text: question)
        let historySnapshot = messages
        messages.append(userMessage)
        isThinking = true

        Task {
            let answer = await AskPayaEngine.ask(
                question: question,
                history: historySnapshot,
                context: modelContext,
                appState: appState
            )
            isThinking = false
            messages.append(.init(isUser: false, text: answer ?? "Couldn't get an answer just now — try again in a moment."))
        }
    }
}
