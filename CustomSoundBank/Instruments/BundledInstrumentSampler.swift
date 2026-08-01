import AudioToolbox
import AVFoundation
import Foundation

@MainActor
final class BundledInstrumentSampler {
    private static let generalMIDIBankPath =
        "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"

    private let sampler = AVAudioUnitSampler()
    private var loadedKind: InstrumentKind?

    var node: AVAudioNode { sampler }

    func load(kind: InstrumentKind, into engine: AudioEngineController) throws {
        engine.attach(node: sampler)
        guard loadedKind != kind else { return }

        guard let program = kind.gmProgram else {
            throw NSError(domain: "BundledInstrumentSampler", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No instrument program for \(kind.displayName)"
            ])
        }

        let bankURL = URL(fileURLWithPath: Self.generalMIDIBankPath)
        guard FileManager.default.fileExists(atPath: bankURL.path) else {
            throw NSError(domain: "BundledInstrumentSampler", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "System General MIDI bank is unavailable."
            ])
        }

        try sampler.loadSoundBankInstrument(
            at: bankURL,
            program: program,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )
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
