import AppKit

/// Short audio cues so the user always knows whether the app is actually
/// listening. All cues respect the "Sound cues" setting and use macOS
/// system sounds (no bundled assets).
enum SoundCues {
    /// Recording actually started — you are being heard.
    static func start() { play("Tink") }
    /// Normal stop: the hotkey was released.
    static func stop() { play("Pop") }
    /// Recording ended for any reason OTHER than the hotkey being
    /// released: recording cap, audio device lost, engine failure.
    static func interrupted() { play("Sosumi") }
    /// Transcription came back empty (silence or a dead microphone).
    static func nothingCaptured() { play("Funk") }
    /// A press was ignored (busy) or recording failed to start.
    static func error() { play("Basso") }

    private static func play(_ name: String) {
        guard UserDefaults.standard.object(forKey: SettingsStore.soundCuesKey) as? Bool ?? true else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
}
