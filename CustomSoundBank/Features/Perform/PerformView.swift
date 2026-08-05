import SwiftUI

struct PerformView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var userSamples: [UserSampleInstrument] = []
    @State private var showSettings = false
    @State private var isLiveMode = false
    @State private var showAddSound = false

    private let gridSpacing: CGFloat = 3
    private let horizontalPadding: CGFloat = 6

    var body: some View {
        NavigationStack {
            VStack(spacing: 6) {
                liveModeButton
                LiveSetToolbar { showAddSound = true }
                compactStatusBar
                performancePanel
                favoritePadsGrid
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 4)
            .background(AppTheme.screenBackground)
            .navigationTitle("Live")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet().environmentObject(appModel)
            }
            .sheet(isPresented: $showAddSound) {
                AddSoundSheet().environmentObject(appModel)
            }
            .fullScreenCover(isPresented: $isLiveMode) {
                LiveModeView()
                    .environmentObject(appModel)
            }
            .onChange(of: isLiveMode) { _, isLive in
                if isLive {
                    IdleTimerController.preventSleep()
                } else {
                    IdleTimerController.allowSleep()
                }
            }
        }
        .task { userSamples = await appModel.sampleLibrary.allSamples() }
    }

    private var liveModeButton: some View {
        Button { isLiveMode = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.title2.weight(.semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Live Mode")
                        .font(.headline)
                    Text("Fullscreen · Landscape · Pitch & Mod wheels")
                        .font(.caption)
                        .opacity(0.9)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.title2)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var compactStatusBar: some View {
        HStack(spacing: 6) {
            Image(systemName: midiConnected ? "cable.connector" : "cable.connector.slash")
                .foregroundStyle(midiConnected ? .green : .secondary)
                .font(.caption2)

            Text(midiConnected ? (appModel.midiService.connectedSourceName ?? "MIDI") : "No MIDI")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(appModel.instrumentRouter.selectedInstrument.displayName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var performancePanel: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                SynthWheelControl(
                    title: "Mod",
                    value: Binding(
                        get: { appModel.instrumentRouter.modulation },
                        set: { appModel.setModulation($0) }
                    )
                )
                .frame(maxWidth: .infinity)

                SynthWheelControl(
                    title: "Pitch",
                    value: Binding(
                        get: { (appModel.instrumentRouter.pitchBend + 1) / 2 },
                        set: { appModel.setPitchBend($0 * 2 - 1) }
                    ),
                    centerSnap: true
                )
                .frame(maxWidth: .infinity)
            }
            .frame(height: 132)

            Group {
                if case .bundled(let pad) = appModel.instrumentRouter.selectedInstrument, pad.isLayered {
                    LayerVolumeControls(layeredPad: pad)
                } else {
                    HStack(spacing: 6) {
                        Text("Voice")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .leading)

                        Slider(
                            value: Binding(
                                get: { appModel.selectedInstrumentVolume },
                                set: { appModel.setSelectedInstrumentVolume($0) }
                            ),
                            in: 0...1
                        )
                        .tint(AppTheme.accent)

                        Text("\(Int(appModel.selectedInstrumentVolume * 100))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)
                    }
                    .frame(height: 24)
                }
            }

            TransposeControl(
                semitones: Binding(
                    get: { appModel.settings.transposeSemitones },
                    set: { appModel.updateTransposeSemitones($0) }
                )
            )
            .frame(maxWidth: .infinity)
            .frame(height: 28)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var favoritePadsGrid: some View {
        PerformPadsGrid(
            favorites: allFavorites,
            gridSpacing: gridSpacing,
            emptyMessage: "Tap Add Sound to build this live set."
        ) { item in
            favoritePadCell(item)
        }
    }

    @ViewBuilder
    private func favoritePadCell(_ item: FavoritePadItem) -> some View {
        switch item {
        case .bundled(let pad):
            FavoritePadCell(
                title: pad.displayName,
                color: AppTheme.categoryColor(pad.category),
                isSelected: appModel.isPadSelected(pad),
                volume: appModel.padVolume(for: pad),
                layeredPad: pad.isLayered ? pad : nil,
                onSelect: { appModel.selectBundledPad(pad) },
                onVolumeChange: { appModel.setPadVolume($0, for: pad) }
            )
        case .user(let sample):
            FavoritePadCell(
                title: sample.name,
                color: AppTheme.accent,
                isSelected: appModel.isUserSampleSelected(sample),
                volume: appModel.sampleVolume(for: sample),
                onSelect: { Task { await appModel.selectUserInstrument(sample) } },
                onVolumeChange: { appModel.setSampleVolume($0, for: sample) }
            )
        }
    }

    private var allFavorites: [FavoritePadItem] {
        appModel.favoriteBundledPads().map { .bundled($0) }
            + appModel.favoriteUserSamples(from: userSamples).map { .user($0) }
    }

    private var midiConnected: Bool {
        appModel.midiService.connectedSourceName != nil
    }
}

private struct SettingsSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showKeyboard = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Audio") {
                    HStack {
                        Text("Master Volume")
                        Slider(
                            value: Binding(
                                get: { appModel.settings.masterVolume },
                                set: { appModel.updateMasterVolume($0) }
                            ),
                            in: 0...1
                        )
                        Text("\(Int(appModel.settings.masterVolume * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                Section("MIDI") {
                    TransposeControl(
                        semitones: Binding(
                            get: { appModel.settings.transposeSemitones },
                            set: { appModel.updateTransposeSemitones($0) }
                        )
                    )

                    if appModel.midiService.sources.isEmpty {
                        Text("No MIDI sources detected").foregroundStyle(.secondary)
                    } else {
                        Picker("Input Device", selection: Binding(
                            get: { appModel.midiService.sources.first(where: \.isConnected)?.id ?? "" },
                            set: { appModel.midiService.connect(toEndpointID: $0) }
                        )) {
                            ForEach(appModel.midiService.sources) { source in
                                Text(source.name).tag(source.id)
                            }
                        }
                    }

                    Picker("Channel", selection: Binding(
                        get: { Int(appModel.settings.midiChannel) },
                        set: { appModel.updateMIDIChannel(UInt8($0)) }
                    )) {
                        Text("All").tag(0)
                        ForEach(1...16, id: \.self) { Text("\($0)").tag($0) }
                    }

                    Button("Reconnect MIDI") {
                        appModel.midiService.refreshSources()
                        appModel.midiService.connectFirstAvailableSource()
                    }

                    Button("All Notes Off") { appModel.instrumentRouter.allNotesOff() }
                }

                Section("Test") {
                    Toggle("Show Keyboard", isOn: $showKeyboard)
                    if showKeyboard {
                        OnScreenKeyboard { note, velocity, isOn in
                            if isOn { appModel.instrumentRouter.noteOn(note: note, velocity: velocity) }
                            else { appModel.instrumentRouter.noteOff(note: note) }
                        }
                        .listRowInsets(EdgeInsets())
                    }
                }

                Section("Diagnostics") {
                    LabeledContent("Output", value: appModel.audioEngine.routeSnapshot.outputName)
                    LabeledContent("Input", value: appModel.audioEngine.routeSnapshot.inputName)
                    LabeledContent("Sample Rate", value: "\(Int(appModel.audioEngine.routeSnapshot.sampleRate)) Hz")
                    LabeledContent("MIDI", value: appModel.midiService.connectedSourceName ?? "Not connected")
                    LabeledContent("MIDI Events", value: "\(appModel.midiService.receivedEventCount)")
                    if let lastEvent = appModel.midiService.lastReceivedEventDescription {
                        LabeledContent("Last MIDI Event", value: lastEvent)
                    }
                    if !appModel.instrumentRouter.activeNotes.isEmpty {
                        LabeledContent(
                            "Active Notes",
                            value: appModel.instrumentRouter.activeNotes.sorted().map(MIDIUtilities.noteName).joined(separator: ", ")
                        )
                    }
                    if let error = appModel.startupError ?? appModel.instrumentRouter.lastError ?? appModel.midiService.lastError {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
