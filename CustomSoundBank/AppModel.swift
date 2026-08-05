import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject, AudioSessionCoordinator {
    @Published var settings = AppSettings.default {
        didSet {
            if !isApplyingLiveSet {
                liveSetIsDirty = true
            }
            persistTranspose()
        }
    }
    @Published private(set) var liveSets: [LiveSet] = []
    @Published private(set) var activeLiveSetID: UUID?
    @Published private(set) var liveSetIsDirty = false
    @Published private(set) var startupError: String?

    private var performanceAudioSuspended = false
    private var cancellables = Set<AnyCancellable>()
    private var isApplyingLiveSet = false
    private var suppressLiveSetDirty = false

    private static let favoritesKey = "favoriteBundledPadIDs"
    private static let favoriteUserSamplesKey = "favoriteUserSampleIDs"
    private static let bundledVolumesKey = "bundledPadVolumes"
    private static let userVolumesKey = "userSampleVolumes"
    private static let layeredLayerVolumesKey = "layeredPadLayerVolumes"
    private static let transposeKey = "transposeSemitones"
    private static let liveSetsKey = "liveSets"
    private static let activeLiveSetKey = "activeLiveSetID"

    /// Maps pre-catalog InstrumentKind ids saved in UserDefaults to current BundledPad ids.
    private static let legacyFavoritePadIDs: [String: String] = [
        "piano": "piano_grand",
        "strings": "strings_ensemble",
        "organ": "organ_church",
        "musicBox": "musicbox_classic",
        "synthLead": "synth_lead_saw",
        "synthPad": "synth_pad_warm",
    ]

    let audioEngine = AudioEngineController()
    let midiService = MIDIService()
    let instrumentRouter = InstrumentRouter()
    let sampleLibrary = SampleLibraryStore()

    var activeLiveSet: LiveSet? {
        guard let activeLiveSetID else { return nil }
        return liveSets.first { $0.id == activeLiveSetID }
    }

    init() {
        loadLiveSets()
        instrumentRouter.setTransposeSemitones(settings.transposeSemitones)

        instrumentRouter.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        midiService.setEventHandlers(
            performance: { [weak self] event in
                self?.instrumentRouter.performanceCore.handleMIDI(event)
            },
            ui: { [weak self] event in
                guard let self else { return }
                Task { @MainActor in
                    self.instrumentRouter.handleMIDIUI(event, channelFilter: self.settings.midiChannel)
                    self.midiService.recordReceivedEvent(event)
                }
            }
        )

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
        instrumentRouter.setMIDIChannelFilter(settings.midiChannel)
        do {
            try audioEngine.start()
            audioEngine.setMasterVolume(settings.masterVolume)
            await applyActiveLiveSetSelection()
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
            try audioEngine.configurePerformanceSession()
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
        instrumentRouter.setMIDIChannelFilter(channel)
    }

    func setModulation(_ value: Float) {
        instrumentRouter.setModulation(value)
    }

    func setPitchBend(_ value: Float) {
        instrumentRouter.setPitchBend(value)
    }

    func updateTransposeSemitones(_ semitones: Int) {
        let clamped = max(-12, min(12, semitones))
        settings.transposeSemitones = clamped
        instrumentRouter.setTransposeSemitones(clamped)
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

    func layerVolume(forLayerPadID layerPadID: String, in layeredPad: BundledPad) -> Float {
        if let stored = settings.layeredPadLayerVolumes[layeredPad.id]?[layerPadID] {
            return stored
        }
        return layeredPad.layers?.first { $0.padID == layerPadID }?.volume ?? 1.0
    }

    func setLayerVolume(_ volume: Float, forLayerPadID layerPadID: String, in layeredPad: BundledPad) {
        let clamped = max(0, min(1, volume))
        var layers = settings.layeredPadLayerVolumes[layeredPad.id] ?? [:]
        layers[layerPadID] = clamped
        settings.layeredPadLayerVolumes[layeredPad.id] = layers
        if isPadSelected(layeredPad) {
            instrumentRouter.setLayerVolume(layerPadID: layerPadID, volume: clamped)
        }
    }

    func layerVolumeOverrides(for layeredPad: BundledPad) -> [String: Float] {
        guard let specs = layeredPad.layers else { return [:] }
        return Dictionary(uniqueKeysWithValues: specs.map { spec in
            (spec.padID, layerVolume(forLayerPadID: spec.padID, in: layeredPad))
        })
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
        instrumentRouter.selectBundled(pad, layerVolumeOverrides: layerVolumeOverrides(for: pad))
        instrumentRouter.setInstrumentVolume(padVolume(for: pad))
        markLiveSetDirty()
    }

    func selectUserInstrument(_ sample: UserSampleInstrument) async {
        let url = await sampleLibrary.fileURL(for: sample)
        do {
            try await instrumentRouter.selectUserSample(sample, fileURL: url)
            instrumentRouter.setInstrumentVolume(sampleVolume(for: sample))
            markLiveSetDirty()
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

    // MARK: - Live Sets

    func suggestedLiveSetName() -> String {
        let prefix = "Live Set"
        let existingNumbers = liveSets.compactMap { set -> Int? in
            guard set.name.hasPrefix(prefix) else { return nil }
            let suffix = set.name.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
            return Int(suffix)
        }
        let nextNumber = (existingNumbers.max() ?? 0) + 1
        return "\(prefix) \(nextNumber)"
    }

    func saveActiveLiveSet() {
        guard let activeLiveSetID,
              let index = liveSets.firstIndex(where: { $0.id == activeLiveSetID }) else { return }
        let selection = currentSelectionSnapshot()
        liveSets[index] = LiveSet.from(
            name: liveSets[index].name,
            settings: settings,
            selectedBundledPadID: selection.bundledPadID,
            selectedUserSampleID: selection.userSampleID
        )
        liveSets[index].id = activeLiveSetID
        persistLiveSets()
        liveSetIsDirty = false
    }

    func createLiveSet(named name: String) {
        if liveSetIsDirty {
            saveActiveLiveSet()
        }
        let set = LiveSet(name: name)
        liveSets.append(set)
        activeLiveSetID = set.id
        applyLiveSet(set)
        persistLiveSets()
    }

    func selectLiveSet(id: UUID) {
        guard id != activeLiveSetID,
              let set = liveSets.first(where: { $0.id == id }) else { return }
        if liveSetIsDirty {
            saveActiveLiveSet()
        }
        activeLiveSetID = id
        applyLiveSet(set)
        persistLiveSets()
        Task {
            await applyActiveLiveSetSelection()
        }
    }

    func addBundledPadToActiveLiveSet(_ pad: BundledPad) {
        if !settings.favoriteBundledPadIDs.contains(pad.id) {
            settings.favoriteBundledPadIDs.append(pad.id)
        }
        selectBundledPad(pad)
    }

    func addUserSampleToActiveLiveSet(_ sample: UserSampleInstrument) async {
        if !settings.favoriteUserSampleIDs.contains(sample.id) {
            settings.favoriteUserSampleIDs.append(sample.id)
        }
        await selectUserInstrument(sample)
    }

    private func applyLiveSet(_ set: LiveSet) {
        isApplyingLiveSet = true
        set.apply(to: &settings)
        isApplyingLiveSet = false
        liveSetIsDirty = false
    }

    func applyActiveLiveSetSelection() async {
        suppressLiveSetDirty = true
        defer { suppressLiveSetDirty = false }

        guard let set = activeLiveSet else {
            selectBundledPad(BundledPad.defaultPad)
            return
        }

        if let padID = set.selectedBundledPadID, let pad = BundledPad.pad(withID: padID) {
            selectBundledPad(pad)
            return
        }

        if let sampleID = set.selectedUserSampleID,
           let sample = await sampleLibrary.sample(id: sampleID) {
            await selectUserInstrument(sample)
            return
        }

        if let firstPad = favoriteBundledPads().first {
            selectBundledPad(firstPad)
            return
        }

        if let firstSampleID = settings.favoriteUserSampleIDs.first,
           let sample = await sampleLibrary.sample(id: firstSampleID) {
            await selectUserInstrument(sample)
        }
    }

    private func markLiveSetDirty() {
        if !isApplyingLiveSet, !suppressLiveSetDirty {
            liveSetIsDirty = true
        }
    }

    private func currentSelectionSnapshot() -> (bundledPadID: String?, userSampleID: UUID?) {
        switch instrumentRouter.selectedInstrument {
        case .bundled(let pad):
            return (pad.id, nil)
        case .user(let sample):
            return (nil, sample.id)
        }
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

    private func loadLiveSets() {
        let defaults = UserDefaults.standard

        if let data = defaults.data(forKey: Self.liveSetsKey),
           let decoded = try? JSONDecoder().decode([LiveSet].self, from: data),
           !decoded.isEmpty {
            liveSets = decoded
        } else {
            loadLegacyPerformanceSettings()
            let migrated = LiveSet.from(
                name: "My Live Set",
                settings: settings,
                selectedBundledPadID: BundledPad.defaultPad.id,
                selectedUserSampleID: nil
            )
            liveSets = [migrated]
            persistLiveSets()
        }

        if let activeIDString = defaults.string(forKey: Self.activeLiveSetKey),
           let activeID = UUID(uuidString: activeIDString),
           liveSets.contains(where: { $0.id == activeID }) {
            activeLiveSetID = activeID
        } else {
            activeLiveSetID = liveSets.first?.id
        }

        if let set = activeLiveSet {
            applyLiveSet(set)
        }

        if defaults.object(forKey: Self.transposeKey) != nil {
            settings.transposeSemitones = max(-12, min(12, defaults.integer(forKey: Self.transposeKey)))
        }
    }

    private func loadLegacyPerformanceSettings() {
        let defaults = UserDefaults.standard
        if let bundledIDs = defaults.stringArray(forKey: Self.favoritesKey) {
            settings.favoriteBundledPadIDs = Self.normalizeFavoritePadIDs(bundledIDs)
        }
        if settings.favoriteBundledPadIDs.isEmpty {
            settings.favoriteBundledPadIDs = BundledPad.defaultFavoritePadIDs
        }
        if let userIDStrings = defaults.stringArray(forKey: Self.favoriteUserSamplesKey) {
            settings.favoriteUserSampleIDs = userIDStrings.compactMap(UUID.init(uuidString:))
        }
        if let volumes = defaults.dictionary(forKey: Self.bundledVolumesKey) as? [String: Float] {
            settings.bundledPadVolumes = volumes
        }
        if let layeredVolumes = defaults.dictionary(forKey: Self.layeredLayerVolumesKey) as? [String: [String: Double]] {
            settings.layeredPadLayerVolumes = layeredVolumes.mapValues { layerDict in
                layerDict.mapValues { Float($0) }
            }
        }
        if let volumeStrings = defaults.dictionary(forKey: Self.userVolumesKey) as? [String: Double] {
            for (key, value) in volumeStrings {
                if let id = UUID(uuidString: key) {
                    settings.userSampleVolumes[id] = Float(value)
                }
            }
        }
    }

    private func persistLiveSets() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(liveSets) {
            defaults.set(data, forKey: Self.liveSetsKey)
        }
        defaults.set(activeLiveSetID?.uuidString, forKey: Self.activeLiveSetKey)
    }

    private func persistTranspose() {
        UserDefaults.standard.set(settings.transposeSemitones, forKey: Self.transposeKey)
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

    private static func normalizeFavoritePadIDs(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        return ids.compactMap { id in
            let migrated = legacyFavoritePadIDs[id] ?? id
            guard BundledPad.pad(withID: migrated) != nil, !seen.contains(migrated) else { return nil }
            seen.insert(migrated)
            return migrated
        }
    }
}