import Foundation

struct LiveSet: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var favoriteBundledPadIDs: [String]
    var favoriteUserSampleIDs: [UUID]
    var bundledPadVolumes: [String: Float]
    var userSampleVolumeStrings: [String: Float]
    var layeredPadLayerVolumes: [String: [String: Float]]
    var selectedBundledPadID: String?
    var selectedUserSampleID: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        favoriteBundledPadIDs: [String] = [],
        favoriteUserSampleIDs: [UUID] = [],
        bundledPadVolumes: [String: Float] = [:],
        userSampleVolumes: [UUID: Float] = [:],
        layeredPadLayerVolumes: [String: [String: Float]] = [:],
        selectedBundledPadID: String? = nil,
        selectedUserSampleID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.favoriteBundledPadIDs = favoriteBundledPadIDs
        self.favoriteUserSampleIDs = favoriteUserSampleIDs
        self.bundledPadVolumes = bundledPadVolumes
        self.userSampleVolumeStrings = userSampleVolumes.reduce(into: [:]) { result, pair in
            result[pair.key.uuidString] = pair.value
        }
        self.layeredPadLayerVolumes = layeredPadLayerVolumes
        self.selectedBundledPadID = selectedBundledPadID
        self.selectedUserSampleID = selectedUserSampleID
    }

    var userSampleVolumes: [UUID: Float] {
        userSampleVolumeStrings.reduce(into: [:]) { result, pair in
            if let id = UUID(uuidString: pair.key) {
                result[id] = pair.value
            }
        }
    }

    static func from(
        name: String,
        settings: AppSettings,
        selectedBundledPadID: String?,
        selectedUserSampleID: UUID?
    ) -> LiveSet {
        LiveSet(
            name: name,
            favoriteBundledPadIDs: settings.favoriteBundledPadIDs,
            favoriteUserSampleIDs: settings.favoriteUserSampleIDs,
            bundledPadVolumes: settings.bundledPadVolumes,
            userSampleVolumes: settings.userSampleVolumes,
            layeredPadLayerVolumes: settings.layeredPadLayerVolumes,
            selectedBundledPadID: selectedBundledPadID,
            selectedUserSampleID: selectedUserSampleID
        )
    }

    func apply(to settings: inout AppSettings) {
        settings.favoriteBundledPadIDs = favoriteBundledPadIDs
        settings.favoriteUserSampleIDs = favoriteUserSampleIDs
        settings.bundledPadVolumes = bundledPadVolumes
        settings.userSampleVolumes = userSampleVolumes
        settings.layeredPadLayerVolumes = layeredPadLayerVolumes
    }
}
