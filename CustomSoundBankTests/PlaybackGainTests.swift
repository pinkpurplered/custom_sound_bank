import XCTest
@testable import CustomSoundBank

final class PlaybackGainTests: XCTestCase {
    func testFazioliPianoIsAttenuated() {
        let pad = BundledPad.pad(withID: "piano_fazioli_f308")!
        XCTAssertLessThan(PlaybackGain.forPad(pad), 1.0)
    }

    func testGeneralUserOrganIsBoosted() {
        let pad = BundledPad.pad(withID: "organ_church")!
        XCTAssertGreaterThan(PlaybackGain.forPad(pad), 1.0)
    }

    func testFreePatsOrganIsBoostedMoreThanGeneralUser() {
        let church = BundledPad.pad(withID: "organ_church")!
        let hammond = BundledPad.pad(withID: "organ_hammond_drawbar")!
        XCTAssertGreaterThan(PlaybackGain.forPad(hammond), PlaybackGain.forPad(church))
    }

    func testMutedRockOrganIncludesEffectMakeup() {
        let rock = BundledPad.pad(withID: "organ_rock")!
        let muted = BundledPad.pad(withID: "organ_muted_rock")!
        XCTAssertGreaterThan(PlaybackGain.forPad(muted), PlaybackGain.forPad(rock))
    }

    func testGainStaysWithinMaximumBoost() {
        for pad in BundledPad.catalog {
            XCTAssertLessThanOrEqual(PlaybackGain.forPad(pad), PlaybackGain.maximumBoost)
            XCTAssertGreaterThan(PlaybackGain.forPad(pad), 0)
        }
    }
}
