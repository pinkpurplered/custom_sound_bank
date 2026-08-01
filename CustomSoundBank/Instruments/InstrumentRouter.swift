import AVFoundation
import Foundation

@MainActor
final class InstrumentRouter: ObservableObject {
    @Published private(set) var selectedInstrument: SelectedInstrument = .bundled(BundledPad.defaultPad)
    @Published private(set) var activeNotes = Set<UInt8>()
    @Published private(set) var lastError: String?
    @Published private(set) var modulation: Float = 0
    @Published private(set) var pitchBend: Float = 0

    private let bundledSampler = BundledInstrumentSampler()
    private var bundledMixer = AVAudioMixerNode()
    private var userVoicePool: SampleVoicePool?
    private var userMixer = AVAudioMixerNode()
    private weak var audioEngine: AudioEngineController?
    private var sustainDown = false
    private var sustainedNotes = Set<UInt8>()
    private var instrumentVolume: Float = 1

    func configure(audioEngine: AudioEngineController) {
        self.audioEngine = audioEngine
        audioEngine.attach(node: bundledMixer)
    }

    func selectBundled(_ pad: BundledPad) {
        do {
            guard let audioEngine else { return }
            allNotesOff()
            try bundledSampler.load(pad: pad, into: audioEngine)
            try audioEngine.mutateGraph {
                let samplerNode = bundledSampler.node
                if !audioEngine.engine.attachedNodes.contains(samplerNode) {
                    audioEngine.engine.attach(samplerNode)
                }
                let outputs = audioEngine.engine.outputConnectionPoints(for: samplerNode, outputBus: 0)
                if !outputs.contains(where: { $0.node === bundledMixer }) {
                    audioEngine.engine.connect(samplerNode, to: bundledMixer, format: nil)
                }
            }
            try audioEngine.connectInstrument(bundledMixer)
            selectedInstrument = .bundled(pad)
            applyInstrumentVolume()
            applyPerformanceControls()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func selectUserSample(_ sample: UserSampleInstrument, fileURL: URL) async throws {
        guard let audioEngine else { return }
        if userVoicePool == nil {
            audioEngine.attach(node: userMixer)
            userVoicePool = SampleVoicePool(engine: audioEngine.engine, mixer: userMixer)
        }
        try userVoicePool?.load(sample: sample, from: fileURL)
        try audioEngine.connectInstrument(userMixer)
        selectedInstrument = .user(sample)
        allNotesOff()
        applyInstrumentVolume()
        applyPerformanceControls()
        lastError = nil
    }

    func setInstrumentVolume(_ volume: Float) {
        instrumentVolume = max(0, min(1, volume))
        applyInstrumentVolume()
    }

    func setModulation(_ value: Float) {
        modulation = max(0, min(1, value))
        applyModulation()
    }

    func setPitchBend(_ value: Float) {
        pitchBend = max(-1, min(1, value))
        applyPitchBend()
    }

    private static let previewNote: UInt8 = 60
    private static let previewVelocity: UInt8 = 100
    private var previewNoteTask: Task<Void, Never>?

    func playPreviewNote() {
        previewNoteTask?.cancel()
        let note = Self.previewNote
        previewNoteTask = Task {
            noteOn(note: note, velocity: Self.previewVelocity)
            try? await Task.sleep(for: .seconds(1.25))
            guard !Task.isCancelled else { return }
            noteOff(note: note)
        }
    }

    func handleMIDI(_ event: MIDINoteEvent, channelFilter: UInt8) {
        guard channelFilter == 0 || event.channel == channelFilter else { return }
        switch event.kind {
        case .noteOn(let note, let velocity): noteOn(note: note, velocity: velocity)
        case .noteOff(let note, _): noteOff(note: note)
        case .sustain(let isDown): setSustain(isDown)
        case .modulation(let value):
            setModulation(MIDIUtilities.normalizedModulation(value))
        case .pitchBend(let value):
            setPitchBend(MIDIUtilities.normalizedPitchBend(value))
        case .allNotesOff: allNotesOff()
        }
    }

    func noteOn(note: UInt8, velocity: UInt8) {
        activeNotes.insert(note)
        sustainedNotes.remove(note)
        switch selectedInstrument {
        case .bundled: bundledSampler.noteOn(note: note, velocity: velocity)
        case .user: userVoicePool?.noteOn(note: note, velocity: velocity)
        }
    }

    func noteOff(note: UInt8) {
        if sustainDown {
            sustainedNotes.insert(note)
            return
        }
        activeNotes.remove(note)
        switch selectedInstrument {
        case .bundled: bundledSampler.noteOff(note: note)
        case .user: userVoicePool?.noteOff(note: note)
        }
    }

    func setSustain(_ isDown: Bool) {
        sustainDown = isDown
        if !isDown {
            let notes = sustainedNotes
            sustainedNotes.removeAll()
            notes.forEach { noteOff(note: $0) }
        }
    }

    func allNotesOff() {
        activeNotes.removeAll()
        sustainedNotes.removeAll()
        sustainDown = false
        bundledSampler.allNotesOff()
        userVoicePool?.allNotesOff()
    }

    private func applyInstrumentVolume() {
        switch selectedInstrument {
        case .bundled:
            bundledMixer.outputVolume = instrumentVolume
        case .user:
            userMixer.outputVolume = instrumentVolume
        }
    }

    private func applyPerformanceControls() {
        applyModulation()
        applyPitchBend()
    }

    private func applyModulation() {
        switch selectedInstrument {
        case .bundled:
            bundledSampler.setModulation(UInt8(modulation * 127))
        case .user:
            userVoicePool?.setModulation(modulation)
        }
    }

    private func applyPitchBend() {
        let midiValue = MIDIUtilities.pitchBendMIDIValue(from: pitchBend)
        switch selectedInstrument {
        case .bundled:
            bundledSampler.setPitchBend(midiValue)
        case .user:
            userVoicePool?.setPitchBend(pitchBend)
        }
    }
}
