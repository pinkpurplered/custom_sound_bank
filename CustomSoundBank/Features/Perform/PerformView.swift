import SwiftUI

struct PerformView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var userSamples: [UserSampleInstrument] = []
    @State private var showSettings = false

    private let gridSpacing: CGFloat = 3
    private let horizontalPadding: CGFloat = 6

    var body: some View {
        NavigationStack {
            VStack(spacing: 6) {
                statusBar
                performanceControls
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
        }
        .task { userSamples = await appModel.sampleLibrary.allSamples() }
    }

    private var statusBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: midiConnected ? "cable.connector" : "cable.connector.slash")
                    .foregroundStyle(midiConnected ? .green : .secondary)
                    .font(.caption)

                Text(midiConnected ? (appModel.midiService.connectedSourceName ?? "MIDI") : "No MIDI")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Text(appModel.instrumentRouter.selectedInstrument.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(AppTheme.accent)
                    .font(.caption2)

                Slider(
                    value: Binding(
                        get: { appModel.settings.masterVolume },
                        set: { appModel.updateMasterVolume($0) }
                    ),
                    in: 0...1
                )
                .tint(AppTheme.accent)

                Text("\(Int(appModel.settings.masterVolume * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .trailing)
            }
        }
        .padding(10)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.top, 2)
    }

    private var performanceControls: some View {
        HStack(spacing: 10) {
            SynthWheelControl(
                title: "Mod",
                value: Binding(
                    get: { appModel.instrumentRouter.modulation },
                    set: { appModel.setModulation($0) }
                )
            )

            SynthWheelControl(
                title: "Pitch",
                value: Binding(
                    get: { (appModel.instrumentRouter.pitchBend + 1) / 2 },
                    set: { appModel.setPitchBend($0 * 2 - 1) }
                ),
                centerSnap: true
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Voice")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(appModel.instrumentRouter.selectedInstrument.displayName)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.accent)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: "speaker.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Slider(
                        value: Binding(
                            get: { appModel.selectedInstrumentVolume },
                            set: { appModel.setSelectedInstrumentVolume($0) }
                        ),
                        in: 0...1
                    )
                    .tint(AppTheme.accent)

                    Text("\(Int(appModel.selectedInstrumentVolume * 100))%")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(10)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var favoritePadsGrid: some View {
        GeometryReader { geometry in
            let favorites = allFavorites
            if favorites.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star").font(.largeTitle).foregroundStyle(.secondary)
                    Text("No favorites yet").font(.headline)
                    Text("Go to Sound Samples and tap ★ to pin sounds here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let layout = gridLayout(itemCount: favorites.count, availableSize: geometry.size)
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: layout.columns),
                    spacing: gridSpacing
                ) {
                    ForEach(favorites) { item in
                        favoritePadCell(item).frame(height: layout.cellHeight)
                    }
                }
            }
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

    private func gridLayout(itemCount: Int, availableSize: CGSize) -> (columns: Int, cellHeight: CGFloat) {
        var bestColumns = 3
        var bestCellHeight: CGFloat = 0
        for columns in 3...5 {
            let rows = Int(ceil(Double(itemCount) / Double(columns)))
            let cellWidth = (availableSize.width - gridSpacing * CGFloat(columns - 1)) / CGFloat(columns)
            let cellHeight = (availableSize.height - gridSpacing * CGFloat(rows - 1)) / CGFloat(rows)
            let size = min(cellWidth, cellHeight)
            if size > bestCellHeight {
                bestCellHeight = size
                bestColumns = columns
            }
        }
        let rows = Int(ceil(Double(itemCount) / Double(bestColumns)))
        let cellHeight = (availableSize.height - gridSpacing * CGFloat(rows - 1)) / CGFloat(rows)
        return (bestColumns, max(cellHeight, 36))
    }

    private var midiConnected: Bool {
        appModel.midiService.connectedSourceName != nil
    }
}

private enum FavoritePadItem: Identifiable {
    case bundled(BundledPad)
    case user(UserSampleInstrument)

    var id: String {
        switch self {
        case .bundled(let pad): "b-\(pad.id)"
        case .user(let sample): "u-\(sample.id.uuidString)"
        }
    }
}

private struct FavoritePadCell: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let volume: Float
    let onSelect: () -> Void
    let onVolumeChange: (Float) -> Void

    @State private var isPressed = false
    @State private var showVolume = false

    var body: some View {
        VStack(spacing: 3) {
            Button(action: onSelect) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isSelected ? color : color.opacity(isPressed ? 0.32 : 0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                isSelected ? color : color.opacity(0.3),
                                lineWidth: isSelected ? 2 : 0.5
                            )
                    )
                    .scaleEffect(isPressed ? 0.95 : 1)
                    .animation(.easeOut(duration: 0.08), value: isPressed)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
            .onLongPressGesture(minimumDuration: 0.35) {
                showVolume.toggle()
            }

            if showVolume {
                Slider(value: Binding(
                    get: { volume },
                    set: { onVolumeChange($0) }
                ), in: 0...1)
                .tint(color)
                .controlSize(.mini)
            }
        }
    }
}

private struct SynthWheelControl: View {
    let title: String
    @Binding var value: Float
    var centerSnap = false

    private let wheelWidth: CGFloat = 44
    private let wheelHeight: CGFloat = 72

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5)
                    )

                if centerSnap {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: wheelWidth - 12, height: 1)
                }

                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .offset(y: thumbOffset)
            }
            .frame(width: wheelWidth, height: wheelHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let clampedY = max(0, min(wheelHeight, gesture.location.y))
                        value = 1 - Float(clampedY / wheelHeight)
                    }
                    .onEnded { _ in
                        if centerSnap {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                value = 0.5
                            }
                        }
                    }
            )

            Text(displayValue)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: wheelWidth)
        }
    }

    private var thumbOffset: CGFloat {
        let range = wheelHeight - 22
        return (CGFloat(1 - value) * range) - range / 2
    }

    private var displayValue: String {
        if centerSnap {
            let bend = Int((value * 2 - 1) * 100)
            return bend == 0 ? "0" : (bend > 0 ? "+\(bend)" : "\(bend)")
        }
        return "\(Int(value * 100))"
    }
}

private struct SettingsSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showKeyboard = false

    var body: some View {
        NavigationStack {
            Form {
                Section("MIDI") {
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
