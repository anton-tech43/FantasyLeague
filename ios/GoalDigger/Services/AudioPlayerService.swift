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
    /// The utterance playing now. A replaced or stopped one still reports
    /// didCancel afterwards, and must not reset the state of the one after it.
    private var current: AVSpeechUtterance?
    /// Ours to hand back. Every detail screen calls stop() on disappear, and
    /// most never spoke, so this keeps those from touching the session.
    private var sessionActive = false

    override init() {
        super.init()
        synth.delegate = self
    }

    /// Speak from the start. Stops any in-flight utterance first.
    func speak(_ text: String) {
        current = nil
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52
        current = utterance
        activateSession()
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
        current = nil
        synth.stopSpeaking(at: .immediate)
        state = .idle
        // May fail while the synthesiser winds down; didCancel tries again.
        deactivateSession()
    }

    // MARK: Audio session

    /// The default session (soloAmbient) is muted by the ring/silent switch, so
    /// Listen played nothing on a phone set to silent (QA NEW-19). Playback is
    /// what she asked for by tapping Listen; spokenAudio pauses a podcast or
    /// audiobook instead of talking over it.
    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        sessionActive = (try? session.setActive(true)) != nil
    }

    /// Hands the audio back: her music or podcast resumes where it stopped.
    private func deactivateSession() {
        guard sessionActive else { return }
        if (try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)) != nil {
            sessionActive = false
        }
    }

    fileprivate func finished(_ utterance: AVSpeechUtterance) {
        if utterance === current {
            current = nil
            state = .idle
        }
        if current == nil { deactivateSession() }
    }
}

extension AudioPlayerService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finished(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        finished(utterance)
    }
}
