import Foundation

enum MIDIUtilities {
    static func noteName(for midiNote: UInt8) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(midiNote) / 12 - 1
        let name = names[Int(midiNote) % 12]
        return "\(name)\(octave)"
    }

    static func transpositionCents(from rootNote: UInt8, to midiNote: UInt8) -> Float {
        Float(Int(midiNote) - Int(rootNote)) * 100
    }

    static func clampVelocity(_ velocity: UInt8) -> Float {
        max(0.05, Float(velocity) / 127.0)
    }
}
