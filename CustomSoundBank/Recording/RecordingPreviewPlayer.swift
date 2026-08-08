import AVFoundation
import Foundation

/// Plays temporary recordings with `AVAudioPlayer` so preview never touches the
/// performance `AVAudioEngine` graph.
final class RecordingPreviewPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var finishWorkItem: DispatchWorkItem?
    private var onFinish: (() -> Void)?

    func play(
        url: URL,
        startTime: TimeInterval,
        endTime: TimeInterval,
        onFinish: @escaping () -> Void
    ) throws {
        stop()

        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
        try session.setPreferredSampleRate(AudioSessionConfiguration.preferredSampleRate(for: session))
        try session.setActive(true)

        let player = try AVAudioPlayer(contentsOf: url)
        guard player.duration > 0 else {
            throw NSError(domain: "RecordingPreviewPlayer", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Recording is empty."
            ])
        }
        player.delegate = self
        player.prepareToPlay()

        let start = min(max(startTime, 0), player.duration)
        let end = min(max(endTime, start + 0.05), player.duration)
        player.currentTime = start

        self.player = player
        self.onFinish = onFinish
        player.play()

        let previewLength = end - start
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.handlePlaybackFinished()
            }
        }
        finishWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + previewLength, execute: workItem)
    }

    func stop() {
        finishWorkItem?.cancel()
        finishWorkItem = nil
        player?.stop()
        player = nil
        onFinish = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            handlePlaybackFinished()
        }
    }

    private func handlePlaybackFinished() {
        guard onFinish != nil else { return }
        let finish = onFinish
        onFinish = nil
        finishWorkItem?.cancel()
        finishWorkItem = nil
        player?.stop()
        player = nil
        finish?()
    }
}
