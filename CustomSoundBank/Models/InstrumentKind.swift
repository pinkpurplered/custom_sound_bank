import Foundation

enum InstrumentKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case piano
    case strings
    case organ
    case musicBox
    case synthLead
    case synthPad
    case userSample

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .piano: return "Piano"
        case .strings: return "Strings"
        case .organ: return "Organ"
        case .musicBox: return "Music Box"
        case .synthLead: return "Synth Lead"
        case .synthPad: return "Synth Pad"
        case .userSample: return "Custom Sample"
        }
    }

    var gmProgram: UInt8? {
        switch self {
        case .piano: return 0
        case .strings: return 48
        case .organ: return 19
        case .musicBox: return 10
        case .synthLead: return 81
        case .synthPad: return 89
        case .userSample: return nil
        }
    }

    var bundledFileName: String? {
        switch self {
        case .piano: return "piano"
        case .strings: return "strings"
        case .organ: return "organ"
        case .musicBox: return "musicbox"
        case .synthLead: return "synth_lead"
        case .synthPad: return "synth_pad"
        case .userSample: return nil
        }
    }

    var iconName: String {
        switch self {
        case .piano: return "pianokeys"
        case .strings: return "music.quarternote.3"
        case .organ: return "chart.bar.doc.horizontal"
        case .musicBox: return "music.note"
        case .synthLead: return "waveform.path"
        case .synthPad: return "cloud.fill"
        case .userSample: return "mic.fill"
        }
    }

    static var bundledCases: [InstrumentKind] {
        allCases.filter { $0 != .userSample }
    }
}

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
    case bundled(InstrumentKind)
    case user(UserSampleInstrument)

    var displayName: String {
        switch self {
        case .bundled(let kind):
            return kind.displayName
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
