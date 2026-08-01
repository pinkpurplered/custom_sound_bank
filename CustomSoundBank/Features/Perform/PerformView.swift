import SwiftUI

struct PerformView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var selectedKind: InstrumentKind = .piano
    @State private var showDiagnostics = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    instrumentSection
                    controlsSection
                    keyboardSection
                    diagnosticsSection
                }
                .padding()
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("Perform")
        }
        .onAppear {
            selectedKind = currentBundledKind
        }
        .onChange(of: appModel.instrumentRouter.selectedInstrument) { _, instrument in
            if case .bundled(let kind) = instrument {
                selectedKind = kind
            }
        }
    }

    private var currentBundledKind: InstrumentKind {
        if case .bundled(let kind) = appModel.instrumentRouter.selectedInstrument {
            return kind
        }
        return .piano
    }

    private var instrumentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instrument")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(InstrumentKind.bundledCases) { kind in
                        InstrumentCard(kind: kind, isSelected: selectedKind == kind) {
                            selectedKind = kind
                            appModel.selectBundledInstrument(kind)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            if case .user(let sample) = appModel.instrumentRouter.selectedInstrument {
                Label(
                    "Custom: \(sample.name) · root \(MIDIUtilities.noteName(for: sample.rootNote))",
                    systemImage: "mic.fill"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Controls")
                .font(.headline)

            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundStyle(AppTheme.accent)
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
                        .frame(width: 36, alignment: .trailing)
                }

                Stepper(
                    "MIDI channel \(appModel.settings.midiChannel)",
                    value: Binding(
                        get: { Int(appModel.settings.midiChannel) },
                        set: { appModel.updateMIDIChannel(UInt8($0)) }
                    ),
                    in: 1...16
                )

                HStack(spacing: 12) {
                    Button("Reconnect MIDI") {
                        appModel.midiService.refreshSources()
                        appModel.midiService.connectFirstAvailableSource()
                    }
                    .buttonStyle(.bordered)

                    Button("All Notes Off") {
                        appModel.instrumentRouter.allNotesOff()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                }
            }
            .padding()
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var keyboardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Keyboard")
                .font(.headline)
            OnScreenKeyboard { note, velocity, isOn in
                if isOn {
                    appModel.instrumentRouter.noteOn(note: note, velocity: velocity)
                } else {
                    appModel.instrumentRouter.noteOff(note: note)
                }
            }
        }
    }

    private var diagnosticsSection: some View {
        DisclosureGroup("Diagnostics", isExpanded: $showDiagnostics) {
            VStack(alignment: .leading, spacing: 8) {
                diagnosticRow("Output", appModel.audioEngine.routeSnapshot.outputName, icon: "hifispeaker.fill")
                diagnosticRow("Input", appModel.audioEngine.routeSnapshot.inputName, icon: "mic.fill")
                diagnosticRow("Sample rate", "\(Int(appModel.audioEngine.routeSnapshot.sampleRate)) Hz", icon: "waveform")
                diagnosticRow("MIDI", appModel.midiService.connectedSourceName ?? "Not connected", icon: "cable.connector")
                if !appModel.instrumentRouter.activeNotes.isEmpty {
                    diagnosticRow(
                        "Active notes",
                        appModel.instrumentRouter.activeNotes.sorted().map(MIDIUtilities.noteName).joined(separator: ", "),
                        icon: "music.note.list"
                    )
                }
                if let error = appModel.startupError ?? appModel.instrumentRouter.lastError ?? appModel.midiService.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(.top, 8)
        }
        .font(.subheadline)
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func diagnosticRow(_ title: String, _ value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .frame(width: 18)
                .foregroundStyle(AppTheme.accent)
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.footnote)
    }
}
