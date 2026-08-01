import SwiftUI

struct CreateSampleView: View {
    @EnvironmentObject private var appModel: AppModel
    @StateObject private var recorder = SampleRecorder()
    @State private var sampleName = ""
    @State private var rootNote: UInt8 = 60
    @State private var isSaving = false
    @State private var alertMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Recording") {
                    Text("Uses the iPhone built-in microphone. If iRig is connected and recording fails, disconnect iRig, record, save, then reconnect for performance.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if case .countdown(let value) = recorder.state {
                        Text("Starting in \(value)...")
                            .font(.title2)
                    }

                    if recorder.state == .recording {
                        ProgressView(value: recorder.level)
                        Text(String(format: "Recording %.1fs / 10s", recorder.duration))
                    }

                    HStack {
                        Button(recorder.state == .recording ? "Stop" : "Record") {
                            Task {
                                if recorder.state == .recording {
                                    recorder.stopRecording()
                                } else {
                                    do {
                                        try await recorder.startCountdown()
                                    } catch {
                                        alertMessage = error.localizedDescription
                                    }
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSaving || recorder.state == .playingBack)

                        if recorder.state == .recorded || recorder.state == .playingBack {
                            Button("Preview") {
                                do {
                                    try recorder.playTrimmedPreview()
                                } catch {
                                    alertMessage = error.localizedDescription
                                }
                            }
                            Button("Discard", role: .destructive) {
                                recorder.discardRecording()
                            }
                        }
                    }
                }

                if recorder.state == .recorded || recorder.state == .playingBack {
                    Section("Trim") {
                        VStack(alignment: .leading) {
                            Text("Start: \(recorder.trimStart, specifier: "%.2f")s")
                            Slider(value: $recorder.trimStart, in: 0...max(recorder.trimEnd - 0.05, 0.05))
                        }
                        VStack(alignment: .leading) {
                            Text("End: \(recorder.trimEnd, specifier: "%.2f")s")
                            Slider(value: $recorder.trimEnd, in: min(recorder.trimStart + 0.05, recorder.duration)...max(recorder.duration, 0.1))
                        }
                    }

                    Section("Instrument") {
                        TextField("Sample name", text: $sampleName)
                        Picker("Root key", selection: $rootNote) {
                            ForEach((48...72).map(UInt8.init), id: \.self) { note in
                                Text(MIDIUtilities.noteName(for: note)).tag(note)
                            }
                        }
                        Button(isSaving ? "Saving..." : "Save Custom Instrument") {
                            Task { await saveSample() }
                        }
                        .disabled(sampleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    }
                }
            }
            .navigationTitle("Record Sample")
            .alert("Recording", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func saveSample() async {
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await appModel.saveSample(
                from: recorder,
                name: sampleName.trimmingCharacters(in: .whitespacesAndNewlines),
                rootNote: rootNote
            )
            sampleName = ""
            recorder.discardRecording()
            alertMessage = "Custom instrument saved."
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
