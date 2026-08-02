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

    @Published private(set) var state: State = .downloadingModel
    @Published private(set) var recordingStart: Date?

    /// True once the model has been loaded (at least attempted successfully).
    @Published private(set) var modelReady = false

    private let recorder = AudioRecorder()
    private let transcriber = Transcriber()
    private var recordingTask: Task<Void, Never>?
    private var resetTask: Task<Void, Never>?

    // MARK: - Model preparation

    /// Request microphone permission and download/load the Whisper model.
    /// Called once at launch; safe to call again to retry after an error.
    func prepare() {
        guard !modelReady else { return }
        state = .downloadingModel
        Task {
            do {
                try await transcriber.prepare()
                modelReady = true
                state = .idle
            } catch {
                state = .error("Model download failed — click to retry")
            }
        }
    }

    // MARK: - Push to talk

    /// Hotkey pressed: start recording (if the model is ready).
    func beginRecording() {
        guard modelReady else {
            if case .error = state { prepare() }
            return
        }
        // Allow retrying from a (sticky) error state.
        guard state == .idle || state.isError else { return }
        recordingTask?.cancel()
        recordingTask = Task {
            let granted = await Self.requestMicrophoneAccess()
            guard granted else {
                state = .error("Microphone access denied — enable in System Settings > Privacy & Security")
                return
            }
            do {
                try recorder.start()
                recordingStart = Date()
                state = .recording
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    /// Hotkey released: stop recording, transcribe, insert text.
    func endRecording() {
        guard state == .recording else { return }
        let samples = recorder.stop()
        recordingStart = nil
        guard !samples.isEmpty else {
            state = .idle
            return
        }
        state = .transcribing
        Task {
            do {
                let text = try await transcriber.transcribe(samples: samples)
                if text.isEmpty {
                    state = .idle
                    return
                }
                let didPaste = TextInserter.insert(text)
                state = didPaste ? .pasted : .copiedOnly
                scheduleReset()
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Helpers

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
