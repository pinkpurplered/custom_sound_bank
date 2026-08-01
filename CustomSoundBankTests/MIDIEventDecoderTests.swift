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
