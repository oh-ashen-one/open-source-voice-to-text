import AVFoundation

/// Saves every finished recording to ~/Downloads as a timestamped
/// 16 kHz mono WAV, so dictations are never lost and can be replayed
/// when debugging transcription issues.
enum RecordingSaver {

    static func save(samples: [Float]) {
        guard !samples.isEmpty else { return }
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else { return }

        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")
            .appendingPathComponent("VoiceToText-\(timestamp()).wav")

        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(samples.count)
            ) else { return }
            buffer.frameLength = AVAudioFrameCount(samples.count)
            samples.withUnsafeBufferPointer { src in
                guard let base = src.baseAddress,
                      let dst = buffer.floatChannelData?[0] else { return }
                dst.update(from: base, count: samples.count)
            }
            try file.write(from: buffer)
            Log.info("saver: wrote \(url.lastPathComponent) (\(samples.count) samples)")
            prune(keep: 3)
        } catch {
            Log.info("saver: failed to write \(url.path): \(error.localizedDescription)")
        }
    }

    /// Keeps only the newest `keep` recordings in ~/Downloads. File names
    /// are timestamped, so sorting by name sorts oldest-first.
    private static func prune(keep: Int) {
        let downloads = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: downloads,
            includingPropertiesForKeys: nil
        ) else { return }
        let recordings = files
            .filter { $0.lastPathComponent.hasPrefix("VoiceToText-") && $0.pathExtension == "wav" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for stale in recordings.dropLast(keep) {
            try? FileManager.default.removeItem(at: stale)
            Log.info("saver: pruned \(stale.lastPathComponent)")
        }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}
