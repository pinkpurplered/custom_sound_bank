import AudioToolbox
import AVFoundation
import Foundation

@MainActor
final class BundledInstrumentSampler {
    private var sampler = AVAudioUnitSampler()

    var node: AVAudioNode { sampler }

    func load(pad: BundledPad, into audioEngine: AudioEngineController) throws {
        allNotesOff()
        let bankName = pad.soundFontFileName ?? "GeneralUser-GS"
        guard let bankURL = Bundle.main.url(
            forResource: bankName,
            withExtension: "sf2",
            subdirectory: "SoundBanks"
        ) ?? Bundle.main.url(forResource: bankName, withExtension: "sf2") else {
            throw NSError(domain: "BundledInstrumentSampler", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Missing bundled sound bank \(bankName).sf2."
            ])
        }

        try audioEngine.mutateGraph {
            if audioEngine.engine.attachedNodes.contains(sampler) {
                audioEngine.detach(node: sampler)
            }
            let newSampler = AVAudioUnitSampler()
            try newSampler.loadSoundBankInstrument(
                at: bankURL,
                program: pad.gmProgram,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB)
            )
            sampler = newSampler
        }
    }

    func noteOn(note: UInt8, velocity: UInt8) {
        sampler.startNote(note, withVelocity: velocity, onChannel: 0)
    }

    func noteOff(note: UInt8) {
        sampler.stopNote(note, onChannel: 0)
    }

    func setModulation(_ value: UInt8) {
        sampler.sendController(1, withValue: value, onChannel: 0)
    }

    func setPitchBend(_ value: UInt16) {
        sampler.sendPitchBend(value, onChannel: 0)
    }

    func allNotesOff() {
        for note: UInt8 in 0...127 {
            sampler.stopNote(note, onChannel: 0)
        }
    }
}
