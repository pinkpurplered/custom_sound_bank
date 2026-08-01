import AVFoundation
import Foundation

@MainActor
final class InstrumentRouter: ObservableObject {
    @Published private(set) var selectedInstrument: SelectedInstrument = .bundled(.piano)
    @Published private(set) var activeNotes = Set<UInt8>()
    @Published private(set) var lastError: String?

    private let bundledSampler = BundledInstrumentSampler()
    private var userVoicePool: UserSampleVoicePool?
    private var userMixer = AVAudioMixerNode()
    private weak var audioEngine: AudioEngineController?
    private var sustainDown = false
    private var sustainedNotes = Set<UInt8>()

    func configure(audioEngine: AudioEngineController) {
        self.audioEngine = audioEngine
        audioEngine.attach(node: userMixer)
    }

    func selectBundled(_ kind: InstrumentKind) {
        Task {
            do {
                guard let audioEngine else { return }
                try bundledSampler.load(kind: kind, into: audioEngine)
                audioEngine.replaceOutputNode(bundledSampler.node)
                selectedInstrument = .bundled(kind)
                allNotesOff()
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func selectUserSample(_ sample: UserSampleInstrument, fileURL: URL) {
        Task {
            do {
                guard let audioEngine else { return }
                if userVoicePool == nil {
                    userVoicePool = UserSampleVoicePool(engine: audioEngine.engine, mixer: userMixer)
                }
                try userVoicePool?.load(sample: sample, from: fileURL)
                audioEngine.replaceOutputNode(userMixer)
                selectedInstrument = .user(sample)
                allNotesOff()
                lastError = nil
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    func handleMIDI(_ event: MIDINoteEvent, channelFilter: UInt8) {
        guard event.channel == channelFilter else { return }

        switch event.kind {
        case .noteOn(let note, let velocity):
            noteOn(note: note, velocity: velocity)
        case .noteOff(let note, _):
            noteOff(note: note)
        case .sustain(let isDown):
            setSustain(isDown)
        case .allNotesOff:
            allNotesOff()
        }
    }

    func noteOn(note: UInt8, velocity: UInt8) {
        activeNotes.insert(note)
        sustainedNotes.remove(note)
        switch selectedInstrument {
        case .bundled:
            bundledSampler.noteOn(note: note, velocity: velocity)
        case .user:
            userVoicePool?.noteOn(note: note, velocity: velocity)
        }
    }

    func noteOff(note: UInt8) {
        if sustainDown {
            sustainedNotes.insert(note)
            return
        }
        activeNotes.remove(note)
        switch selectedInstrument {
        case .bundled:
            bundledSampler.noteOff(note: note)
        case .user:
            userVoicePool?.noteOff(note: note)
        }
    }

    func setSustain(_ isDown: Bool) {
        sustainDown = isDown
        userVoicePool?.setSustain(isDown)
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
}
