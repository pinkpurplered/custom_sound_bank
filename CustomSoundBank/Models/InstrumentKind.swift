import Foundation

struct UserSampleInstrument: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var fileName: String
    var rootNote: UInt8
    var createdAt: Date
    var trimStartSeconds: Double
    var trimEndSeconds: Double?

    init(
        id: UUID = UUID(),
        name: String,
        fileName: String,
        rootNote: UInt8,
        createdAt: Date = .now,
        trimStartSeconds: Double = 0,
        trimEndSeconds: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.rootNote = rootNote
        self.createdAt = createdAt
        self.trimStartSeconds = trimStartSeconds
        self.trimEndSeconds = trimEndSeconds
    }
}

enum SelectedInstrument: Equatable, Sendable {
    case bundled(BundledPad)
    case user(UserSampleInstrument)

    var displayName: String {
        switch self {
        case .bundled(let pad):
            return pad.displayName
        case .user(let sample):
            return sample.name
        }
    }
}

struct MIDINoteEvent: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case noteOn(note: UInt8, velocity: UInt8)
        case noteOff(note: UInt8, velocity: UInt8)
        case sustain(isDown: Bool)
        case modulation(value: UInt8)
        case pitchBend(value: UInt16)
        case allNotesOff
    }

    let channel: UInt8
    let kind: Kind
}

struct AudioRouteSnapshot: Equatable, Sendable {
    var outputName: String
    var inputName: String
    var sampleRate: Double
    var isExternalOutput: Bool
}

struct MIDISourceSnapshot: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let isConnected: Bool
}
