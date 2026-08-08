import AVFoundation
import Foundation

final class SampleVoicePool {
    /// Matches `SampleLibraryStore` output: mono float32 @ 44.1 kHz.
    private static let sampleFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 44_100,
        channels: 1,
        interleaved: false
    )!

    private struct ActiveVoice {
        let note: UInt8
        let player: AVAudioPlayerNode
        let varispeed: AVAudioUnitVarispeed
    }

    private let engine: AVAudioEngine
    private let mixer: AVAudioMixerNode
    private let maxVoices: Int
    private var pool: [(player: AVAudioPlayerNode, varispeed: AVAudioUnitVarispeed)] = []
    private var activeVoices: [ActiveVoice] = []
    private var sampleBuffer: AVAudioPCMBuffer?
    private var rootNote: UInt8 = 60
    private var pitchBendCents: Float = 0
    private var modulation: Float = 0
    private var vibratoOffset: Float = 0
    private var modulationTask: Task<Void, Never>?

    init(engine: AVAudioEngine, mixer: AVAudioMixerNode, maxVoices: Int = 16) {
        self.engine = engine
        self.mixer = mixer
        self.maxVoices = maxVoices
        buildPool()
    }

    deinit {
        modulationTask?.cancel()
    }

    func load(sample: UserSampleInstrument, from url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        let sourceFormat = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
            throw NSError(domain: "SampleVoicePool", code: 1)
        }
        try file.read(into: sourceBuffer)

        let floatBuffer = try makeFloatBuffer(from: sourceBuffer, format: sourceFormat, to: Self.sampleFormat)

        let totalFrames = Int(floatBuffer.frameLength)
        guard totalFrames > 0 else {
            throw NSError(domain: "SampleVoicePool", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Recorded sample is empty."
            ])
        }

        let sampleRate = floatBuffer.format.sampleRate
        let startFrame = min(
            max(0, Int(sample.trimStartSeconds * sampleRate)),
            totalFrames - 1
        )
        let endFrame: Int
        if let trimEndSeconds = sample.trimEndSeconds {
            endFrame = min(max(startFrame + 1, Int(trimEndSeconds * sampleRate)), totalFrames)
        } else {
            endFrame = totalFrames
        }
        let trimmedLength = AVAudioFrameCount(endFrame - startFrame)
        guard let trimmed = AVAudioPCMBuffer(pcmFormat: floatBuffer.format, frameCapacity: trimmedLength) else {
            throw NSError(domain: "SampleVoicePool", code: 3)
        }
        trimmed.frameLength = trimmedLength

        guard
            let src = floatBuffer.floatChannelData,
            let dst = trimmed.floatChannelData
        else {
            throw NSError(domain: "SampleVoicePool", code: 4)
        }

        for channel in 0..<Int(floatBuffer.format.channelCount) {
            let source = src[channel].advanced(by: startFrame)
            dst[channel].update(from: source, count: Int(trimmedLength))
        }

        AudioBufferGain.peakNormalize(trimmed)

        sampleBuffer = trimmed
        rootNote = sample.rootNote
        allNotesOff()
    }

    func setModulation(_ value: Float) {
        modulation = max(0, min(1, value))
        if modulation > 0 {
            startModulationLFO()
        } else {
            modulationTask?.cancel()
            modulationTask = nil
            vibratoOffset = 0
            updateActiveVoiceRates()
        }
    }

    func setPitchBend(_ normalized: Float) {
        pitchBendCents = MIDIUtilities.pitchBendCents(from: normalized)
        updateActiveVoiceRates()
    }

    func noteOn(note: UInt8, velocity: UInt8) {
        guard let sampleBuffer else { return }
        if activeVoices.count >= maxVoices { releaseOldestVoice() }
        guard let voice = pool.popLast() else { return }
        voice.varispeed.rate = playbackRate(for: note)
        voice.player.volume = MIDIUtilities.clampVelocity(velocity)
        if !voice.player.isPlaying {
            voice.player.play()
        }
        voice.player.scheduleBuffer(
            sampleBuffer,
            at: nil,
            options: [.interrupts],
            completionHandler: nil
        )
        activeVoices.append(ActiveVoice(note: note, player: voice.player, varispeed: voice.varispeed))
    }

    func noteOff(note: UInt8) {
        let matches = activeVoices.filter { $0.note == note }
        activeVoices.removeAll { $0.note == note }
        for voice in matches {
            voice.player.stop()
            returnVoice(player: voice.player, varispeed: voice.varispeed)
        }
    }

    func allNotesOff() {
        let voices = activeVoices
        activeVoices.removeAll()
        for voice in voices {
            voice.player.stop()
            returnVoice(player: voice.player, varispeed: voice.varispeed)
        }
    }

    private func makeFloatBuffer(
        from sourceBuffer: AVAudioPCMBuffer,
        format sourceFormat: AVAudioFormat,
        to destinationFormat: AVAudioFormat
    ) throws -> AVAudioPCMBuffer {
        if sourceFormat.commonFormat == destinationFormat.commonFormat,
           sourceFormat.isInterleaved == destinationFormat.isInterleaved,
           sourceFormat.channelCount == destinationFormat.channelCount,
           sourceFormat.sampleRate == destinationFormat.sampleRate {
            return sourceBuffer
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: destinationFormat) else {
            throw NSError(domain: "SampleVoicePool", code: 6)
        }
        AudioConverterQuality.configure(converter)

        let capacity = AVAudioFrameCount(
            Double(sourceBuffer.frameLength) * destinationFormat.sampleRate / sourceFormat.sampleRate + 1
        )
        guard let destination = AVAudioPCMBuffer(pcmFormat: destinationFormat, frameCapacity: capacity) else {
            throw NSError(domain: "SampleVoicePool", code: 7)
        }

        var consumedInput = false
        var error: NSError?
        let status = converter.convert(to: destination, error: &error) { _, outStatus in
            if consumedInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumedInput = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if status == .error {
            throw error ?? NSError(domain: "SampleVoicePool", code: 8)
        }

        return destination
    }

    private func playbackRate(for note: UInt8) -> Float {
        let cents = MIDIUtilities.transpositionCents(from: rootNote, to: note) + pitchBendCents + vibratoOffset
        return pow(2.0, cents / 1200.0)
    }

    private func updateActiveVoiceRates() {
        for voice in activeVoices {
            voice.varispeed.rate = playbackRate(for: voice.note)
        }
    }

    private func startModulationLFO() {
        guard modulationTask == nil else { return }
        modulationTask = Task { [weak self] in
            var phase: Float = 0
            while !Task.isCancelled {
                guard let self else { return }
                let depth = self.modulation * 50
                self.vibratoOffset = sin(phase) * depth
                self.updateActiveVoiceRates()
                phase += 0.35
                try? await Task.sleep(for: .milliseconds(20))
            }
        }
    }

    private func releaseOldestVoice() {
        guard let oldest = activeVoices.first else { return }
        activeVoices.removeFirst()
        oldest.player.stop()
        returnVoice(player: oldest.player, varispeed: oldest.varispeed)
    }

    private func buildPool() {
        let format = Self.sampleFormat
        for _ in 0..<maxVoices {
            let player = AVAudioPlayerNode()
            let varispeed = AVAudioUnitVarispeed()
            engine.attach(player)
            engine.attach(varispeed)
            engine.connect(player, to: varispeed, format: format)
            engine.connect(varispeed, to: mixer, format: format)
            prime(player, format: format)
            pool.append((player, varispeed))
        }
    }

    private func prime(_ player: AVAudioPlayerNode, format: AVAudioFormat) {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 256) else { return }
        buffer.frameLength = 256
        player.scheduleBuffer(buffer, at: nil, options: [])
    }

    private func returnVoice(player: AVAudioPlayerNode, varispeed: AVAudioUnitVarispeed) {
        pool.append((player, varispeed))
    }
}
