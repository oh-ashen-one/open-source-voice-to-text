import Foundation
import WhisperKit

/// Thin wrapper around WhisperKit. The model is downloaded from the
/// argmaxinc/whisperkit-coreml repo on first use (~150 MB for base).
actor Transcriber {
    private var kit: WhisperKit?
    private var prepareTask: Task<Void, Error>?

    /// Idempotently download (first launch) and load the Whisper model.
    func prepare() async throws {
        if kit != nil { return }
        if let prepareTask {
            return try await prepareTask.value
        }
        let task = Task<Void, Error> {
            let config = WhisperKitConfig(
                model: "openai_whisper-base",
                modelRepo: "argmaxinc/whisperkit-coreml",
                verbose: false,
                logLevel: .error,
                load: true,
                download: true
            )
            self.kit = try await WhisperKit(config)
        }
        prepareTask = task
        do {
            try await task.value
        } catch {
            prepareTask = nil // allow retry on next attempt
            throw error
        }
    }

    /// Transcribe 16 kHz mono Float32 samples to text.
    func transcribe(samples: [Float]) async throws -> String {
        try await prepare()
        guard let kit else { throw TranscriberError.notReady }
        guard samples.count >= 1600 else { return "" } // < 0.1 s of audio

        let options = DecodingOptions(
            task: .transcribe,
            temperature: 0, // greedy decoding = lowest latency
            withoutTimestamps: true,
            wordTimestamps: false
        )
        let results = try await kit.transcribe(audioArray: samples, decodeOptions: options)
        return results
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum TranscriberError: LocalizedError {
        case notReady

        var errorDescription: String? {
            switch self {
            case .notReady: return "The transcription model is not ready yet."
            }
        }
    }
}
