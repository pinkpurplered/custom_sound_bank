import AVFoundation
import Foundation

@MainActor
final class BundledInstrumentSampler {
    private var sampler = AVAudioUnitSampler()
    private var loadedKind: InstrumentKind?

    var node: AVAudioNode { sampler }

    func load(kind: InstrumentKind, into audioEngine: AudioEngineController) throws {
        guard loadedKind != kind else { return }

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

        try audioEngine.mutateGraph {
            if audioEngine.engine.attachedNodes.contains(sampler) {
                audioEngine.detach(node: sampler)
            }

            let newSampler = AVAudioUnitSampler()
            try newSampler.loadAudioFiles(at: [sampleURL])
            sampler = newSampler
            loadedKind = kind
            audioEngine.attach(node: sampler)
        }
    }

    private static func sampleURL(fileName: String) -> URL? {
        Bundle.main.url(forResource: fileName, withExtension: "wav", subdirectory: "SoundBanks")
            ?? Bundle.main.url(forResource: fileName, withExtension: "wav")
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
