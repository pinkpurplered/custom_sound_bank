import Foundation
import CoreMIDI
import Combine

private final class MIDIPortReadContext: @unchecked Sendable {
    var performanceHandler: ((MIDINoteEvent) -> Void)?
    var uiHandler: ((MIDINoteEvent) -> Void)?

    func deliver(_ events: [MIDINoteEvent]) {
        for event in events {
            performanceHandler?(event)
            uiHandler?(event)
        }
    }
}

@MainActor
final class MIDIService: ObservableObject {
    @Published private(set) var sources: [MIDISourceSnapshot] = []
    @Published private(set) var connectedSourceName: String?
    @Published private(set) var lastError: String?
    @Published private(set) var receivedEventCount = 0
    @Published private(set) var lastReceivedEventDescription: String?

    func setEventHandlers(
        performance: @escaping (MIDINoteEvent) -> Void,
        ui: @escaping (MIDINoteEvent) -> Void
    ) {
        readContext.performanceHandler = performance
        readContext.uiHandler = ui
    }

    func recordReceivedEvent(_ event: MIDINoteEvent) {
        receivedEventCount += 1
        lastReceivedEventDescription = Self.describe(event)
    }

    var onEvent: ((MIDINoteEvent) -> Void)? {
        get { nil }
        set {
            if let newValue {
                setEventHandlers(performance: newValue, ui: newValue)
            } else {
                readContext.performanceHandler = nil
                readContext.uiHandler = nil
            }
        }
    }

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var connectedSource: MIDIEndpointRef?
    private let readContext = MIDIPortReadContext()

    init() {
        setupClient()
        refreshSources()
    }

    deinit {
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
        }
        if client != 0 {
            MIDIClientDispose(client)
        }
    }

    func refreshSources() {
        sources = (0..<MIDIGetNumberOfSources()).compactMap { index in
            let endpoint = MIDIGetSource(index)
            guard endpoint != 0 else { return nil }
            let name = Self.endpointName(endpoint) ?? "MIDI Source \(index + 1)"
            return MIDISourceSnapshot(
                id: "\(endpoint)",
                name: name,
                isConnected: endpoint == connectedSource
            )
        }
    }

    func connectFirstAvailableSource() {
        guard let preferred = Self.preferredSource(from: sources) ?? sources.first else {
            connectedSourceName = nil
            return
        }
        connect(toEndpointID: preferred.id)
    }

    func connect(toEndpointID id: String) {
        guard let endpoint = UInt32(id), endpoint != 0 else { return }
        disconnect()

        let status = MIDIPortConnectSource(inputPort, MIDIEndpointRef(endpoint), nil)
        if status == noErr {
            connectedSource = MIDIEndpointRef(endpoint)
            connectedSourceName = Self.endpointName(MIDIEndpointRef(endpoint))
            lastError = nil
        } else {
            lastError = "Failed to connect MIDI source (\(status))"
        }
        refreshSources()
    }

    func disconnect() {
        if let connectedSource, connectedSource != 0 {
            MIDIPortDisconnectSource(inputPort, connectedSource)
        }
        connectedSource = nil
        connectedSourceName = nil
        refreshSources()
    }

    private func setupClient() {
        let clientStatus = MIDIClientCreateWithBlock("CustomSoundBankClient" as CFString, &client) { [weak self] notification in
            guard let self else { return }
            Task { @MainActor in
                self.handle(notification: notification)
            }
        }
        if clientStatus != noErr {
            lastError = "Failed to create MIDI client (\(clientStatus))"
            return
        }

        let readContext = self.readContext
        let portStatus = MIDIInputPortCreateWithProtocol(
            client,
            "CustomSoundBankInput" as CFString,
            ._1_0,
            &inputPort
        ) { eventList, _ in
            let events = MIDIEventDecoder.decode(eventList: eventList)
            readContext.deliver(events)
        }

        if portStatus != noErr {
            let refCon = Unmanaged.passUnretained(readContext).toOpaque()
            let legacyStatus = MIDIInputPortCreate(
                client,
                "CustomSoundBankInput" as CFString,
                Self.legacyMidiReadProc,
                refCon,
                &inputPort
            )
            if legacyStatus != noErr {
                lastError = "Failed to create MIDI input port (\(legacyStatus))"
            }
        }
    }

    private static let legacyMidiReadProc: MIDIReadProc = { packetList, _, refCon in
        guard let refCon else { return }
        let context = Unmanaged<MIDIPortReadContext>.fromOpaque(refCon).takeUnretainedValue()
        let events = MIDIEventDecoder.decode(packetList: packetList)
        context.deliver(events)
    }


    private static func describe(_ event: MIDINoteEvent) -> String {
        switch event.kind {
        case .noteOn(let note, let velocity):
            return "Ch \(event.channel) Note On \(MIDIUtilities.noteName(for: note)) (\(velocity))"
        case .noteOff(let note, _):
            return "Ch \(event.channel) Note Off \(MIDIUtilities.noteName(for: note))"
        case .sustain(let isDown):
            return "Ch \(event.channel) Sustain \(isDown ? "On" : "Off")"
        case .modulation(let value):
            return "Ch \(event.channel) Modulation \(value)"
        case .pitchBend(let value):
            return "Ch \(event.channel) Pitch Bend \(value)"
        case .allNotesOff:
            return "Ch \(event.channel) All Notes Off"
        }
    }

    private func handle(notification: UnsafePointer<MIDINotification>) {
        switch notification.pointee.messageID {
        case .msgSetupChanged, .msgObjectAdded, .msgObjectRemoved:
            refreshSources()
            if let preferred = Self.preferredSource(from: sources) {
                let preferredEndpoint = MIDIEndpointRef(UInt32(preferred.id) ?? 0)
                if connectedSource == nil || connectedSource != preferredEndpoint {
                    connect(toEndpointID: preferred.id)
                }
            } else if connectedSource == nil {
                connectFirstAvailableSource()
            }
        default:
            break
        }
    }

    private static func preferredSource(from sources: [MIDISourceSnapshot]) -> MIDISourceSnapshot? {
        let ranked = sources.sorted { lhs, rhs in
            score(for: lhs.name) > score(for: rhs.name)
        }
        return ranked.first
    }

    private static func score(for sourceName: String) -> Int {
        let name = sourceName.lowercased()
        var score = 0
        if name.contains("irig") { score += 100 }
        if name.contains("midi") { score += 50 }
        if name.contains("keyboard") || name.contains("piano") { score += 25 }
        if name.contains("network") || name.contains("session") { score -= 100 }
        return score
    }

    private static func endpointName(_ endpoint: MIDIEndpointRef) -> String? {
        var param: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &param)
        guard status == noErr, let value = param?.takeRetainedValue() else { return nil }
        return value as String
    }
}
