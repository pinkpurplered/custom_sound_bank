import AVFoundation
import Combine
import Foundation

@MainActor
final class SampleRecorder: ObservableObject {
    enum State: Equatable {
        case idle
        case countdown(Int)
        case recording
        case recorded
        case playingBack
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var level: Float = 0
    @Published private(set) var recordedURL: URL?
    @Published private(set) var duration: TimeInterval = 0
    @Published var trimStart: TimeInterval = 0
    @Published var trimEnd: TimeInterval = 0
    @Published private(set) var lastError: String?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var audioFile: AVAudioFile?
    private var meterTimer: Timer?
    private var recordingStart: Date?
    private let maxDuration: TimeInterval = 10

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    func startCountdown() async throws {
        guard await requestPermission() else {
            lastError = "Microphone permission denied."
            throw NSError(domain: "SampleRecorder", code: 1)
        }

        try configureSession()
        for tick in stride(from: 3, through: 1, by: -1) {
            state = .countdown(tick)
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        try startRecording()
    }

    func stopRecording() {
        engine.inputNode.removeTap(onBus: 0)
        meterTimer?.invalidate()
        meterTimer = nil
        if let recordingStart {
            duration = Date().timeIntervalSince(recordingStart)
            trimEnd = duration
        }
        engine.stop()
        state = recordedURL == nil ? .idle : .recorded
    }

    func discardRecording() {
        if let recordedURL {
            try? FileManager.default.removeItem(at: recordedURL)
        }
        recordedURL = nil
        audioFile = nil
        duration = 0
        trimStart = 0
        trimEnd = 0
        state = .idle
    }

    func playTrimmedPreview() throws {
        guard let recordedURL else { return }
        let file = try AVAudioFile(forReading: recordedURL)
        let format = file.processingFormat
        let startFrame = AVAudioFramePosition(trimStart * format.sampleRate)
        let endFrame = AVAudioFramePosition(trimEnd * format.sampleRate)
        let frameCount = max(1, endFrame - startFrame)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return
        }
        file.framePosition = startFrame
        try file.read(into: buffer, frameCount: AVAudioFrameCount(frameCount))

        if !engine.isRunning {
            try engine.start()
        }
        state = .playingBack
        player.stop()
        player.scheduleBuffer(buffer, at: nil) { [weak self] in
            Task { @MainActor in
                self?.state = .recorded
            }
        }
        player.play()
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setActive(true)
        if let builtInMic = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try session.setPreferredInput(builtInMic)
        }
    }

    private func startRecording() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        audioFile = try AVAudioFile(forWriting: tempURL, settings: format.settings)
        recordedURL = tempURL
        recordingStart = Date()
        duration = 0
        trimStart = 0
        trimEnd = 0

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            try? self.audioFile?.write(from: buffer)
            if let channel = buffer.floatChannelData?.pointee {
                let frameLength = Int(buffer.frameLength)
                var peak: Float = 0
                for index in 0..<frameLength {
                    peak = max(peak, abs(channel[index]))
                }
                Task { @MainActor in
                    self.level = peak
                    if let recordingStart = self.recordingStart {
                        self.duration = Date().timeIntervalSince(recordingStart)
                        self.trimEnd = self.duration
                        if self.duration >= self.maxDuration {
                            self.stopRecording()
                        }
                    }
                }
            }
        }

        engine.prepare()
        try engine.start()
        state = .recording
    }
}
