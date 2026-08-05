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

    static func transposedNote(_ note: UInt8, by semitones: Int) -> UInt8 {
        UInt8(max(0, min(127, Int(note) + semitones)))
    }

    static func clampVelocity(_ velocity: UInt8) -> Float {
        max(0.05, Float(velocity) / 127.0)
    }

    static func normalizedModulation(_ value: UInt8) -> Float {
        Float(value) / 127.0
    }

    static func normalizedPitchBend(_ value: UInt16) -> Float {
        (Float(value) - 8192.0) / 8192.0
    }

    static func pitchBendMIDIValue(from normalized: Float) -> UInt16 {
        let clamped = max(-1, min(1, normalized))
        return UInt16((clamped * 8192.0) + 8192.0)
    }

    static func pitchBendCents(from normalized: Float, range: Float = 200) -> Float {
        max(-1, min(1, normalized)) * range
    }
}
