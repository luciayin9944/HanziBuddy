import AVFoundation

enum SpeechServiceError: LocalizedError {
    case emptyText
    case mandarinVoiceUnavailable
    case audioUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyText:
            "There is no Chinese text to play."
        case .mandarinVoiceUnavailable:
            "A Mandarin voice is not available on this device."
        case .audioUnavailable:
            "Audio is unavailable right now. Please try again."
        }
    }
}

@MainActor
final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    /// An example word gives the Mandarin voice context for polyphonic characters.
    func playPronunciation(character: String, exampleWord: String? = nil) throws {
        let text = (exampleWord?.isEmpty == false ? exampleWord : nil) ?? character
        try play(text)
    }

    func playWord(_ word: String) throws {
        try play(word)
    }

    private func play(_ text: String) throws {
        guard !text.isEmpty else { throw SpeechServiceError.emptyText }
        guard let voice = AVSpeechSynthesisVoice(language: "zh-CN") else {
            throw SpeechServiceError.mandarinVoiceUnavailable
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: .mixWithOthers
            )
        } catch {
            throw SpeechServiceError.audioUnavailable
        }

        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.45
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
