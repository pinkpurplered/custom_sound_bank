import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    var masterVolume: Float
    var midiChannel: UInt8
    var polyphonyLimit: Int
    var selectedInstrument: InstrumentSelection

    static let `default` = AppSettings(
        masterVolume: 0.85,
        midiChannel: 1,
        polyphonyLimit: 16,
        selectedInstrument: .bundled(.piano)
    )
}

enum InstrumentSelection: Codable, Equatable, Sendable {
    case bundled(InstrumentKind)
    case user(UUID)

    private enum CodingKeys: String, CodingKey {
        case type, kind, userID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "bundled":
            self = .bundled(try container.decode(InstrumentKind.self, forKey: .kind))
        case "user":
            self = .user(try container.decode(UUID.self, forKey: .userID))
        default:
            self = .bundled(.piano)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .bundled(let kind):
            try container.encode("bundled", forKey: .type)
            try container.encode(kind, forKey: .kind)
        case .user(let id):
            try container.encode("user", forKey: .type)
            try container.encode(id, forKey: .userID)
        }
    }
}
