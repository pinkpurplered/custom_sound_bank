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
    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

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
        try configureSessionForPerformance()
        try startEngineIfNeeded()
        refreshRouteSnapshot()
    }

    func startForRecording() throws {
        try configureSessionForRecording()
        try startEngineIfNeeded()
        refreshRouteSnapshot()
    }

    func stop() {
        engine.stop()
        isRunning = false
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
        if wasRunning {
            engine.stop()
            isRunning = false
        }

        try mutation()

        engine.prepare()
        if wasRunning {
            try engine.start()
            isRunning = true
        }
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
            let connectedToMainMixer = outputs.contains { $0.node === mainMixer }
            if !connectedToMainMixer {
                engine.connect(node, to: mainMixer, format: nil)
            }

            connectedInstrumentRoot = node
        }
    }

    func replaceOutputNode(_ node: AVAudioNode) {
        for attached in engine.attachedNodes where attached !== mainMixer && attached !== engine.outputNode {
            if attached is AVAudioUnitSampler || attached is AVAudioPlayerNode {
                engine.disconnectNodeOutput(attached)
            }
        }
        if !engine.attachedNodes.contains(node) {
            engine.attach(node)
        }
        engine.connect(node, to: mainMixer, format: nil)
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
        ) { _ in
            onRouteChange()
        }
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

    private func configureSessionForPerformance() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try session.setPreferredSampleRate(44_100)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
    }

    private func configureSessionForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try session.setPreferredSampleRate(44_100)
        try session.setActive(true)

        if let builtInMic = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try session.setPreferredInput(builtInMic)
        }
    }

    private func startEngineIfNeeded() throws {
        guard !engine.isRunning else {
            isRunning = true
            return
        }
        engine.prepare()
        try engine.start()
        isRunning = true
        lastError = nil
    }
}
