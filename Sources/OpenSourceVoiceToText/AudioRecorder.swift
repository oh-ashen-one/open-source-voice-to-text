import AVFoundation

/// Records microphone audio via AVAudioEngine and converts it on the fly
/// to 16 kHz mono Float32 samples, the format Whisper expects.
final class AudioRecorder {
    /// Called on an arbitrary thread when recording dies mid-capture
    /// (input device lost and the engine could not be restarted).
    var onFailure: (() -> Void)?

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var targetFormat: AVAudioFormat?

    private let lock = NSLock()
    private var samples: [Float] = []
    private var isRecording = false
    private var configObserver: NSObjectProtocol?

    /// Start capturing audio. Throws if the engine fails to start.
    func start() throws {
        lock.lock()
        samples = []
        lock.unlock()

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw RecorderError.noInputDevice
        }
        guard let target = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            throw RecorderError.formatUnavailable
        }
        targetFormat = target
        converter = AVAudioConverter(from: inputFormat, to: target)

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

        engine.prepare()
        try engine.start()
        isRecording = true
        observeConfigurationChanges()
    }

    /// Stop capturing and return the recorded 16 kHz mono samples.
    func stop() -> [Float] {
        guard isRecording else { return [] }
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
            self.configObserver = nil
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRecording = false
        lock.lock()
        defer { lock.unlock() }
        return samples
    }

    deinit {
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
        }
    }

    // MARK: - Surviving audio route changes

    private func observeConfigurationChanges() {
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self] _ in
            self?.handleConfigurationChange()
        }
    }

    /// The input device changed mid-recording (AirPods connected or
    /// disconnected, another app grabbed the mic, …). Rebuild the converter
    /// for the new hardware format and restart the engine, keeping the
    /// samples captured so far. Without this the tap keeps "recording"
    /// silence and the user talks into the void.
    private func handleConfigurationChange() {
        lock.lock()
        let wasRecording = isRecording
        lock.unlock()
        guard wasRecording else { return }

        let input = engine.inputNode
        input.removeTap(onBus: 0)
        engine.stop()

        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
              let target = targetFormat,
              let newConverter = AVAudioConverter(from: inputFormat, to: target) else {
            lock.lock()
            isRecording = false
            lock.unlock()
            Log.info("recorder: input device lost mid-recording")
            onFailure?()
            return
        }
        converter = newConverter
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }
        engine.prepare()
        do {
            try engine.start()
            Log.info("recorder: restarted after audio configuration change")
        } catch {
            lock.lock()
            isRecording = false
            lock.unlock()
            Log.info("recorder: restart after configuration change failed: \(error.localizedDescription)")
            onFailure?()
        }
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let converter, let targetFormat else { return }
        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var error: NSError?
        var consumed = false
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, output.frameLength > 0,
              let channelData = output.floatChannelData?[0] else { return }

        let chunk = Array(UnsafeBufferPointer(start: channelData, count: Int(output.frameLength)))
        lock.lock()
        samples.append(contentsOf: chunk)
        lock.unlock()
    }

    enum RecorderError: LocalizedError {
        case noInputDevice
        case formatUnavailable

        var errorDescription: String? {
            switch self {
            case .noInputDevice: return "No microphone input available."
            case .formatUnavailable: return "Could not create target audio format."
            }
        }
    }
}
