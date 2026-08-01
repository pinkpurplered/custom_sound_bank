import AudioToolbox
import AVFoundation
import Foundation

/// Plays multiple bundled pads simultaneously through a sub-mixer.
final class LayeredInstrumentSampler {
    private let layerMixer = AVAudioMixerNode()
    private var samplers: [AVAudioUnitSampler] = []
    private var layerVolumes: [Float] = []
    private(set) var loadedPadID: String?
    private var masterVolume: Float = 1

    var node: AVAudioNode { layerMixer }

    func setVolume(_ volume: Float) {
        masterVolume = max(0, min(1, volume))
        applyLayerVolumes()
    }

    func load(padID: String, layers: [(BundledPad, Float)], into audioEngine: AudioEngineController) throws {
        allNotesOff()
        try audioEngine.mutateGraph {
            tearDownGraph(in: audioEngine)

            let engine = audioEngine.engine
            if !engine.attachedNodes.contains(layerMixer) {
                engine.attach(layerMixer)
            }

            for (pad, layerVolume) in layers {
                let bankName = pad.soundFontFileName ?? "GeneralUser-GS"
                guard let bankURL = Bundle.main.url(
                    forResource: bankName,
                    withExtension: "sf2",
                    subdirectory: "SoundBanks"
                ) ?? Bundle.main.url(forResource: bankName, withExtension: "sf2") else {
                    throw NSError(domain: "LayeredInstrumentSampler", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Missing bundled sound bank \(bankName).sf2."
                    ])
                }

                let sampler = AVAudioUnitSampler()
                try sampler.loadSoundBankInstrument(
                    at: bankURL,
                    program: pad.gmProgram,
                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: UInt8(kAUSampler_DefaultBankLSB)
                )
                engine.attach(sampler)
                engine.connect(sampler, to: layerMixer, format: nil)
                samplers.append(sampler)
                layerVolumes.append(layerVolume)
            }
            applyLayerVolumes()
        }
        loadedPadID = padID
    }

    func tearDown(from audioEngine: AudioEngineController) {
        try? audioEngine.mutateGraph {
            tearDownGraph(in: audioEngine)
            loadedPadID = nil
        }
    }

    func noteOn(note: UInt8, velocity: UInt8) {
        for sampler in samplers {
            sampler.startNote(note, withVelocity: velocity, onChannel: 0)
        }
    }

    func noteOff(note: UInt8) {
        for sampler in samplers {
            sampler.stopNote(note, onChannel: 0)
        }
    }

    func setModulation(_ value: Float) {
        let midiValue = UInt8(max(0, min(127, Int(value * 127))))
        for sampler in samplers {
            sampler.sendController(1, withValue: midiValue, onChannel: 0)
        }
    }

    func setPitchBend(_ normalized: Float) {
        let midiValue = MIDIUtilities.pitchBendMIDIValue(from: normalized)
        for sampler in samplers {
            sampler.sendPitchBend(midiValue, onChannel: 0)
        }
    }

    func allNotesOff() {
        for sampler in samplers {
            for note: UInt8 in 0...127 {
                sampler.stopNote(note, onChannel: 0)
            }
        }
    }

    private func tearDownGraph(in audioEngine: AudioEngineController) {
        let engine = audioEngine.engine
        for sampler in samplers {
            if engine.attachedNodes.contains(sampler) {
                engine.disconnectNodeOutput(sampler)
                engine.detach(sampler)
            }
        }
        samplers = []
        layerVolumes = []
        if engine.attachedNodes.contains(layerMixer) {
            engine.disconnectNodeOutput(layerMixer)
            engine.detach(layerMixer)
        }
    }

    private func applyLayerVolumes() {
        for (index, sampler) in samplers.enumerated() {
            let layerVolume = layerVolumes[index]
            sampler.volume = layerVolume * masterVolume
        }
    }
}
