import AVFoundation
import Combine
import Foundation

@MainActor
protocol AudioSessionCoordinator: AnyObject {
    func suspendPerformanceAudio()
    func resumePerformanceAudio()
}

@MainActor
final class SampleRecorder: NSObject, ObservableObject {
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

    weak var audioCoordinator: AudioSessionCoordinator?

    private var recorder: AVAudioRecorder?
    private var previewPlayer: AVAudioPlayer?
    private var meterTimer: Timer?
    private var playbackStopTimer: Timer?
    private let maxDuration: TimeInterval = 10

    private let recordingSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false
    ]

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

        audioCoordinator?.suspendPerformanceAudio()
        try configureSessionForRecording()

        for tick in stride(from: 3, through: 1, by: -1) {
            state = .countdown(tick)
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        try startRecording()
    }

    func stopRecording() {
        meterTimer?.invalidate()
        meterTimer = nil
        recorder?.stop()
        recorder = nil
        if duration > 0 {
            trimEnd = duration
        }
        state = recordedURL == nil ? .idle : .recorded
    }

    func discardRecording() {
        stopPreview()
        if let recordedURL {
            try? FileManager.default.removeItem(at: recordedURL)
        }
        recordedURL = nil
        duration = 0
        trimStart = 0
        trimEnd = 0
        state = .idle
        audioCoordinator?.resumePerformanceAudio()
    }

    func playTrimmedPreview() throws {
        guard let recordedURL else { return }
        stopPreview()

        let player = try AVAudioPlayer(contentsOf: recordedURL)
        player.delegate = PreviewDelegate { [weak self] in
            Task { @MainActor in
                self?.finishPreview()
            }
        }
        player.prepareToPlay()

        let start = min(max(trimStart, 0), duration)
        let end = min(max(trimEnd, start + 0.05), max(duration, 0.1))
        player.currentTime = start
        previewPlayer = player
        state = .playingBack
        player.play()

        let previewLength = end - start
        playbackStopTimer = Timer.scheduledTimer(withTimeInterval: previewLength, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.finishPreview()
            }
        }
    }

    func stopPreview() {
        playbackStopTimer?.invalidate()
        playbackStopTimer = nil
        previewPlayer?.stop()
        previewPlayer = nil
        if state == .playingBack {
            state = recordedURL == nil ? .idle : .recorded
        }
    }

    private func finishPreview() {
        stopPreview()
        audioCoordinator?.resumePerformanceAudio()
    }

    private func configureSessionForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setPreferredSampleRate(44_100)
        try session.setActive(true)

        if let builtInMic = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try session.setPreferredInput(builtInMic)
        }
    }

    private func startRecording() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let recorder = try AVAudioRecorder(url: tempURL, settings: recordingSettings)
        recorder.isMeteringEnabled = true
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw NSError(domain: "SampleRecorder", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Could not start recording."
            ])
        }

        self.recorder = recorder
        recordedURL = tempURL
        duration = 0
        trimStart = 0
        trimEnd = 0
        state = .recording

        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMeters()
            }
        }
    }

    private func updateMeters() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        level = max(0, min(1, (power + 50) / 50))
        duration = recorder.currentTime
        trimEnd = duration
        if duration >= maxDuration {
            stopRecording()
        }
    }
}

private final class PreviewDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
