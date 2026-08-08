import XCTest
@testable import CustomSoundBank

final class AudioSessionConfigurationTests: XCTestCase {
    func testUSBOutputPrefers48kHz() {
        XCTAssertEqual(AudioSessionConfiguration.preferredSampleRate(for: .sharedInstance()), 44_100)
    }

    func testUSBOutputUsesLongerBuffer() {
        let builtInBuffer = AudioSessionConfiguration.preferredIOBufferDuration(for: .sharedInstance())
        XCTAssertGreaterThanOrEqual(builtInBuffer, 0.005)
        XCTAssertLessThanOrEqual(builtInBuffer, 0.010)
    }
}
