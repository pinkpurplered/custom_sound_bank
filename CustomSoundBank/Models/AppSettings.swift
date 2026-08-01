import Foundation

struct AppSettings: Equatable, Sendable {
    var masterVolume: Float
    var midiChannel: UInt8
    var favoriteBundledPadIDs: [String]
    var favoriteUserSampleIDs: [UUID]
    var bundledPadVolumes: [String: Float]
    var userSampleVolumes: [UUID: Float]

    static let `default` = AppSettings(
        masterVolume: 0.85,
        midiChannel: 0,
        favoriteBundledPadIDs: BundledPad.defaultFavoritePadIDs,
        favoriteUserSampleIDs: [],
        bundledPadVolumes: [:],
        userSampleVolumes: [:]
    )
}
