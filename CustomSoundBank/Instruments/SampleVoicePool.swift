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
    private var sustainDown = false
    private var sustainedNotes = Set<UInt8>()

    init(engine: AVAudioEngine, mixer: AVAudioMixerNode, maxVoices: Int = 16) {
        self.engine = engine
        self.mixer = mixer
        self.maxVoices = maxVoices
        buildPool()
    }

    var node: AVAudioNode { mixer }

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
            let channelCount = Int(format.channelCount)
            for channel in 0..<channelCount {
                let source = src[channel].advanced(by: Int(startFrame))
                dst[channel].update(from: source, count: Int(trimmedLength))
            }
        }

        sampleBuffer = trimmed
        rootNote = sample.rootNote
        allNotesOff()
    }

    func noteOn(note: UInt8, velocity: UInt8) {
        guard let sampleBuffer else { return }
        sustainedNotes.remove(note)

        if activeVoices.count >= maxVoices {
            releaseOldestVoice()
        }

        guard let voice = pool.popLast() else { return }
        voice.pitch.pitch = MIDIUtilities.transpositionCents(from: rootNote, to: note)
        voice.player.volume = MIDIUtilities.clampVelocity(velocity)
        voice.player.stop()
        voice.player.scheduleBuffer(sampleBuffer, at: nil, options: [], completionHandler: nil)
        voice.player.play()

        activeVoices.append(ActiveVoice(note: note, player: voice.player, pitch: voice.pitch))
    }

    func noteOff(note: UInt8) {
        if sustainDown {
            sustainedNotes.insert(note)
            return
        }
        stop(note: note)
    }

    func setSustain(_ isDown: Bool) {
        sustainDown = isDown
        if !isDown {
            let notes = sustainedNotes
            sustainedNotes.removeAll()
            notes.forEach { stop(note: $0) }
        }
    }

    func allNotesOff() {
        sustainedNotes.removeAll()
        sustainDown = false
        let voices = activeVoices
        activeVoices.removeAll()
        for voice in voices {
            voice.player.stop()
            returnVoice(player: voice.player, pitch: voice.pitch)
        }
    }

    private func stop(note: UInt8) {
        let matches = activeVoices.filter { $0.note == note }
        activeVoices.removeAll { $0.note == note }
        for voice in matches {
            voice.player.stop()
            returnVoice(player: voice.player, pitch: voice.pitch)
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
