import AVFoundation
import Foundation

final class SampleVoicePool {
    private struct ActiveVoice {
        let note: UInt8
        let player: AVAudioPlayerNode
        let pitch: AVAudioUnitTimePitch
    }

    private let engine: AVAudioEngine
    private let mixer: AVAudioMixerNode
    private let maxVoices: Int
    private var pool: [(player: AVAudioPlayerNode, pitch: AVAudioUnitTimePitch)] = []
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
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "SampleVoicePool", code: 1)
        }
        try file.read(into: buffer)

        let startFrame = AVAudioFramePosition(sample.trimStartSeconds * format.sampleRate)
        let endFrame = sample.trimEndSeconds.map { AVAudioFramePosition($0 * format.sampleRate) } ?? AVAudioFramePosition(frameCount)
        let trimmedLength = AVAudioFrameCount(max(1, endFrame - startFrame))
        guard let trimmed = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: trimmedLength) else {
            throw NSError(domain: "SampleVoicePool", code: 2)
        }
        trimmed.frameLength = trimmedLength

        if let src = buffer.floatChannelData, let dst = trimmed.floatChannelData {
            for channel in 0..<Int(format.channelCount) {
                let source = src[channel].advanced(by: Int(startFrame))
                dst[channel].update(from: source, count: Int(trimmedLength))
            }
        }

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
            updateActiveVoicePitches()
        }
    }

    func setPitchBend(_ normalized: Float) {
        pitchBendCents = MIDIUtilities.pitchBendCents(from: normalized)
        updateActiveVoicePitches()
    }

    func noteOn(note: UInt8, velocity: UInt8) {
        guard let sampleBuffer else { return }
        if activeVoices.count >= maxVoices { releaseOldestVoice() }
        guard let voice = pool.popLast() else { return }
        voice.pitch.pitch = pitchFor(note: note)
        voice.player.volume = MIDIUtilities.clampVelocity(velocity)
        voice.player.stop()
        voice.player.scheduleBuffer(sampleBuffer, at: nil, options: [], completionHandler: nil)
        voice.player.play()
        activeVoices.append(ActiveVoice(note: note, player: voice.player, pitch: voice.pitch))
    }

    func noteOff(note: UInt8) {
        let matches = activeVoices.filter { $0.note == note }
        activeVoices.removeAll { $0.note == note }
        for voice in matches {
            voice.player.stop()
            returnVoice(player: voice.player, pitch: voice.pitch)
        }
    }

    func allNotesOff() {
        let voices = activeVoices
        activeVoices.removeAll()
        for voice in voices {
            voice.player.stop()
            returnVoice(player: voice.player, pitch: voice.pitch)
        }
    }

    private func pitchFor(note: UInt8) -> Float {
        MIDIUtilities.transpositionCents(from: rootNote, to: note) + pitchBendCents + vibratoOffset
    }

    private func updateActiveVoicePitches() {
        for voice in activeVoices {
            voice.pitch.pitch = pitchFor(note: voice.note)
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
                self.updateActiveVoicePitches()
                phase += 0.35
                try? await Task.sleep(for: .milliseconds(20))
            }
        }
    }

    private func releaseOldestVoice() {
        guard let oldest = activeVoices.first else { return }
        activeVoices.removeFirst()
        oldest.player.stop()
        returnVoice(player: oldest.player, pitch: oldest.pitch)
    }

    private func buildPool() {
        for _ in 0..<maxVoices {
            let player = AVAudioPlayerNode()
            let pitch = AVAudioUnitTimePitch()
            engine.attach(player)
            engine.attach(pitch)
            engine.connect(player, to: pitch, format: nil)
            engine.connect(pitch, to: mixer, format: nil)
            pool.append((player, pitch))
        }
    }

    private func returnVoice(player: AVAudioPlayerNode, pitch: AVAudioUnitTimePitch) {
        pool.append((player, pitch))
    }
}
