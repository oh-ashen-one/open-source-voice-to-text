import Foundation
import AVFoundation
import Combine

/// Central state machine: owns the recorder + transcriber and drives the
/// pill UI state. All state mutations happen on the main actor.
@MainActor
final class AppController: ObservableObject {

    enum State: Equatable {
        case downloadingModel
        case idle
        case recording
        case transcribing
        case pasted           // text inserted into the focused app
        case copiedOnly       // clipboard only (no Accessibility permission)
        case error(String)

        var isError: Bool {
            if case .error = self { return true }
            return false
        }
    }

    /// Maximum recording length before auto-stop (seconds). Prevents an
    /// accidentally held key from buffering audio indefinitely.
    static let recordingLimit: TimeInterval = 180

    @Published private(set) var state: State = .downloadingModel
    @Published private(set) var recordingStart: Date?

    /// True once the model has been loaded (at least attempted successfully).
    @Published private(set) var modelReady = false

    let settings: SettingsStore

    private let recorder = AudioRecorder()
    private let transcriber = Transcriber()
    private var recordingTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?
    private var limitTask: Task<Void, Never>?
    private var modelCancellable: AnyCancellable?

    init(settings: SettingsStore) {
        self.settings = settings
        // The recorder can die mid-capture if the input device disappears
        // and the engine cannot be restarted — surface it loudly.
        recorder.onFailure = { [weak self] in
            Task { @MainActor in
                guard let self, self.state == .recording else { return }
                self.limitTask?.cancel()
                self.recordingStart = nil
                self.state = .error("Microphone stopped — check your input device")
                SoundCues.interrupted()
            }
        }
        // Switching models in settings unloads the current one and downloads
        // the new selection.
        modelCancellable = settings.$model
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                modelReady = false
                Task { await self.transcriber.reset() }
                prepare()
            }
    }

    // MARK: - Model preparation

    /// Request microphone permission and download/load the Whisper model.
    /// Called once at launch; safe to call again to retry after an error.
    func prepare() {
        guard !modelReady else { return }
        state = .downloadingModel
        let model = settings.model.rawValue
        // Ask for the microphone up front so the system prompt never
        // appears in the middle of a hold-to-talk press (which would
        // swallow the key release and desync the state machine).
        Task {
            let granted = await Self.requestMicrophoneAccess()
            Log.info("prepare: microphone access \(granted ? "granted" : "denied")")
        }
        Task {
            do {
                try await transcriber.prepare(model: model)
                modelReady = true
                state = .idle
                Log.info("prepare: model ready")
            } catch {
                Log.info("prepare: model failed: \(error.localizedDescription)")
                state = .error("Model download failed — click to retry")
            }
        }
    }

    // MARK: - Push to talk

    /// Hotkey pressed: start recording (if the model is ready).
    func beginRecording() {
        Log.info("beginRecording: modelReady=\(modelReady) state=\(state)")
        guard modelReady else {
            if case .error = state { prepare() }
            SoundCues.error() // pressed while the model is still loading
            return
        }
        // Allow retrying from a (sticky) error state.
        guard state == .idle || state.isError else {
            if state != .recording {
                // Pressed while busy transcribing/pasting — let the user
                // know this press did NOT start a new recording.
                SoundCues.error()
            }
            return
        }
        recordingTask?.cancel()
        recordingTask = Task {
            let granted = await Self.requestMicrophoneAccess()
            // The key may have been released (or a newer press started)
            // while the system permission prompt was on screen.
            guard !Task.isCancelled else {
                Log.info("beginRecording: cancelled while awaiting mic permission")
                return
            }
            guard granted else {
                state = .error("Microphone access denied — enable in System Settings > Privacy & Security")
                SoundCues.error()
                return
            }
            do {
                try recorder.start()
                recordingStart = Date()
                state = .recording
                scheduleRecordingLimit()
                SoundCues.start()
                Log.info("beginRecording: recording started")
            } catch {
                Log.info("beginRecording: recorder failed: \(error.localizedDescription)")
                state = .error(error.localizedDescription)
                SoundCues.error()
            }
        }
    }

    /// Hotkey released: stop recording, transcribe, insert text.
    func endRecording() {
        Log.info("endRecording: state=\(state)")
        // Cancel a start that is still waiting on the permission prompt;
        // otherwise recording would begin with the key already up.
        recordingTask?.cancel()
        recordingTask = nil
        guard state == .recording else { return }
        limitTask?.cancel()
        let samples = recorder.stop()
        recordingStart = nil
        SoundCues.stop()
        Log.info("endRecording: captured \(samples.count) samples")
        guard !samples.isEmpty else {
            state = .idle
            return
        }
        state = .transcribing
        let model = settings.model.rawValue
        Task {
            do {
                let text = try await transcriber.transcribe(samples: samples, model: model)
                Log.info("endRecording: transcription: \"\(text)\"")
                if text.isEmpty {
                    // They talked (or thought they did) but nothing usable
                    // was captured — say so out loud.
                    SoundCues.nothingCaptured()
                    state = .idle
                    return
                }
                let didPaste = TextInserter.insert(text)
                state = didPaste ? .pasted : .copiedOnly
                scheduleReset()
            } catch {
                Log.info("endRecording: transcription failed: \(error.localizedDescription)")
                state = .error(error.localizedDescription)
                SoundCues.error()
            }
        }
    }

    // MARK: - Helpers

    /// Auto-stops the recording after `recordingLimit` seconds.
    private func scheduleRecordingLimit() {
        limitTask?.cancel()
        limitTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(Self.recordingLimit * 1_000_000_000))
            guard !Task.isCancelled else { return }
            Log.info("recording limit reached — auto-stopping")
            SoundCues.interrupted() // stopped without the key being released
            endRecording()
        }
    }

    private func scheduleReset(after seconds: TimeInterval = 2.5) {
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            state = .idle
        }
    }

    private static func requestMicrophoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }
}
