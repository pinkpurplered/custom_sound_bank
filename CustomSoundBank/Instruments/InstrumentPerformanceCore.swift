import AVFoundation
import Foundation

/// Thread-safe MIDI-to-audio path. Called directly from the Core MIDI read callback.
final class InstrumentPerformanceCore: @unchecked Sendable {
    private let lock = NSLock()
    private let bundledSampler = BundledInstrumentSampler()
    private let effectSampler = EffectInstrumentSampler()
    private let layeredSampler = LayeredInstrumentSampler()
    private var usingLayeredSampler = false
    private var usingEffectSampler = false
    private var userVoicePool: SampleVoicePool?
    private var userMixer = AVAudioMixerNode()
    private weak var audioEngine: AudioEngineController?
    private var selectedInstrument: SelectedInstrument = .bundled(BundledPad.defaultPad)
    private var sustainDown = false
    private var sustainedNotes = Set<UInt8>()
    private var instrumentVolume: Float = 1
    private var modulation: Float = 0
    private var pitchBend: Float = 0
    private var transposeSemitones: Int = 0
    private var midiChannelFilter: UInt8 = 0

    func configure(audioEngine: AudioEngineController) {
        lock.lock()
        defer { lock.unlock() }
        self.audioEngine = audioEngine
    }

    func setMIDIChannelFilter(_ channel: UInt8) {
        lock.lock()
        defer { lock.unlock() }
        midiChannelFilter = channel
    }

    func selectBundled(_ pad: BundledPad, layerVolumeOverrides: [String: Float] = [:]) throws {
        lock.lock()
        defer { lock.unlock() }
        guard let audioEngine else {
            throw NSError(domain: "InstrumentPerformanceCore", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Audio engine is not configured."
            ])
        }
        allNotesOffLocked()
        if let layerSpecs = pad.layers {
            effectSampler.tearDown(from: audioEngine)
            usingEffectSampler = false
            let resolvedLayers = layerSpecs.compactMap { spec -> (BundledPad, Float)? in
                guard let layerPad = BundledPad.pad(withID: spec.padID) else { return nil }
                let volume = layerVolumeOverrides[spec.padID] ?? spec.volume
                return (layerPad, volume)
            }
            guard !resolvedLayers.isEmpty else {
                throw NSError(domain: "InstrumentPerformanceCore", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Layered pad \(pad.id) has no valid layers."
                ])
            }
            try layeredSampler.load(padID: pad.id, layers: resolvedLayers, into: audioEngine)
            try audioEngine.connectInstrument(layeredSampler.node)
            usingLayeredSampler = true
        } else if pad.effects != nil {
            layeredSampler.tearDown(from: audioEngine)
            bundledSampler.tearDown(from: audioEngine)
            usingLayeredSampler = false
            try effectSampler.load(pad: pad, into: audioEngine)
            try audioEngine.connectInstrument(effectSampler.node)
            usingEffectSampler = true
        } else {
            effectSampler.tearDown(from: audioEngine)
            layeredSampler.tearDown(from: audioEngine)
            usingEffectSampler = false
            try bundledSampler.load(pad: pad, into: audioEngine)
            try audioEngine.connectInstrument(bundledSampler.node)
            usingLayeredSampler = false
        }
        selectedInstrument = .bundled(pad)
        applyInstrumentVolumeLocked()
        applyPerformanceControlsLocked()
    }

    func selectUserSample(_ sample: UserSampleInstrument, fileURL: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        guard let audioEngine else {
            throw NSError(domain: "InstrumentPerformanceCore", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Audio engine is not configured."
            ])
        }
        if userVoicePool == nil {
            try audioEngine.mutateGraph {
                let engine = audioEngine.engine
                if !engine.attachedNodes.contains(userMixer) {
                    engine.attach(userMixer)
                }
                if userVoicePool == nil {
                    userVoicePool = SampleVoicePool(engine: engine, mixer: userMixer)
                }
            }
        }
        bundledSampler.tearDown(from: audioEngine)
        layeredSampler.tearDown(from: audioEngine)
        effectSampler.tearDown(from: audioEngine)
        usingLayeredSampler = false
        usingEffectSampler = false
        try userVoicePool?.load(sample: sample, from: fileURL)
        try audioEngine.connectInstrument(userMixer)
        selectedInstrument = .user(sample)
        allNotesOffLocked()
        applyInstrumentVolumeLocked()
        applyPerformanceControlsLocked()
    }

    func setInstrumentVolume(_ volume: Float) {
        lock.lock()
        defer { lock.unlock() }
        instrumentVolume = max(0, min(1, volume))
        applyInstrumentVolumeLocked()
    }

    func setLayerVolume(layerPadID: String, volume: Float) {
        lock.lock()
        defer { lock.unlock() }
        layeredSampler.setLayerVolume(padID: layerPadID, volume: volume)
    }

    func setModulation(_ value: Float) {
        lock.lock()
        defer { lock.unlock() }
        modulation = max(0, min(1, value))
        applyModulationLocked()
    }

    func setPitchBend(_ value: Float) {
        lock.lock()
        defer { lock.unlock() }
        pitchBend = max(-1, min(1, value))
        applyPitchBendLocked()
    }

    func setTransposeSemitones(_ semitones: Int) {
        lock.lock()
        defer { lock.unlock() }
        transposeSemitones = max(-12, min(12, semitones))
    }

    func handleMIDI(_ event: MIDINoteEvent) {
        lock.lock()
        defer { lock.unlock() }
        let channelFilter = midiChannelFilter
        guard channelFilter == 0 || event.channel == channelFilter else { return }
        switch event.kind {
        case .noteOn(let note, let velocity):
            if velocity == 0 {
                noteOffLocked(note: note)
            } else {
                noteOnLocked(note: note, velocity: velocity)
            }
        case .noteOff(let note, _):
            noteOffLocked(note: note)
        case .sustain(let isDown):
            setSustainLocked(isDown)
        case .modulation(let value):
            modulation = MIDIUtilities.normalizedModulation(value)
            applyModulationLocked()
        case .pitchBend(let value):
            pitchBend = MIDIUtilities.normalizedPitchBend(value)
            applyPitchBendLocked()
        case .allNotesOff:
            allNotesOffLocked()
        }
    }

    func noteOn(note: UInt8, velocity: UInt8) {
        lock.lock()
        defer { lock.unlock() }
        noteOnLocked(note: note, velocity: velocity)
    }

    func noteOff(note: UInt8) {
        lock.lock()
        defer { lock.unlock() }
        noteOffLocked(note: note)
    }

    func allNotesOff() {
        lock.lock()
        defer { lock.unlock() }
        allNotesOffLocked()
    }

    var currentInstrument: SelectedInstrument {
        lock.lock()
        defer { lock.unlock() }
        return selectedInstrument
    }

    private func noteOnLocked(note: UInt8, velocity: UInt8) {
        sustainedNotes.remove(note)
        let transposedNote = transposed(note)
        switch selectedInstrument {
        case .bundled:
            if usingLayeredSampler {
                layeredSampler.noteOn(note: transposedNote, velocity: velocity)
            } else if usingEffectSampler {
                effectSampler.noteOn(note: transposedNote, velocity: velocity)
            } else {
                bundledSampler.noteOn(note: transposedNote, velocity: velocity)
            }
        case .user:
            userVoicePool?.noteOn(note: transposedNote, velocity: velocity)
        }
    }

    private func noteOffLocked(note: UInt8) {
        if sustainDown && !selectedPadIgnoresSustain() {
            sustainedNotes.insert(note)
            return
        }
        let transposedNote = transposed(note)
        switch selectedInstrument {
        case .bundled:
            if usingLayeredSampler {
                layeredSampler.noteOff(note: transposedNote)
            } else if usingEffectSampler {
                effectSampler.noteOff(note: transposedNote)
            } else {
                bundledSampler.noteOff(note: transposedNote)
            }
        case .user:
            userVoicePool?.noteOff(note: transposedNote)
        }
    }

    private func transposed(_ note: UInt8) -> UInt8 {
        MIDIUtilities.transposedNote(note, by: transposeSemitones)
    }

    private func setSustainLocked(_ isDown: Bool) {
        if selectedPadIgnoresSustain() { return }
        sustainDown = isDown
        if !isDown {
            let notes = sustainedNotes
            sustainedNotes.removeAll()
            notes.forEach { noteOffLocked(note: $0) }
        }
    }

    private func allNotesOffLocked() {
        sustainedNotes.removeAll()
        sustainDown = false
        bundledSampler.allNotesOff()
        effectSampler.allNotesOff()
        layeredSampler.allNotesOff()
        userVoicePool?.allNotesOff()
    }

    private func applyInstrumentVolumeLocked() {
        switch selectedInstrument {
        case .bundled:
            if usingLayeredSampler {
                layeredSampler.setVolume(instrumentVolume)
            } else if usingEffectSampler {
                effectSampler.setVolume(instrumentVolume)
            } else {
                bundledSampler.setVolume(instrumentVolume)
            }
        case .user:
            userMixer.outputVolume = instrumentVolume
        }
    }

    private func applyPerformanceControlsLocked() {
        applyModulationLocked()
        applyPitchBendLocked()
    }

    private func applyModulationLocked() {
        switch selectedInstrument {
        case .bundled:
            if usingLayeredSampler {
                layeredSampler.setModulation(modulation)
            } else if usingEffectSampler {
                effectSampler.setModulation(modulation)
            } else {
                bundledSampler.setModulation(modulation)
            }
        case .user:
            userVoicePool?.setModulation(modulation)
        }
    }

    private func applyPitchBendLocked() {
        switch selectedInstrument {
        case .bundled:
            if usingLayeredSampler {
                layeredSampler.setPitchBend(pitchBend)
            } else if usingEffectSampler {
                effectSampler.setPitchBend(pitchBend)
            } else {
                bundledSampler.setPitchBend(pitchBend)
            }
        case .user:
            userVoicePool?.setPitchBend(pitchBend)
        }
    }

    private func selectedPadIgnoresSustain() -> Bool {
        switch selectedInstrument {
        case .bundled(let pad):
            return pad.articulation?.ignoresSustainPedal ?? false
        case .user:
            return false
        }
    }
}
