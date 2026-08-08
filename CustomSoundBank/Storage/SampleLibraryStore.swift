import AVFoundation
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
        case emptyRecording

        var errorDescription: String? {
            switch self {
            case .sampleNotFound: return "Sample not found."
            case .invalidManifest: return "Sample library manifest is invalid."
            case .emptyRecording: return "Recording is too short to save."
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
        try writeTrimmedCAF(from: sourceURL, to: destination, trimStart: trimStart, trimEnd: trimEnd)

        let sample = UserSampleInstrument(
            id: id,
            name: name,
            fileName: fileName,
            rootNote: rootNote,
            trimStartSeconds: 0,
            trimEndSeconds: nil
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

    private func writeTrimmedCAF(
        from sourceURL: URL,
        to destination: URL,
        trimStart: Double,
        trimEnd: Double?
    ) throws {
        let inputFile = try AVAudioFile(forReading: sourceURL)
        let inputFormat = inputFile.processingFormat
        let frameCount = AVAudioFrameCount(inputFile.length)
        guard frameCount > 0 else {
            throw StoreError.emptyRecording
        }

        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frameCount) else {
            throw StoreError.invalidManifest
        }
        try inputFile.read(into: inputBuffer)

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44_100,
            channels: 1,
            interleaved: false
        ) else {
            throw StoreError.invalidManifest
        }

        let floatBuffer = try convertToFloatBuffer(inputBuffer, from: inputFormat, to: outputFormat)
        let totalFrames = Int(floatBuffer.frameLength)
        guard totalFrames > 0 else {
            throw StoreError.emptyRecording
        }

        let sampleRate = outputFormat.sampleRate
        let startFrame = min(max(0, Int(trimStart * sampleRate)), totalFrames - 1)
        let endFrame: Int
        if let trimEnd {
            endFrame = min(max(startFrame + 1, Int(trimEnd * sampleRate)), totalFrames)
        } else {
            endFrame = totalFrames
        }
        let trimmedLength = AVAudioFrameCount(endFrame - startFrame)
        guard trimmedLength > 0 else {
            throw StoreError.emptyRecording
        }

        guard let trimmed = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: trimmedLength) else {
            throw StoreError.invalidManifest
        }
        trimmed.frameLength = trimmedLength

        guard
            let src = floatBuffer.floatChannelData,
            let dst = trimmed.floatChannelData
        else {
            throw StoreError.invalidManifest
        }

        for channel in 0..<Int(outputFormat.channelCount) {
            dst[channel].update(from: src[channel].advanced(by: startFrame), count: Int(trimmedLength))
        }

        AudioBufferGain.peakNormalize(trimmed)

        let outputFile = try AVAudioFile(
            forWriting: destination,
            settings: outputFormat.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try outputFile.write(from: trimmed)
    }

    private func convertToFloatBuffer(
        _ sourceBuffer: AVAudioPCMBuffer,
        from sourceFormat: AVAudioFormat,
        to destinationFormat: AVAudioFormat
    ) throws -> AVAudioPCMBuffer {
        if sourceFormat.commonFormat == destinationFormat.commonFormat,
           sourceFormat.isInterleaved == destinationFormat.isInterleaved,
           sourceFormat.channelCount == destinationFormat.channelCount,
           sourceFormat.sampleRate == destinationFormat.sampleRate {
            return sourceBuffer
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: destinationFormat) else {
            throw StoreError.invalidManifest
        }
        AudioConverterQuality.configure(converter)

        let capacity = AVAudioFrameCount(
            Double(sourceBuffer.frameLength) * destinationFormat.sampleRate / sourceFormat.sampleRate + 1
        )
        guard let destination = AVAudioPCMBuffer(pcmFormat: destinationFormat, frameCapacity: capacity) else {
            throw StoreError.invalidManifest
        }

        var consumedInput = false
        var error: NSError?
        let status = converter.convert(to: destination, error: &error) { _, outStatus in
            if consumedInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumedInput = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if status == .error {
            throw error ?? StoreError.invalidManifest
        }

        return destination
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
