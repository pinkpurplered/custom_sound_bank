import Foundation

/// Catalog-level makeup gain so bundled instruments play at similar loudness.
enum PlaybackGain {
    /// Upper bound for per-instrument boost to limit clipping risk.
    static let maximumBoost: Float = 2.5

    static func forPad(_ pad: BundledPad) -> Float {
        var gain = soundFontGain(pad.soundFontFileName)
        if pad.soundFontFileName == nil {
            gain *= categoryGain(pad.category)
        }
        if let effects = pad.effects {
            gain *= effectChainGain(effects)
        }
        return min(maximumBoost, gain)
    }

    private static func soundFontGain(_ fileName: String?) -> Float {
        switch fileName {
        case "DoreMark-Fazioli-F308":
            // Dedicated grand-piano bank runs much hotter than GeneralUser-GS.
            return 0.55
        case "FreePats-DrawbarOrgan", "FreePats-PercussiveOrgan":
            return 2.6
        case "FreePats-RockOrgan":
            return 2.8
        case "FreePats-PipeOrgan":
            return 2.2
        default:
            return 1.0
        }
    }

    private static func categoryGain(_ category: PadCategory) -> Float {
        switch category {
        case .organ:
            // GM organ programs in GeneralUser-GS are noticeably quieter than piano.
            return 1.75
        case .strings, .choir:
            return 1.25
        case .woodwind, .brass:
            return 1.15
        case .piano:
            return 0.95
        case .guitar, .synthLead:
            return 0.9
        case .bass:
            return 1.05
        case .musicBox, .percussion:
            return 1.1
        case .synthPad, .ethnic:
            return 1.0
        }
    }

    private static func effectChainGain(_ preset: InstrumentEffectPreset) -> Float {
        var gain: Float = 1.0
        if preset.autoWah != nil {
            // Low-pass filtering at closed frequencies cuts a lot of energy.
            gain *= 2.0
        }
        if let distortion = preset.distortion, distortion.mix > 0 {
            gain *= 1.15
        }
        return gain
    }
}
