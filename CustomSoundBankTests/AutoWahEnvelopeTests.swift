import XCTest
@testable import CustomSoundBank

final class AutoWahEnvelopeTests: XCTestCase {
    private let settings = AutoWahSettings(
        closedFrequency: 500,
        openFrequency: 2_800,
        decayTargetFrequency: 700,
        attackSeconds: 0.008,
        decaySeconds: 0.11,
        resonance: 5,
        velocitySensitivity: 0.7,
        chordTriggerWindow: 0.015
    )

    func testHigherVelocityProducesHigherFilterPeak() {
        let soft = AutoWahEnvelope.peakFrequency(velocity: 30, settings: settings)
        let loud = AutoWahEnvelope.peakFrequency(velocity: 100, settings: settings)
        let max = AutoWahEnvelope.peakFrequency(velocity: 127, settings: settings)

        XCTAssertLessThan(soft, loud)
        XCTAssertLessThanOrEqual(loud, max)
        XCTAssertLessThanOrEqual(max, settings.openFrequency)
    }

    func testChordNotesTriggerOneFilterEnvelope() {
        let envelope = AutoWahEnvelope()
        envelope.configure(settings: settings)

        envelope.trigger(velocity: 100) { _ in }
        envelope.trigger(velocity: 90) { _ in }
        envelope.trigger(velocity: 80) { _ in }

        XCTAssertEqual(envelope.triggerCount, 1)
    }

    func testSeparateChordsTriggerSeparateEnvelopes() {
        let envelope = AutoWahEnvelope()
        envelope.configure(settings: settings)

        envelope.trigger(velocity: 100) { _ in }
        Thread.sleep(forTimeInterval: settings.chordTriggerWindow + 0.01)
        envelope.trigger(velocity: 100) { _ in }

        XCTAssertEqual(envelope.triggerCount, 2)
    }
}
