import AVFoundation
import Foundation

@MainActor
final class BundledInstrumentSampler {
    private let mixer = AVAudioMixerNode()
    private var voicePool: SampleVoicePool?
    private(set) var loadedKind: InstrumentKind?

    var node: AVAudioNode { mixer }

    func load(kind: InstrumentKind, into audioEngine: AudioEngineController) throws {
        guard let fileName = kind.bundledFileName else {
            throw NSError(domain: "BundledInstrumentSampler", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No bundled asset for \(kind.displayName)"
            ])
        }

        guard let sampleURL = Self.sampleURL(fileName: fileName) else {
            throw NSError(domain: "BundledInstrumentSampler", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Missing bundled sample \(fileName).wav"
            ])
        }

        allNotesOff()

        if voicePool == nil {
            audioEngine.attach(node: mixer)
            voicePool = SampleVoicePool(engine: audioEngine.engine, mixer: mixer)
        }

        let sample = UserSampleInstrument(
            name: kind.displayName,
            fileName: "\(fileName).wav",
            rootNote: 60
        )
        try voicePool?.load(sample: sample, from: sampleURL)
        loadedKind = kind
    }

    private static func sampleURL(fileName: String) -> URL? {
        Bundle.main.url(forResource: fileName, withExtension: "wav", subdirectory: "SoundBanks")
            ?? Bundle.main.url(forResource: fileName, withExtension: "wav")
    }

    func noteOn(note: UInt8, velocity: UInt8) {
        voicePool?.noteOn(note: note, velocity: velocity)
    }

    func noteOff(note: UInt8) {
        voicePool?.noteOff(note: note)
    }

    func allNotesOff() {
        voicePool?.allNotesOff()
    }
}
