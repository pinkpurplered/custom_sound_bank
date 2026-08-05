import AVFoundation
import Foundation

@MainActor
final class InstrumentRouter: ObservableObject {
    @Published private(set) var selectedInstrument: SelectedInstrument = .bundled(BundledPad.defaultPad)
    @Published private(set) var activeNotes = Set<UInt8>()
    @Published private(set) var lastError: String?
    @Published private(set) var modulation: Float = 0
    @Published private(set) var pitchBend: Float = 0
    @Published private(set) var transposeSemitones: Int = 0

    let performanceCore = InstrumentPerformanceCore()

    private var sustainDown = false
    private var sustainedNotes = Set<UInt8>()
    private var previewNoteTask: Task<Void, Never>?

    private static let previewNote: UInt8 = 60
    private static let previewVelocity: UInt8 = 100

    func configure(audioEngine: AudioEngineController) {
        performanceCore.configure(audioEngine: audioEngine)
    }

    func selectBundled(_ pad: BundledPad, layerVolumeOverrides: [String: Float] = [:]) {
        do {
            try performanceCore.selectBundled(pad, layerVolumeOverrides: layerVolumeOverrides)
            selectedInstrument = .bundled(pad)
            allNotesOff()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func selectUserSample(_ sample: UserSampleInstrument, fileURL: URL) async throws {
        try performanceCore.selectUserSample(sample, fileURL: fileURL)
        selectedInstrument = .user(sample)
        allNotesOff()
        lastError = nil
    }

    func setInstrumentVolume(_ volume: Float) {
        performanceCore.setInstrumentVolume(volume)
    }

    func setLayerVolume(layerPadID: String, volume: Float) {
        performanceCore.setLayerVolume(layerPadID: layerPadID, volume: volume)
    }

    func setModulation(_ value: Float) {
        modulation = max(0, min(1, value))
        performanceCore.setModulation(modulation)
    }

    func setPitchBend(_ value: Float) {
        pitchBend = max(-1, min(1, value))
        performanceCore.setPitchBend(pitchBend)
    }

    func setTransposeSemitones(_ semitones: Int) {
        let clamped = max(-12, min(12, semitones))
        guard clamped != transposeSemitones else { return }
        transposeSemitones = clamped
        performanceCore.setTransposeSemitones(clamped)
        allNotesOff()
    }

    func setMIDIChannelFilter(_ channel: UInt8) {
        performanceCore.setMIDIChannelFilter(channel)
    }

    func playPreviewNote() {
        previewNoteTask?.cancel()
        let note = MIDIUtilities.transposedNote(Self.previewNote, by: transposeSemitones)
        previewNoteTask = Task {
            noteOn(note: note, velocity: Self.previewVelocity)
            try? await Task.sleep(for: .seconds(1.25))
            guard !Task.isCancelled else { return }
            noteOff(note: note)
        }
    }

    func handleMIDIUI(_ event: MIDINoteEvent, channelFilter: UInt8) {
        guard channelFilter == 0 || event.channel == channelFilter else { return }
        switch event.kind {
        case .noteOn(let note, let velocity):
            guard velocity > 0 else {
                noteOff(note: note)
                return
            }
            activeNotes.insert(note)
            sustainedNotes.remove(note)
        case .noteOff(let note, _):
            if sustainDown {
                sustainedNotes.insert(note)
                return
            }
            activeNotes.remove(note)
        case .sustain(let isDown):
            sustainDown = isDown
            if !isDown {
                let notes = sustainedNotes
                sustainedNotes.removeAll()
                notes.forEach { activeNotes.remove($0) }
            }
        case .modulation(let value):
            modulation = MIDIUtilities.normalizedModulation(value)
        case .pitchBend(let value):
            pitchBend = MIDIUtilities.normalizedPitchBend(value)
        case .allNotesOff:
            activeNotes.removeAll()
            sustainedNotes.removeAll()
            sustainDown = false
        }
    }

    func noteOn(note: UInt8, velocity: UInt8) {
        activeNotes.insert(note)
        sustainedNotes.remove(note)
        performanceCore.noteOn(note: note, velocity: velocity)
    }

    func noteOff(note: UInt8) {
        if sustainDown {
            sustainedNotes.insert(note)
            return
        }
        activeNotes.remove(note)
        performanceCore.noteOff(note: note)
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
        performanceCore.allNotesOff()
    }
}
