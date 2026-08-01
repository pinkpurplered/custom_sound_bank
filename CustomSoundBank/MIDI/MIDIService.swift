import Foundation
import CoreMIDI
import Combine

@MainActor
final class MIDIService: ObservableObject {
    @Published private(set) var sources: [MIDISourceSnapshot] = []
    @Published private(set) var connectedSourceName: String?
    @Published private(set) var lastError: String?

    var onEvent: ((MIDINoteEvent) -> Void)?

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var connectedSource: MIDIEndpointRef?

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
        guard let first = sources.first else {
            connectedSourceName = nil
            return
        }
        connect(toEndpointID: first.id)
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

        let portStatus = MIDIInputPortCreateWithProtocol(
            client,
            "CustomSoundBankInput" as CFString,
            MIDIProtocolID._1_0,
            &inputPort
        ) { [weak self] eventList, _ in
            guard let self else { return }
            let events = MIDIEventDecoder.decode(eventList: eventList)
            for event in events {
                self.onEvent?(event)
            }
        }

        if portStatus != noErr {
            lastError = "Failed to create MIDI input port (\(portStatus))"
        }
    }

    private func handle(notification: UnsafePointer<MIDINotification>) {
        switch notification.pointee.messageID {
        case .msgSetupChanged, .msgObjectAdded, .msgObjectRemoved:
            refreshSources()
            if connectedSource == nil {
                connectFirstAvailableSource()
            }
        default:
            break
        }
    }

    private static func endpointName(_ endpoint: MIDIEndpointRef) -> String? {
        var param: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &param)
        guard status == noErr, let value = param?.takeRetainedValue() else { return nil }
        return value as String
    }
}
