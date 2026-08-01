import Foundation

struct SampleLibraryManifest: Codable, Equatable {
    static let currentVersion = 1

    var version: Int
    var samples: [UserSampleInstrument]

    static let empty = SampleLibraryManifest(version: currentVersion, samples: [])
}

actor SampleLibraryStore {
    enum StoreError: LocalizedError {
        case sampleNotFound
        case invalidManifest

        var errorDescription: String? {
            switch self {
            case .sampleNotFound: return "Sample not found."
            case .invalidManifest: return "Sample library manifest is invalid."
            }
        }
    }

    private let fileManager = FileManager.default
    private let manifestURL: URL
    private let samplesDirectory: URL
    private var manifest: SampleLibraryManifest

    init(rootDirectory: URL? = nil) {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = rootDirectory ?? support.appendingPathComponent("CustomSoundBank", isDirectory: true)
        samplesDirectory = root.appendingPathComponent("Samples", isDirectory: true)
        manifestURL = root.appendingPathComponent("manifest.json")
        try? fileManager.createDirectory(at: samplesDirectory, withIntermediateDirectories: true)
        manifest = (try? Self.loadManifest(from: manifestURL)) ?? .empty
    }

    func allSamples() -> [UserSampleInstrument] {
        manifest.samples.sorted { $0.createdAt > $1.createdAt }
    }

    func sample(id: UUID) -> UserSampleInstrument? {
        manifest.samples.first { $0.id == id }
    }

    func fileURL(for sample: UserSampleInstrument) -> URL {
        samplesDirectory.appendingPathComponent(sample.fileName)
    }

    func importRecording(
        from sourceURL: URL,
        name: String,
        rootNote: UInt8,
        trimStart: Double,
        trimEnd: Double?
    ) throws -> UserSampleInstrument {
        let id = UUID()
        let fileName = "\(id.uuidString).caf"
        let destination = samplesDirectory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)

        let sample = UserSampleInstrument(
            id: id,
            name: name,
            fileName: fileName,
            rootNote: rootNote,
            trimStartSeconds: trimStart,
            trimEndSeconds: trimEnd
        )
        manifest.samples.append(sample)
        try persist()
        return sample
    }

    func rename(id: UUID, to newName: String) throws {
        guard let index = manifest.samples.firstIndex(where: { $0.id == id }) else {
            throw StoreError.sampleNotFound
        }
        manifest.samples[index].name = newName
        try persist()
    }

    func delete(id: UUID) throws {
        guard let index = manifest.samples.firstIndex(where: { $0.id == id }) else {
            throw StoreError.sampleNotFound
        }
        let sample = manifest.samples.remove(at: index)
        let url = fileURL(for: sample)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        try persist()
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: manifestURL, options: .atomic)
    }

    private static func loadManifest(from url: URL) throws -> SampleLibraryManifest {
        let data = try Data(contentsOf: url)
        let manifest = try JSONDecoder().decode(SampleLibraryManifest.self, from: data)
        guard manifest.version <= SampleLibraryManifest.currentVersion else {
            throw StoreError.invalidManifest
        }
        return manifest
    }
}
