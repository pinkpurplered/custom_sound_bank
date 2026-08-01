import SwiftUI

struct PerformView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selectedKind: InstrumentKind = .piano

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusSection
                    instrumentSection
                    controlsSection
                    OnScreenKeyboard { note, velocity, isOn in
                        if isOn {
                            appModel.instrumentRouter.noteOn(note: note, velocity: velocity)
                        } else {
                            appModel.instrumentRouter.noteOff(note: note)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Perform")
        }
        .onAppear {
            selectedKind = currentBundledKind
        }
    }

    private var currentBundledKind: InstrumentKind {
        if case .bundled(let kind) = appModel.instrumentRouter.selectedInstrument {
            return kind
        }
        return .piano
    }

    private var statusSection: some View {
        GroupBox("Diagnostics") {
            VStack(alignment: .leading, spacing: 8) {
                Label("Output: \(appModel.audioEngine.routeSnapshot.outputName)", systemImage: "speaker.wave.2")
                Label("Input: \(appModel.audioEngine.routeSnapshot.inputName)", systemImage: "mic")
                Label("Sample rate: \(Int(appModel.audioEngine.routeSnapshot.sampleRate)) Hz", systemImage: "waveform")
                Label(
                    "MIDI: \(appModel.midiService.connectedSourceName ?? "Not connected")",
                    systemImage: "cable.connector"
                )
                if !appModel.instrumentRouter.activeNotes.isEmpty {
                    Text("Active notes: \(appModel.instrumentRouter.activeNotes.sorted().map(MIDIUtilities.noteName).joined(separator: ", "))")
                        .font(.footnote)
                }
                if let error = appModel.startupError ?? appModel.instrumentRouter.lastError ?? appModel.midiService.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var instrumentSection: some View {
        GroupBox("Instrument") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Preset", selection: $selectedKind) {
                    ForEach(InstrumentKind.bundledCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedKind) { _, newValue in
                    appModel.selectBundledInstrument(newValue)
                }

                if case .user(let sample) = appModel.instrumentRouter.selectedInstrument {
                    Text("Custom: \(sample.name) (root \(MIDIUtilities.noteName(for: sample.rootNote)))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var controlsSection: some View {
        GroupBox("Controls") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Master volume")
                    Slider(
                        value: Binding(
                            get: { appModel.settings.masterVolume },
                            set: { appModel.updateMasterVolume($0) }
                        ),
                        in: 0...1
                    )
                }

                Stepper(
                    "MIDI channel: \(appModel.settings.midiChannel)",
                    value: Binding(
                        get: { Int(appModel.settings.midiChannel) },
                        set: { appModel.updateMIDIChannel(UInt8($0)) }
                    ),
                    in: 1...16
                )

                Button("Reconnect MIDI") {
                    appModel.midiService.refreshSources()
                    appModel.midiService.connectFirstAvailableSource()
                }
                .buttonStyle(.bordered)

                Button("All Notes Off") {
                    appModel.instrumentRouter.allNotesOff()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct OnScreenKeyboard: View {
    let onNote: (UInt8, UInt8, Bool) -> Void

    private let whiteNotes: [UInt8] = [60, 62, 64, 65, 67, 69, 71, 72]
    private let blackOffsets: [UInt8: CGFloat] = [61: 0.72, 63: 1.72, 66: 3.72, 68: 4.72, 70: 5.72]

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 4) {
                ForEach(whiteNotes, id: \.self) { note in
                    KeyView(label: MIDIUtilities.noteName(for: note), isBlack: false) {
                        onNote(note, 100, true)
                    } onRelease: {
                        onNote(note, 0, false)
                    }
                }
            }

            HStack(spacing: 4) {
                ForEach(Array(blackOffsets.keys).sorted(), id: \.self) { note in
                    Spacer()
                        .frame(width: (blackOffsets[note] ?? 0) * 36)
                    KeyView(label: "", isBlack: true) {
                        onNote(note, 100, true)
                    } onRelease: {
                        onNote(note, 0, false)
                    }
                    Spacer()
                }
            }
            .padding(.leading, 18)
        }
        .frame(height: 140)
    }
}

private struct KeyView: View {
    let label: String
    let isBlack: Bool
    let onPress: () -> Void
    let onRelease: () -> Void

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(isBlack ? Color.black : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
            )
            .overlay(
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(isBlack ? .white : .black)
                    .padding(.bottom, 8),
                alignment: .bottom
            )
            .frame(width: isBlack ? 28 : 36, height: isBlack ? 90 : 120)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}
