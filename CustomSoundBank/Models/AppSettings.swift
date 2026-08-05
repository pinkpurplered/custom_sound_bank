import Foundation

struct AppSettings: Equatable, Sendable {
    var masterVolume: Float
    var midiChannel: UInt8
    var transposeSemitones: Int
    var favoriteBundledPadIDs: [String]
    var favoriteUserSampleIDs: [UUID]
    var bundledPadVolumes: [String: Float]
    var userSampleVolumes: [UUID: Float]
    /// Per-layer volume overrides for layered pads: layeredPadID → layerPadID → volume.
    var layeredPadLayerVolumes: [String: [String: Float]]

    static let `default` = AppSettings(
        masterVolume: 0.85,
        midiChannel: 0,
        transposeSemitones: 0,
        favoriteBundledPadIDs: BundledPad.defaultFavoritePadIDs,
        favoriteUserSampleIDs: [],
        bundledPadVolumes: [:],
        userSampleVolumes: [:],
        layeredPadLayerVolumes: [:]
    )
}
