import Foundation
import WhisperKit

/// Thin wrapper around WhisperKit. The model is downloaded from the
/// argmaxinc/whisperkit-coreml repo on first use.
actor Transcriber {
    private var kit: WhisperKit?
    private var loadedModel: String?
    private var prepareTask: Task<Void, Error>?

    /// Idempotently download (first launch) and load the given Whisper model.
    /// If a different model was previously loaded, it is unloaded first.
    func prepare(model: String) async throws {
        if kit != nil, loadedModel == model { return }
        if let prepareTask, loadedModel == model {
            return try await prepareTask.value
        }
        kit = nil
        loadedModel = model
        let task = Task<Void, Error> {
            let config = WhisperKitConfig(
                model: model,
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

    /// Unload the current model (used when switching models in settings).
    func reset() {
        kit = nil
        loadedModel = nil
        prepareTask = nil
    }

    /// Transcribe 16 kHz mono Float32 samples to text.
    /// Returns "" for silence and for known Whisper hallucinations.
    func transcribe(samples: [Float], model: String) async throws -> String {
        try await prepare(model: model)
        guard let kit else { throw TranscriberError.notReady }
        guard samples.count >= 1600 else { return "" } // < 0.1 s of audio

        // Silence gate: skip transcription when the recording is essentially
        // quiet. Whisper hallucinates phantom text ("Thanks for watching!")
        // on near-silent audio.
        let rms = Self.rms(samples)
        if rms < 0.005 && Self.peak(samples) < 0.02 { return "" }

        let options = DecodingOptions(
            task: .transcribe,
            temperature: 0, // greedy decoding = lowest latency
            withoutTimestamps: true,
            wordTimestamps: false
        )
        let results = try await kit.transcribe(audioArray: samples, decodeOptions: options)
        let text = results
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Hallucination blocklist, gated on low signal so genuinely spoken
        // "thank you" at normal volume still passes through.
        if rms < 0.03, Self.isHallucination(text) { return "" }
        return text
    }

    private static func rms(_ samples: [Float]) -> Float {
        var sumSquares: Float = 0
        for s in samples { sumSquares += s * s }
        return sqrt(sumSquares / Float(max(samples.count, 1)))
    }

    private static func peak(_ samples: [Float]) -> Float {
        samples.reduce(0) { max($0, abs($1)) }
    }

    /// Whole-text matches of phrases Whisper emits on silence or noise.
    /// Compared case- and punctuation-insensitively.
    private static let hallucinations: Set<String> = [
        "thank you",
        "thank you for watching",
        "thanks for watching",
        "thank you so much for watching",
        "thanks for listening",
        "thank you for listening",
        "bye",
        "goodbye",
        "see you next time",
        "please subscribe",
        "subscribe",
        "you",
    ]

    private static func isHallucination(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?,… "))
        return hallucinations.contains(normalized)
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
