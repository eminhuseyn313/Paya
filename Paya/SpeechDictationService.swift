import Foundation
import Speech
import AVFoundation
import Observation

// MARK: - Speech Dictation Service
//
// A real in-app microphone button for "Describe a food" — the earlier
// design assumed the iOS keyboard's built-in dictation mic would cover
// this, but that requires the user to notice a tiny keyboard glyph, needs
// Settings > General > Keyboard > Enable Dictation turned on, and Paya
// never declared microphone/speech permissions at all, so it may not have
// even been offered. This does live on-device-preferred transcription via
// SFSpeechRecognizer, with an explicit start/stop button in the app itself.

@Observable
@MainActor
final class SpeechDictationService: NSObject {

    enum DictationError: LocalizedError {
        case notAuthorized
        case recognizerUnavailable

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Microphone or speech recognition access was denied. Enable it in Settings > Privacy > Speech Recognition."
            case .recognizerUnavailable:
                return "Speech recognition isn't available right now — check your connection and try again."
            }
        }
    }

    private(set) var isRecording = false
    private(set) var errorText: String? = nil

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Called with the live/final transcript as it updates.
    var onTranscriptUpdate: ((String) -> Void)?

    func toggle() {
        if isRecording {
            stop()
        } else {
            Task { await start() }
        }
    }

    @MainActor
    func start() async {
        errorText = nil

        let speechStatus = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in cont.resume(returning: status) }
        }
        guard speechStatus == .authorized else {
            errorText = DictationError.notAuthorized.localizedDescription
            return
        }

        let micGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in cont.resume(returning: granted) }
        }
        guard micGranted else {
            errorText = DictationError.notAuthorized.localizedDescription
            return
        }

        let match = Self.bestAvailableRecognizer()
        guard let recognizer = match.recognizer, recognizer.isAvailable else {
            errorText = DictationError.recognizerUnavailable.localizedDescription
            return
        }
        self.recognizer = recognizer

        // Apple's on-device Speech framework only supports a fixed list of
        // languages — it doesn't include Azerbaijani (or several other
        // languages) at all, so there's no locale to request even though
        // Gemini itself understands the text fine once typed. Silently
        // falling back to English transcription would just produce garbled
        // text with no explanation, which reads as "voice doesn't
        // understand my language" — say so plainly instead and point at
        // typing, which has no such limitation.
        if match.isFallback {
            errorText = "Voice recognition doesn't support \(Locale.autoupdatingCurrent.language.languageCode?.identifier ?? "this language") yet — transcribing in English instead. Type your description for full-language support."
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorText = "Couldn't start the microphone: \(error.localizedDescription)"
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            errorText = "Couldn't start the microphone: \(error.localizedDescription)"
            return
        }

        isRecording = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // This callback isn't guaranteed to land on the main thread —
            // mutating SwiftUI @State from off-main can silently drop the
            // update (or race with the next render and appear to erase
            // whatever was just typed), so every touch of self here is
            // hopped onto the main actor explicitly.
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.onTranscriptUpdate?(result.bestTranscription.formattedString)
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stop()
                }
            }
        }
    }

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Was hardcoded to en-US regardless of what language the user actually
    /// speaks or has their device set to — Gemini itself understands
    /// Azerbaijani (and plenty else) fine, so the transcription step was the
    /// only thing forcing English. Tries the device's actual language first,
    /// then a plain language-code match (ignoring region) against Apple's
    /// supported dictation locales, before falling back to English.
    private static func bestAvailableRecognizer() -> (recognizer: SFSpeechRecognizer?, isFallback: Bool) {
        let deviceLocale = Locale.autoupdatingCurrent
        if let recognizer = SFSpeechRecognizer(locale: deviceLocale), recognizer.isAvailable {
            return (recognizer, false)
        }

        let supported = SFSpeechRecognizer.supportedLocales()
        if let languageCode = deviceLocale.language.languageCode?.identifier,
           let match = supported.first(where: { $0.language.languageCode?.identifier == languageCode }),
           let recognizer = SFSpeechRecognizer(locale: match), recognizer.isAvailable {
            return (recognizer, false)
        }

        // Nothing matched the device's language at all — Apple simply
        // doesn't support it for on-device Speech recognition. This is the
        // one case that's a real fallback, not a match.
        return (SFSpeechRecognizer(locale: Locale(identifier: "en-US")), true)
    }
}
