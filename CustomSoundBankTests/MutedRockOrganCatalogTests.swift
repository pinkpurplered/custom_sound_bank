import XCTest
@testable import CustomSoundBank

final class InstrumentEffectPresetTests: XCTestCase {
    func testMutedRockOrganPresetHasExpectedFilterRange() {
        let preset = InstrumentEffectPreset.mutedRockOrgan
        XCTAssertEqual(preset.autoWah?.closedFrequency, 500)
        XCTAssertEqual(preset.autoWah?.openFrequency, 2_800)
        XCTAssertEqual(preset.autoWah?.decayTargetFrequency, 700)
    }

    func testMutedRockOrganExistsInOrganCategory() {
        let pad = BundledPad.pad(withID: "organ_muted_rock")
        XCTAssertNotNil(pad)
        XCTAssertEqual(pad?.displayName, "Muted Rock Organ")
        XCTAssertEqual(pad?.category, .organ)
        XCTAssertEqual(pad?.soundFontFileName, "FreePats-RockOrgan")
        XCTAssertNotNil(pad?.effects)
        XCTAssertEqual(pad?.articulation?.ignoresSustainPedal, true)
        XCTAssertEqual(pad?.effects?.distortion?.mix, 0)
    }

    func testRockOrganIsSingleInstrument() {
        let pad = BundledPad.pad(withID: "organ_rock")
        XCTAssertNotNil(pad)
        XCTAssertFalse(pad?.isLayered == true)
        XCTAssertEqual(pad?.gmProgram, 18)
    }

    func testHammondRockOrganUsesRockOrganSoundFont() {
        let pad = BundledPad.pad(withID: "organ_hammond_rock")
        XCTAssertNotNil(pad)
        XCTAssertEqual(pad?.soundFontFileName, "FreePats-RockOrgan")
        XCTAssertNil(pad?.effects)
    }
}
