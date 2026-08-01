import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var settings = AppSettings.default
    @Published private(set) var startupError: String?

    let audioEngine = AudioEngineController()
    let midiService = MIDIService()
    let instrumentRouter = InstrumentRouter()
    let sampleLibrary = SampleLibraryStore()

    init() {
        midiService.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.handleMIDI(event)
            }
        }

        audioEngine.installObservers(
            onInterruption: { [weak self] in
                Task { @MainActor in
                    self?.recoverAudio()
                }
            },
            onRouteChange: { [weak self] in
                Task { @MainActor in
                    self?.audioEngine.refreshRouteSnapshot()
                }
            }
        )

        Task {
            await bootstrap()
        }
    }

    func bootstrap() async {
        instrumentRouter.configure(audioEngine: audioEngine)
        do {
            try audioEngine.start()
            audioEngine.setMasterVolume(settings.masterVolume)
            instrumentRouter.selectBundled(.piano)
            midiService.connectFirstAvailableSource()
            audioEngine.refreshRouteSnapshot()
        } catch {
            startupError = error.localizedDescription
        }
    }

    func recoverAudio() {
        do {
            try audioEngine.start()
            instrumentRouter.allNotesOff()
        } catch {
            startupError = error.localizedDescription
        }
    }

    func updateMasterVolume(_ volume: Float) {
        settings.masterVolume = volume
        audioEngine.setMasterVolume(volume)
    }

    func updateMIDIChannel(_ channel: UInt8) {
        settings.midiChannel = channel
    }

    func selectBundledInstrument(_ kind: InstrumentKind) {
        settings.selectedInstrument = .bundled(kind)
        instrumentRouter.selectBundled(kind)
    }

    func selectUserInstrument(_ sample: UserSampleInstrument) async {
        settings.selectedInstrument = .user(sample.id)
        let url = await sampleLibrary.fileURL(for: sample)
        instrumentRouter.selectUserSample(sample, fileURL: url)
    }

    func saveSample(
        from recorder: SampleRecorder,
        name: String,
        rootNote: UInt8
    ) async throws -> UserSampleInstrument {
        guard let sourceURL = recorder.recordedURL else {
            throw NSError(domain: "AppModel", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No recording available."
            ])
        }
        let sample = try await sampleLibrary.importRecording(
            from: sourceURL,
            name: name,
            rootNote: rootNote,
            trimStart: recorder.trimStart,
            trimEnd: recorder.trimEnd > recorder.trimStart ? recorder.trimEnd : nil
        )
        await selectUserInstrument(sample)
        return sample
    }

    private func handleMIDI(_ event: MIDINoteEvent) {
        instrumentRouter.handleMIDI(event, channelFilter: settings.midiChannel)
    }
}
