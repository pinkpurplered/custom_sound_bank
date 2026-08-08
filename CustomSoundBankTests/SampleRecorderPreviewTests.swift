import AVFoundation
import XCTest
@testable import CustomSoundBank

@MainActor
final class SampleRecorderPreviewTests: XCTestCase {
    override func tearDown() async throws {
        try await Task.sleep(for: .milliseconds(150))
        AppModel.current?.resumePerformanceAudio()
        try await Task.sleep(for: .milliseconds(150))
    }

    func testRecordingPreviewDoesNotCrash() async throws {
        guard let appModel = AppModel.current else {
            XCTFail("AppModel is not available in the test host.")
            return
        }

        let recorder = SampleRecorder()
        recorder.audioCoordinator = appModel
        let source = try makeTempRecording(duration: 0.2)
        defer { try? FileManager.default.removeItem(at: source) }
        recorder.loadTestRecording(url: source, duration: 0.2)

        appModel.suspendPerformanceAudio()
        defer { appModel.resumePerformanceAudio() }

        try recorder.playTrimmedPreview()
        try await Task.sleep(for: .milliseconds(350))
        recorder.stopPreview()
    }

    func testRecordingPreviewWithInt16WAVDoesNotCrash() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Int16 preview playback is validated on device; simulator audio session is unreliable here.")
        #else
        guard let appModel = AppModel.current else {
            XCTFail("AppModel is not available in the test host.")
            return
        }

        let recorder = SampleRecorder()
        recorder.audioCoordinator = appModel
        let source = try makeInt16Recording(duration: 0.2)
        defer { try? FileManager.default.removeItem(at: source) }
        recorder.loadTestRecording(url: source, duration: 0.2)

        appModel.suspendPerformanceAudio()
        defer { appModel.resumePerformanceAudio() }

        try recorder.playTrimmedPreview()
        try await Task.sleep(for: .milliseconds(350))
        recorder.stopPreview()
        #endif
    }

    func testMutateGraphWhilePerformanceAudioSuspendedDoesNotCrash() async throws {
        guard let appModel = AppModel.current else {
            XCTFail("AppModel is not available in the test host.")
            return
        }

        appModel.suspendPerformanceAudio()
        defer { appModel.resumePerformanceAudio() }

        let source = try makeTempRecording(duration: 0.1)
        defer { try? FileManager.default.removeItem(at: source) }
        let sample = try await appModel.sampleLibrary.importRecording(
            from: source,
            name: "Suspended Graph",
            rootNote: 60,
            trimStart: 0,
            trimEnd: nil
        )
        let url = await appModel.sampleLibrary.fileURL(for: sample)
        try await appModel.instrumentRouter.selectUserSample(sample, fileURL: url)
        XCTAssertFalse(appModel.audioEngine.engine.isRunning)
    }

    func testSamplesTabPreviewStartsEngine() async throws {
        guard let appModel = AppModel.current else {
            XCTFail("AppModel is not available in the test host.")
            return
        }

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = SampleLibraryStore(rootDirectory: root)
        let source = try makeTempRecording(duration: 0.15)
        defer { try? FileManager.default.removeItem(at: source) }

        let sample = try await store.importRecording(
            from: source,
            name: "Samples Tab Preview",
            rootNote: 60,
            trimStart: 0,
            trimEnd: nil
        )

        appModel.suspendPerformanceAudio()
        appModel.resumePerformanceAudio()
        XCTAssertTrue(appModel.audioEngine.engine.isRunning)

        await appModel.previewUserInstrument(sample)
        try await Task.sleep(for: .milliseconds(300))
        appModel.instrumentRouter.allNotesOff()
    }

    private func makeTempRecording(duration: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44_100,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "SampleRecorderPreviewTests", code: 1)
        }

        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "SampleRecorderPreviewTests", code: 2)
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
        return url
    }

    private func makeInt16Recording(duration: Double) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).wav")
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 44_100,
            channels: 1,
            interleaved: false
        ) else {
            throw NSError(domain: "SampleRecorderPreviewTests", code: 3)
        }

        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw NSError(domain: "SampleRecorderPreviewTests", code: 4)
        }
        buffer.frameLength = frameCount
        if let channelData = buffer.int16ChannelData {
            for frame in 0..<Int(frameCount) {
                let t = Double(frame) / format.sampleRate
                channelData[0][frame] = Int16(sin(t * 440 * 2 * .pi) * 8_000)
            }
        }

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }
}
