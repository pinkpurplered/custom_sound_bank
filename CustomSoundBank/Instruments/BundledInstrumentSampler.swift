import AudioToolbox
import AVFoundation
import Foundation

final class BundledInstrumentSampler {
    private var sampler = AVAudioUnitSampler()
    private let outputMixer = AVAudioMixerNode()
    private(set) var loadedPadID: String?
    private var catalogGain: Float = 1
    private var userVolume: Float = 1

    var node: AVAudioNode { outputMixer }

    func setVolume(_ volume: Float) {
        userVolume = max(0, min(1, volume))
        applyOutputVolume()
    }

    func load(pad: BundledPad, into audioEngine: AudioEngineController) throws {
        allNotesOff()
        catalogGain = PlaybackGain.forPad(pad)

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
            tearDownGraph(in: audioEngine)

            let engine = audioEngine.engine
            let newSampler = AVAudioUnitSampler()
            try newSampler.loadSoundBankInstrument(
                at: bankURL,
                program: pad.gmProgram,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB)
            )
            newSampler.volume = 1

            engine.attach(newSampler)
            engine.attach(outputMixer)
            engine.connect(newSampler, to: outputMixer, format: nil)

            sampler = newSampler
            applyOutputVolume()
        }
        loadedPadID = pad.id
    }

    func tearDown(from audioEngine: AudioEngineController) {
        allNotesOff()
        try? audioEngine.mutateGraph {
            tearDownGraph(in: audioEngine)
            loadedPadID = nil
            catalogGain = 1
        }
    }

    func noteOn(note: UInt8, velocity: UInt8) {
        sampler.startNote(note, withVelocity: velocity, onChannel: 0)
    }

    func noteOff(note: UInt8) {
        sampler.stopNote(note, onChannel: 0)
    }

    func setModulation(_ value: Float) {
        let midiValue = UInt8(max(0, min(127, Int(value * 127))))
        sampler.sendController(1, withValue: midiValue, onChannel: 0)
    }

    func setPitchBend(_ normalized: Float) {
        sampler.sendPitchBend(MIDIUtilities.pitchBendMIDIValue(from: normalized), onChannel: 0)
    }

    func allNotesOff() {
        for note: UInt8 in 0...127 {
            sampler.stopNote(note, onChannel: 0)
        }
    }

    private func applyOutputVolume() {
        outputMixer.outputVolume = min(PlaybackGain.maximumBoost, catalogGain * userVolume)
    }

    private func tearDownGraph(in audioEngine: AudioEngineController) {
        let engine = audioEngine.engine
        if engine.attachedNodes.contains(sampler) {
            engine.disconnectNodeOutput(sampler)
            engine.detach(sampler)
        }
        if engine.attachedNodes.contains(outputMixer) {
            engine.disconnectNodeOutput(outputMixer)
            engine.detach(outputMixer)
        }
    }
}
