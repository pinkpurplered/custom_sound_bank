import AVFoundation
import Foundation

@MainActor
final class BundledInstrumentSampler {
    private let sampler = AVAudioUnitSampler()
    private var loadedKind: InstrumentKind?

    var node: AVAudioNode { sampler }

    func load(kind: InstrumentKind, into engine: AudioEngineController) throws {
        engine.attach(node: sampler)
        guard loadedKind != kind else { return }

        guard let fileName = kind.bundledFileName else {
            throw NSError(domain: "BundledInstrumentSampler", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No bundled asset for \(kind.displayName)"
            ])
        }

        guard let url = Bundle.main.url(forResource: fileName, withExtension: "wav", subdirectory: "SoundBanks")
            ?? Bundle.main.url(forResource: fileName, withExtension: "wav", subdirectory: "Resources/SoundBanks")
            ?? Bundle.main.url(forResource: fileName, withExtension: "wav") else {
            throw NSError(domain: "BundledInstrumentSampler", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Missing bundled sample \(fileName).wav"
            ])
        }

        try sampler.loadAudioFiles(at: [url])
        loadedKind = kind
    }

    func noteOn(note: UInt8, velocity: UInt8) {
        sampler.startNote(note, withVelocity: velocity, onChannel: 0)
    }

    func noteOff(note: UInt8) {
        sampler.stopNote(note, onChannel: 0)
    }

    func allNotesOff() {
        for note: UInt8 in 0...127 {
            sampler.stopNote(note, onChannel: 0)
        }
    }
}
