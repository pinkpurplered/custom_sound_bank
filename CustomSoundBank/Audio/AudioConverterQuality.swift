import AVFoundation
import Foundation

enum AudioConverterQuality {
    static func configure(_ converter: AVAudioConverter) {
        converter.sampleRateConverterQuality = .max
    }
}
