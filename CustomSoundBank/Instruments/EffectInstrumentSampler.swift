import AudioToolbox
import AVFoundation
import Foundation

/// Bundled pad with an instrument-local effect chain: sampler → distortion → filter → mixer.
final class EffectInstrumentSampler {
    private var sampler = AVAudioUnitSampler()
    private var filter = AVAudioUnitEQ(numberOfBands: 1)
    private var distortion: AVAudioUnitDistortion?
    private let instrumentMixer = AVAudioMixerNode()
    private let autoWah = AutoWahEnvelope()
    private var chopWorkItems: [UInt8: DispatchWorkItem] = [:]
    private let chopQueue = DispatchQueue(label: "EffectInstrumentSampler.chop")
    private(set) var loadedPadID: String?
    private var articulation: ArticulationSettings?
    private var autoWahSettings: AutoWahSettings?
    private var catalogGain: Float = 1
    private var userVolume: Float = 1

    var node: AVAudioNode { instrumentMixer }

    func setVolume(_ volume: Float) {
        userVolume = max(0, min(1, volume))
        applyOutputVolume()
    }

    func load(pad: BundledPad, into audioEngine: AudioEngineController) throws {
        guard let effects = pad.effects else {
            throw NSError(domain: "EffectInstrumentSampler", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Pad \(pad.id) has no effect preset."
            ])
        }

        allNotesOff()
        articulation = pad.articulation
        catalogGain = PlaybackGain.forPad(pad)

        let bankName = pad.soundFontFileName ?? "GeneralUser-GS"
        guard let bankURL = Bundle.main.url(
            forResource: bankName,
            withExtension: "sf2",
            subdirectory: "SoundBanks"
        ) ?? Bundle.main.url(forResource: bankName, withExtension: "sf2") else {
            throw NSError(domain: "EffectInstrumentSampler", code: 2, userInfo: [
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

            let newFilter = AVAudioUnitEQ(numberOfBands: 1)
            configureFilter(newFilter, settings: effects.autoWah)

            var newDistortion: AVAudioUnitDistortion?
            if let distortionSettings = effects.distortion, distortionSettings.mix > 0 {
                let unit = AVAudioUnitDistortion()
                unit.loadFactoryPreset(.multiBrokenSpeaker)
                unit.wetDryMix = distortionSettings.mix * 100
                unit.preGain = distortionSettings.gain
                newDistortion = unit
            }

            engine.attach(newSampler)
            engine.attach(newFilter)
            engine.attach(instrumentMixer)

            if let newDistortion {
                engine.attach(newDistortion)
                engine.connect(newSampler, to: newDistortion, format: nil)
                engine.connect(newDistortion, to: newFilter, format: nil)
            } else {
                engine.connect(newSampler, to: newFilter, format: nil)
            }
            engine.connect(newFilter, to: instrumentMixer, format: nil)

            sampler = newSampler
            filter = newFilter
            distortion = newDistortion
            applyOutputVolume()
        }

        autoWahSettings = effects.autoWah
        autoWah.configure(settings: effects.autoWah)
        loadedPadID = pad.id
    }

    func tearDown(from audioEngine: AudioEngineController) {
        allNotesOff()
        try? audioEngine.mutateGraph {
            tearDownGraph(in: audioEngine)
            loadedPadID = nil
            articulation = nil
            autoWahSettings = nil
            autoWah.configure(settings: nil)
            catalogGain = 1
        }
    }

    func noteOn(note: UInt8, velocity: UInt8) {
        sampler.startNote(note, withVelocity: velocity, onChannel: 0)

        if autoWahSettings != nil {
            autoWah.trigger(velocity: velocity) { [weak self] frequency in
                self?.setFilterFrequency(frequency)
            }
        }

        if let maxDuration = articulation?.maximumNoteDuration {
            scheduleAutoChop(note: note, after: maxDuration)
        }
    }

    func noteOff(note: UInt8) {
        cancelAutoChop(note: note)
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
        cancelAllAutoChops()
        autoWah.cancel()
        for note: UInt8 in 0...127 {
            sampler.stopNote(note, onChannel: 0)
        }
    }

    private func applyOutputVolume() {
        instrumentMixer.outputVolume = min(PlaybackGain.maximumBoost, catalogGain * userVolume)
    }

    private func configureFilter(_ filter: AVAudioUnitEQ, settings: AutoWahSettings?) {
        let band = filter.bands[0]
        band.filterType = .lowPass
        band.bypass = false
        band.frequency = settings?.closedFrequency ?? 500
        if let settings {
            band.bandwidth = max(0.1, 2.0 / settings.resonance)
        } else {
            band.bandwidth = 0.7
        }
        band.gain = 0
    }

    private func setFilterFrequency(_ frequency: Float) {
        let band = filter.bands[0]
        band.frequency = max(20, min(20_000, frequency))
    }

    private func scheduleAutoChop(note: UInt8, after duration: TimeInterval) {
        cancelAutoChop(note: note)
        let work = DispatchWorkItem { [weak self] in
            self?.sampler.stopNote(note, onChannel: 0)
            self?.chopQueue.async {
                self?.chopWorkItems.removeValue(forKey: note)
            }
        }
        chopWorkItems[note] = work
        chopQueue.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func cancelAutoChop(note: UInt8) {
        chopQueue.async {
            if let work = self.chopWorkItems.removeValue(forKey: note) {
                work.cancel()
            }
        }
    }

    private func cancelAllAutoChops() {
        chopQueue.async {
            for work in self.chopWorkItems.values {
                work.cancel()
            }
            self.chopWorkItems.removeAll()
        }
    }

    private func tearDownGraph(in audioEngine: AudioEngineController) {
        let engine = audioEngine.engine
        if engine.attachedNodes.contains(sampler) {
            engine.disconnectNodeOutput(sampler)
            engine.detach(sampler)
        }
        if let distortion, engine.attachedNodes.contains(distortion) {
            engine.disconnectNodeOutput(distortion)
            engine.detach(distortion)
        }
        if engine.attachedNodes.contains(filter) {
            engine.disconnectNodeOutput(filter)
            engine.detach(filter)
        }
        if engine.attachedNodes.contains(instrumentMixer) {
            engine.disconnectNodeOutput(instrumentMixer)
            engine.detach(instrumentMixer)
        }
        distortion = nil
    }
}
