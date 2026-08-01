import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject, AudioSessionCoordinator {
    @Published var settings = AppSettings.default {
        didSet {
            persistFavorites()
            persistVolumes()
        }
    }
    @Published private(set) var startupError: String?

    private var performanceAudioSuspended = false
    private var cancellables = Set<AnyCancellable>()

    private static let favoritesKey = "favoriteBundledPadIDs"
    private static let favoriteUserSamplesKey = "favoriteUserSampleIDs"
    private static let bundledVolumesKey = "bundledPadVolumes"
    private static let userVolumesKey = "userSampleVolumes"

    let audioEngine = AudioEngineController()
    let midiService = MIDIService()
    let instrumentRouter = InstrumentRouter()
    let sampleLibrary = SampleLibraryStore()

    init() {
        loadFavorites()

        instrumentRouter.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

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
            instrumentRouter.selectBundled(BundledPad.defaultPad)
            instrumentRouter.setInstrumentVolume(padVolume(for: BundledPad.defaultPad))
            midiService.connectFirstAvailableSource()
            audioEngine.refreshRouteSnapshot()
        } catch {
            startupError = error.localizedDescription
        }
    }

    func recoverAudio() {
        guard !performanceAudioSuspended else { return }
        do {
            try audioEngine.start()
            instrumentRouter.allNotesOff()
        } catch {
            startupError = error.localizedDescription
        }
    }

    func suspendPerformanceAudio() {
        performanceAudioSuspended = true
        instrumentRouter.allNotesOff()
        audioEngine.stop()
    }

    func resumePerformanceAudio() {
        performanceAudioSuspended = false
        do {
            try audioEngine.start()
            audioEngine.refreshRouteSnapshot()
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

    func setModulation(_ value: Float) {
        instrumentRouter.setModulation(value)
    }

    func setPitchBend(_ value: Float) {
        instrumentRouter.setPitchBend(value)
    }

    func padVolume(for pad: BundledPad) -> Float {
        settings.bundledPadVolumes[pad.id] ?? 1.0
    }

    func setPadVolume(_ volume: Float, for pad: BundledPad) {
        settings.bundledPadVolumes[pad.id] = max(0, min(1, volume))
        if isPadSelected(pad) {
            instrumentRouter.setInstrumentVolume(volume)
        }
    }

    func sampleVolume(for sample: UserSampleInstrument) -> Float {
        settings.userSampleVolumes[sample.id] ?? 1.0
    }

    func setSampleVolume(_ volume: Float, for sample: UserSampleInstrument) {
        settings.userSampleVolumes[sample.id] = max(0, min(1, volume))
        if isUserSampleSelected(sample) {
            instrumentRouter.setInstrumentVolume(volume)
        }
    }

    var selectedInstrumentVolume: Float {
        switch instrumentRouter.selectedInstrument {
        case .bundled(let pad):
            return padVolume(for: pad)
        case .user(let sample):
            return sampleVolume(for: sample)
        }
    }

    func setSelectedInstrumentVolume(_ volume: Float) {
        switch instrumentRouter.selectedInstrument {
        case .bundled(let pad):
            setPadVolume(volume, for: pad)
        case .user(let sample):
            setSampleVolume(volume, for: sample)
        }
    }

    func selectBundledPad(_ pad: BundledPad) {
        instrumentRouter.selectBundled(pad)
        instrumentRouter.setInstrumentVolume(padVolume(for: pad))
    }

    func selectUserInstrument(_ sample: UserSampleInstrument) async {
        let url = await sampleLibrary.fileURL(for: sample)
        do {
            try await instrumentRouter.selectUserSample(sample, fileURL: url)
            instrumentRouter.setInstrumentVolume(sampleVolume(for: sample))
        } catch {
            startupError = error.localizedDescription
        }
    }

    func previewBundledPad(_ pad: BundledPad) {
        selectBundledPad(pad)
        instrumentRouter.playPreviewNote()
    }

    func previewUserInstrument(_ sample: UserSampleInstrument) async {
        await selectUserInstrument(sample)
        try? await Task.sleep(for: .milliseconds(80))
        instrumentRouter.playPreviewNote()
    }

    func isPadSelected(_ pad: BundledPad) -> Bool {
        if case .bundled(let selected) = instrumentRouter.selectedInstrument {
            return selected.id == pad.id
        }
        return false
    }

    func isUserSampleSelected(_ sample: UserSampleInstrument) -> Bool {
        if case .user(let selected) = instrumentRouter.selectedInstrument {
            return selected.id == sample.id
        }
        return false
    }

    // MARK: - Favorites

    func isFavorite(pad: BundledPad) -> Bool {
        settings.favoriteBundledPadIDs.contains(pad.id)
    }

    func isFavorite(sample: UserSampleInstrument) -> Bool {
        settings.favoriteUserSampleIDs.contains(sample.id)
    }

    func toggleFavorite(pad: BundledPad) {
        if let index = settings.favoriteBundledPadIDs.firstIndex(of: pad.id) {
            settings.favoriteBundledPadIDs.remove(at: index)
        } else {
            settings.favoriteBundledPadIDs.append(pad.id)
        }
    }

    func toggleFavorite(sample: UserSampleInstrument) {
        if let index = settings.favoriteUserSampleIDs.firstIndex(of: sample.id) {
            settings.favoriteUserSampleIDs.remove(at: index)
        } else {
            settings.favoriteUserSampleIDs.append(sample.id)
        }
    }

    func favoriteBundledPads() -> [BundledPad] {
        BundledPad.pads(withIDs: settings.favoriteBundledPadIDs)
    }

    func favoriteUserSamples(from allSamples: [UserSampleInstrument]) -> [UserSampleInstrument] {
        let lookup = Dictionary(uniqueKeysWithValues: allSamples.map { ($0.id, $0) })
        return settings.favoriteUserSampleIDs.compactMap { lookup[$0] }
    }

    private func loadFavorites() {
        let defaults = UserDefaults.standard
        if let bundledIDs = defaults.stringArray(forKey: Self.favoritesKey) {
            settings.favoriteBundledPadIDs = bundledIDs
        }
        if let userIDStrings = defaults.stringArray(forKey: Self.favoriteUserSamplesKey) {
            settings.favoriteUserSampleIDs = userIDStrings.compactMap(UUID.init(uuidString:))
        }
        if let volumes = defaults.dictionary(forKey: Self.bundledVolumesKey) as? [String: Float] {
            settings.bundledPadVolumes = volumes
        }
        if let volumeStrings = defaults.dictionary(forKey: Self.userVolumesKey) as? [String: Double] {
            for (key, value) in volumeStrings {
                if let id = UUID(uuidString: key) {
                    settings.userSampleVolumes[id] = Float(value)
                }
            }
        }
    }

    private func persistFavorites() {
        let defaults = UserDefaults.standard
        defaults.set(settings.favoriteBundledPadIDs, forKey: Self.favoritesKey)
        defaults.set(
            settings.favoriteUserSampleIDs.map(\.uuidString),
            forKey: Self.favoriteUserSamplesKey
        )
    }

    private func persistVolumes() {
        let defaults = UserDefaults.standard
        defaults.set(settings.bundledPadVolumes, forKey: Self.bundledVolumesKey)
        let userVolumes = settings.userSampleVolumes.reduce(into: [String: Float]()) { result, pair in
            result[pair.key.uuidString] = pair.value
        }
        defaults.set(userVolumes, forKey: Self.userVolumesKey)
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
        resumePerformanceAudio()
        return sample
    }

    private func handleMIDI(_ event: MIDINoteEvent) {
        instrumentRouter.handleMIDI(event, channelFilter: settings.midiChannel)
    }
}
