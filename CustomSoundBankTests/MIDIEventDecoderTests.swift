import XCTest
@testable import CustomSoundBank

final class MIDIEventDecoderTests: XCTestCase {
    func testNoteOnAndOff() {
        let bytes: [UInt8] = [0x90, 60, 100, 0x80, 60, 0]
        let events = MIDIEventDecoder.decode(bytes: bytes)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].kind, .noteOn(note: 60, velocity: 100))
        XCTAssertEqual(events[1].kind, .noteOff(note: 60, velocity: 0))
    }

    func testVelocityZeroNoteOnIsNoteOff() {
        let bytes: [UInt8] = [0x90, 64, 0]
        let events = MIDIEventDecoder.decode(bytes: bytes)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .noteOff(note: 64, velocity: 0))
    }

    func testSustainPedal() {
        let bytes: [UInt8] = [0xB0, 64, 127, 0xB0, 64, 0]
        let events = MIDIEventDecoder.decode(bytes: bytes)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].kind, .sustain(isDown: true))
        XCTAssertEqual(events[1].kind, .sustain(isDown: false))
    }

    func testUMPChannelVoice() {
        let noteOn: UInt32 = 0x20903C64
        let events = MIDIEventDecoder.decodeUMP(words: [noteOn])
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .noteOn(note: 60, velocity: 100))
    }

    func testRunningStatusNoteOn() {
        let bytes: [UInt8] = [0x90, 60, 100, 64, 80]
        let events = MIDIEventDecoder.decode(bytes: bytes)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].kind, .noteOn(note: 60, velocity: 100))
        XCTAssertEqual(events[1].kind, .noteOn(note: 64, velocity: 80))
    }

    func testPitchBendBeforeNoteOn() {
        let bytes: [UInt8] = [0xE0, 0, 64, 0x90, 60, 100]
        let events = MIDIEventDecoder.decode(bytes: bytes)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].kind, .pitchBend(value: 8192))
        XCTAssertEqual(events[1].kind, .noteOn(note: 60, velocity: 100))
    }

    func testModulationWheel() {
        let bytes: [UInt8] = [0xB0, 1, 100]
        let events = MIDIEventDecoder.decode(bytes: bytes)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .modulation(value: 100))
    }

    func testSysExBeforeNoteOn() {
        let bytes: [UInt8] = [0xF0, 0x7E, 0x7F, 0x06, 0x01, 0xF7, 0x90, 60, 100]
        let events = MIDIEventDecoder.decode(bytes: bytes)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .noteOn(note: 60, velocity: 100))
    }

    func testIgnoresOrphanDataBytes() {
        let bytes: [UInt8] = [0x3C, 0x90, 60, 100]
        let events = MIDIEventDecoder.decode(bytes: bytes)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .noteOn(note: 60, velocity: 100))
    }
}

final class MIDIUtilitiesTests: XCTestCase {
    func testTranspositionCents() {
        XCTAssertEqual(MIDIUtilities.transpositionCents(from: 60, to: 72), 1200)
        XCTAssertEqual(MIDIUtilities.transpositionCents(from: 60, to: 60), 0)
        XCTAssertEqual(MIDIUtilities.transpositionCents(from: 60, to: 59), -100)
    }

    func testNoteName() {
        XCTAssertEqual(MIDIUtilities.noteName(for: 60), "C4")
        XCTAssertEqual(MIDIUtilities.noteName(for: 61), "C#4")
    }

    func testPitchBendConversion() {
        XCTAssertEqual(MIDIUtilities.normalizedPitchBend(8192), 0, accuracy: 0.001)
        XCTAssertEqual(MIDIUtilities.pitchBendMIDIValue(from: 0), 8192)
        XCTAssertEqual(MIDIUtilities.pitchBendCents(from: 1), 200)
    }
}

final class SampleLibraryManifestTests: XCTestCase {
    func testManifestRoundTrip() throws {
        let manifest = SampleLibraryManifest(
            version: 1,
            samples: [
                UserSampleInstrument(name: "Clap", fileName: "a.caf", rootNote: 36)
            ]
        )
        let data = try JSONEncoder().encode(manifest)
        let decoded = try JSONDecoder().decode(SampleLibraryManifest.self, from: data)
        XCTAssertEqual(decoded, manifest)
    }
}
