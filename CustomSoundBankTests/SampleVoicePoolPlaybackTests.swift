import AVFoundation
import XCTest
@testable import CustomSoundBank

/// Exercises the record → save → play path that was crashing in the app.
@MainActor
final class SampleVoicePoolPlaybackTests: XCTestCase {
    override func tearDown() async throws {
        AppModel.current?.instrumentRouter.allNotesOff()
        try await Task.sleep(for: .milliseconds(150))
        AppModel.current?.resumePerformanceAudio()
        try await Task.sleep(for: .milliseconds(150))
    }

    func testSaveFlowSelectsSampleBeforeEngineStarts() async throws {
        guard let appModel = AppModel.current else {
            XCTFail("AppModel is not available in the test host.")
            return
        }

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SampleLibraryStore(rootDirectory: root)
        let source = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        try writeTestWAV(to: source, duration: 0.15)

        let sample = try await store.importRecording(
            from: source,
            name: "Save Flow",
            rootNote: 60,
            trimStart: 0,
            trimEnd: nil
        )
        let fileURL = await store.fileURL(for: sample)

        appModel.suspendPerformanceAudio()
        defer { appModel.resumePerformanceAudio() }

        XCTAssertFalse(appModel.audioEngine.engine.isRunning)
        try await appModel.instrumentRouter.selectUserSample(sample, fileURL: fileURL)
        XCTAssertFalse(appModel.audioEngine.engine.isRunning)
        try appModel.audioEngine.start()
        XCTAssertTrue(appModel.audioEngine.engine.isRunning)
        try await Task.sleep(for: .milliseconds(200))

        try? FileManager.default.removeItem(at: source)
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
                let t = Double(frame) / format.sampleRate
                channelData[0][frame] = Float(sin(t * 440 * 2 * .pi) * 0.25)
            }
        }

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
    }
}
