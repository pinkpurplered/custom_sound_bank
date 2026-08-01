import AudioToolbox
import AVFoundation
import Foundation

enum BundledPadSampleRenderer {
    private static let sampleRate: Double = 44_100
    private static let renderDuration: Double = 3.5
    private static let previewNote: UInt8 = 60
    private static let previewVelocity: UInt8 = 110

    static func sampleURL(for pad: BundledPad) throws -> URL {
        let cacheDir = try cacheDirectory()
        let fileURL = cacheDir.appendingPathComponent("\(pad.id).wav")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        try render(pad: pad, to: fileURL)
        return fileURL
    }

    private static func cacheDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("BundledPadCache", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func soundFontURL(for pad: BundledPad) throws -> URL {
        let bankName = pad.soundFontFileName ?? "GeneralUser-GS"
        guard let bankURL = Bundle.main.url(
            forResource: bankName,
            withExtension: "sf2",
            subdirectory: "SoundBanks"
        ) ?? Bundle.main.url(forResource: bankName, withExtension: "sf2") else {
            throw NSError(domain: "BundledPadSampleRenderer", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Missing bundled sound bank \(bankName).sf2."
            ])
        }
        return bankURL
    }

    private static func render(pad: BundledPad, to url: URL) throws {
        let bankURL = try soundFontURL(for: pad)
        let engine = AVAudioEngine()
        let sampler = AVAudioUnitSampler()
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)

        try sampler.loadSoundBankInstrument(
            at: bankURL,
            program: pad.gmProgram,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
        )

        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw NSError(domain: "BundledPadSampleRenderer", code: 2)
        }

        let totalFrames = AVAudioFramePosition(sampleRate * renderDuration)
        let chunkSize = AVAudioFrameCount(4096)
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: chunkSize)
        engine.prepare()
        try engine.start()

        sampler.startNote(previewNote, withVelocity: previewVelocity, onChannel: 0)

        let outputFile = try AVAudioFile(forWriting: url, settings: format.settings)
        guard let chunkBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkSize) else {
            throw NSError(domain: "BundledPadSampleRenderer", code: 3)
        }

        while engine.manualRenderingSampleTime < totalFrames {
            let remaining = totalFrames - engine.manualRenderingSampleTime
            let framesToRender = AVAudioFrameCount(min(Int64(chunkSize), remaining))
            chunkBuffer.frameLength = framesToRender

            switch try engine.renderOffline(framesToRender, to: chunkBuffer) {
            case .success, .insufficientDataFromInputNode:
                try outputFile.write(from: chunkBuffer)
            case .cannotDoInCurrentContext:
                continue
            case .error:
                throw NSError(domain: "BundledPadSampleRenderer", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to render \(pad.displayName)."
                ])
            @unknown default:
                throw NSError(domain: "BundledPadSampleRenderer", code: 5)
            }
        }

        sampler.stopNote(previewNote, onChannel: 0)
        engine.stop()
    }
}
