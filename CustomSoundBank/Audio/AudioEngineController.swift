import AVFoundation
import Foundation

@MainActor
final class AudioEngineController: ObservableObject {
    @Published private(set) var routeSnapshot = AudioRouteSnapshot(
        outputName: "Unknown",
        inputName: "Unknown",
        sampleRate: 44_100,
        isExternalOutput: false
    )

    let engine = AVAudioEngine()
    let mainMixer = AVAudioMixerNode()

    private var interruptionObserver: NSObjectProtocol?
    private var routeObserver: NSObjectProtocol?
    private weak var connectedInstrumentRoot: AVAudioNode?

    init() {
        engine.attach(mainMixer)
        engine.connect(mainMixer, to: engine.outputNode, format: nil)
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try session.setPreferredSampleRate(44_100)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)

        guard !engine.isRunning else {
            refreshRouteSnapshot()
            return
        }
        engine.prepare()
        try engine.start()
        refreshRouteSnapshot()
    }

    func stop() {
        engine.stop()
    }

    func setMasterVolume(_ volume: Float) {
        mainMixer.outputVolume = max(0, min(1, volume))
    }

    func attach(node: AVAudioNode) {
        if !engine.attachedNodes.contains(node) {
            engine.attach(node)
            engine.connect(node, to: mainMixer, format: nil)
        }
    }

    func detach(node: AVAudioNode) {
        if engine.attachedNodes.contains(node) {
            engine.disconnectNodeOutput(node)
            engine.detach(node)
        }
    }

    func mutateGraph(_ mutation: () throws -> Void) throws {
        let wasRunning = engine.isRunning
        if wasRunning { engine.stop() }
        try mutation()
        engine.prepare()
        if wasRunning { try engine.start() }
    }

    func connectInstrument(_ node: AVAudioNode) throws {
        try mutateGraph {
            if let connectedInstrumentRoot,
               connectedInstrumentRoot !== node,
               engine.attachedNodes.contains(connectedInstrumentRoot) {
                engine.disconnectNodeOutput(connectedInstrumentRoot)
            }

            if !engine.attachedNodes.contains(node) {
                engine.attach(node)
            }

            let outputs = engine.outputConnectionPoints(for: node, outputBus: 0)
            if !outputs.contains(where: { $0.node === mainMixer }) {
                engine.connect(node, to: mainMixer, format: nil)
            }

            connectedInstrumentRoot = node
        }
    }

    func installObservers(onInterruption: @escaping () -> Void, onRouteChange: @escaping () -> Void) {
        let center = NotificationCenter.default
        interruptionObserver = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard
                let info = notification.userInfo,
                let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: typeValue),
                type == .ended
            else { return }
            onInterruption()
        }

        routeObserver = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { _ in onRouteChange() }
    }

    func refreshRouteSnapshot() {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs.map(\.portName).joined(separator: ", ")
        let inputs = session.currentRoute.inputs.map(\.portName).joined(separator: ", ")
        let external = session.currentRoute.outputs.contains {
            $0.portType == .usbAudio || $0.portType == .headphones || $0.portType == .bluetoothA2DP
        }
        routeSnapshot = AudioRouteSnapshot(
            outputName: outputs.isEmpty ? "None" : outputs,
            inputName: inputs.isEmpty ? "Built-in Mic" : inputs,
            sampleRate: session.sampleRate,
            isExternalOutput: external
        )
    }
}
