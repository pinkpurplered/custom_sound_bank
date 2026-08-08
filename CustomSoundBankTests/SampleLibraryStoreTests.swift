import AVFoundation
import XCTest
@testable import CustomSoundBank

final class SampleLibraryStoreTests: XCTestCase {
    func testImportRenameAndDelete() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SampleLibraryStore(rootDirectory: root)
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("sample.wav")
        try writeTestWAV(to: source, duration: 0.2)

        let sample = try await store.importRecording(
            from: source,
            name: "Test",
            rootNote: 60,
            trimStart: 0,
            trimEnd: 0.1
        )

        let imported = await store.allSamples()
        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(imported.first?.trimStartSeconds, 0)
        XCTAssertNil(imported.first?.trimEndSeconds)

        try await store.rename(id: sample.id, to: "Renamed")
        let renamed = await store.sample(id: sample.id)
        XCTAssertEqual(renamed?.name, "Renamed")

        let fileURL = await store.fileURL(for: sample)
        try await store.delete(id: sample.id)
        let remaining = await store.allSamples()
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    private func writeTestWAV(to url: URL, duration: Double) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44_100,
            channels: 1,
            interleaved: false
        ) else {
            XCTFail("Could not create audio format")
            return
        }

        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            XCTFail("Could not create audio buffer")
            return
        }
        buffer.frameLength = frameCount

        if let channelData = buffer.floatChannelData {
            for frame in 0..<Int(frameCount) {
                channelData[0][frame] = 0.1
            }
        }

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
}
