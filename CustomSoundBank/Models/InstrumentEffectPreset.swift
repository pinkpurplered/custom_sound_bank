import Foundation

struct AutoWahSettings: Hashable, Codable, Sendable {
    var closedFrequency: Float
    var openFrequency: Float
    /// Frequency reached after the decay phase; defaults to `closedFrequency` when nil.
    var decayTargetFrequency: Float?
    var attackSeconds: Float
    var decaySeconds: Float
    var resonance: Float
    var velocitySensitivity: Float
    var chordTriggerWindow: TimeInterval = 0.015

    var resolvedDecayTarget: Float {
        decayTargetFrequency ?? closedFrequency
    }
}

struct DistortionSettings: Hashable, Codable, Sendable {
    var mix: Float
    var gain: Float
}

struct GateSettings: Hashable, Codable, Sendable {
    var holdSeconds: Float
    var releaseSeconds: Float
}

struct ArticulationSettings: Hashable, Codable, Sendable {
    var maximumNoteDuration: TimeInterval?
    var ignoresSustainPedal: Bool
}

struct InstrumentEffectPreset: Hashable, Codable, Sendable {
    var autoWah: AutoWahSettings?
    var distortion: DistortionSettings?
    var gate: GateSettings?

    static let mutedRockOrgan = InstrumentEffectPreset(
        autoWah: AutoWahSettings(
            closedFrequency: 500,
            openFrequency: 2_800,
            decayTargetFrequency: 700,
            attackSeconds: 0.008,
            decaySeconds: 0.11,
            resonance: 5,
            velocitySensitivity: 0.7
        ),
        distortion: DistortionSettings(
            mix: 0,
            gain: 0
        ),
        gate: GateSettings(
            holdSeconds: 0.06,
            releaseSeconds: 0.025
        )
    )
}
