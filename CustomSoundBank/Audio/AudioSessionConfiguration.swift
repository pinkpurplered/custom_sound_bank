import AVFoundation
import Foundation

/// Performance audio session settings tuned for the active output route.
enum AudioSessionConfiguration {
    /// USB interfaces such as iRig Pro run at 48 kHz; forcing 44.1 kHz causes audible resampling.
    static func preferredSampleRate(for session: AVAudioSession = .sharedInstance()) -> Double {
        usesUSBOutput(session) ? 48_000 : 44_100
    }

    /// Larger buffers on external outputs trade a few milliseconds of latency for stability and quality.
    static func preferredIOBufferDuration(for session: AVAudioSession = .sharedInstance()) -> TimeInterval {
        usesUSBOutput(session) ? 0.010 : 0.005
    }

    static func usesUSBOutput(_ session: AVAudioSession = .sharedInstance()) -> Bool {
        session.currentRoute.outputs.contains { $0.portType == .usbAudio }
    }
}
