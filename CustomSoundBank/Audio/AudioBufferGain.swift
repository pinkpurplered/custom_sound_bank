import AVFoundation
import Foundation

enum AudioBufferGain {
    /// Peak-normalize a mono or stereo float buffer to the given linear target.
    static func peakNormalize(_ buffer: AVAudioPCMBuffer, targetPeak: Float = 0.89) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        var peak: Float = 0
        let channelCount = Int(buffer.format.channelCount)
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameCount {
                peak = max(peak, abs(samples[frame]))
            }
        }

        guard peak > 0.000_001 else { return }
        let scale = min(PlaybackGain.maximumBoost, targetPeak / peak)
        guard abs(scale - 1) > 0.001 else { return }

        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameCount {
                samples[frame] *= scale
            }
        }
    }
}
