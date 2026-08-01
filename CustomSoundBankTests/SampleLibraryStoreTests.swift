import XCTest
@testable import CustomSoundBank

final class SampleLibraryStoreTests: XCTestCase {
    func testImportRenameAndDelete() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SampleLibraryStore(rootDirectory: root)
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("sample.caf")
        try Data([0, 1, 2, 3]).write(to: source)

        let sample = try await store.importRecording(
            from: source,
            name: "Test",
            rootNote: 60,
            trimStart: 0,
            trimEnd: 1
        )

        let imported = await store.allSamples()
        XCTAssertEqual(imported.count, 1)

        try await store.rename(id: sample.id, to: "Renamed")
        let renamed = await store.sample(id: sample.id)
        XCTAssertEqual(renamed?.name, "Renamed")

        let fileURL = await store.fileURL(for: sample)
        try await store.delete(id: sample.id)
        let remaining = await store.allSamples()
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
