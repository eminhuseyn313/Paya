import Foundation
import AVFoundation
import Observation

// MARK: - Audio Recorder Service
//
// Records a short clip to a temp file for cloud transcription instead of
// live on-device recognition. This exists specifically because Apple's
// SFSpeechRecognizer (SpeechDictationService) has a fixed, Apple-controlled
// list of supported languages that does NOT include Azerbaijani (or several
// others) — no amount of app code can add a language to that list. Gemini's
// audio understanding has no such restriction, so for "Describe a Food"
// this replaces live partial transcripts with record-then-transcribe: a
// small UX trade-off (no live text while speaking) for actually working in
// the user's own language.

@Observable
@MainActor
final class AudioRecorderService: NSObject {

    enum RecorderError: LocalizedError {
        case notAuthorized
        case recordingFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Microphone access was denied. Enable it in Settings > Privacy > Microphone."
            case .recordingFailed(let detail):
                return "Couldn't record audio: \(detail)"
            }
        }
    }

    private(set) var isRecording = false
    private(set) var errorText: String? = nil

    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    func start() async {
        errorText = nil

        let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in cont.resume(returning: granted) }
        }
        guard granted else {
            errorText = RecorderError.notAuthorized.localizedDescription
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            errorText = RecorderError.recordingFailed(error.localizedDescription).localizedDescription
            return
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.record()
            self.recorder = recorder
            self.fileURL = url
            isRecording = true
        } catch {
            errorText = RecorderError.recordingFailed(error.localizedDescription).localizedDescription
        }
    }

    /// Stops recording and returns the recorded clip's data, or nil if
    /// nothing was recorded / recording failed.
    func stop() -> Data? {
        recorder?.stop()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard let fileURL else { return nil }
        defer {
            try? FileManager.default.removeItem(at: fileURL)
            self.fileURL = nil
            self.recorder = nil
        }
        return try? Data(contentsOf: fileURL)
    }
}
