import AVFoundation
import SwiftUI

/// Reads news copy aloud using the system speech synthesiser. Free, ships
/// today. Upgrade path to ElevenLabs is documented in V1.1_FEATURE_BUNDLE.md
/// (deferred to v1.2 or v2).
@Observable
final class AudioPlayerService: NSObject {
    static let shared = AudioPlayerService()

    enum PlaybackState { case idle, playing, paused }
    private(set) var state: PlaybackState = .idle

    private let synth = AVSpeechSynthesizer()

    override init() {
        super.init()
        synth.delegate = self
    }

    /// Speak from the start. Stops any in-flight utterance first.
    func speak(_ text: String) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52
        synth.speak(utterance)
        state = .playing
    }

    func pause() {
        synth.pauseSpeaking(at: .word)
        state = .paused
    }

    func resume() {
        synth.continueSpeaking()
        state = .playing
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        state = .idle
    }
}

extension AudioPlayerService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        state = .idle
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        state = .idle
    }
}
