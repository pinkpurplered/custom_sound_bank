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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    recordingCard
                    if recorder.state == .recorded || recorder.state == .playingBack {
                        trimCard
                        saveCard
                    }
                }
                .padding()
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("Record")
            .onAppear {
                recorder.audioCoordinator = appModel
            }
            .onDisappear {
                recorder.stopPreview()
                if recorder.state != .recording, !isCountingDown {
                    appModel.resumePerformanceAudio()
                }
            }
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

    private var recordingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Capture a Sound")
                .font(.headline)

            Text("Uses the iPhone microphone. If recording fails with iRig connected, disconnect iRig, record, save, then reconnect.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if case .countdown(let value) = recorder.state {
                Text("\(value)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }

            if recorder.state == .recording {
                LevelMeter(level: recorder.level)
                Text(String(format: "%.1f / 10 seconds", recorder.duration))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    Task { await toggleRecording() }
                } label: {
                    Label(
                        recorder.state == .recording ? "Stop" : "Record",
                        systemImage: recorder.state == .recording ? "stop.fill" : "mic.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(recorder.state == .recording ? .red : AppTheme.accent)
                .disabled(isSaving || recorder.state == .playingBack || isCountingDown)

                if recorder.state == .recorded || recorder.state == .playingBack {
                    Button {
                        previewRecording()
                    } label: {
                        Label(
                            recorder.state == .playingBack ? "Playing" : "Preview",
                            systemImage: recorder.state == .playingBack ? "speaker.wave.2.fill" : "play.fill"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(recorder.state == .playingBack)

                    Button(role: .destructive) {
                        recorder.discardRecording()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var trimCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Trim")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Start · \(recorder.trimStart, specifier: "%.2f")s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $recorder.trimStart, in: 0...max(recorder.trimEnd - 0.05, 0.05))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("End · \(recorder.trimEnd, specifier: "%.2f")s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: $recorder.trimEnd,
                    in: min(recorder.trimStart + 0.05, recorder.duration)...max(recorder.duration, 0.1)
                )
            }
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var saveCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Save Instrument")
                .font(.headline)

            TextField("Sample name", text: $sampleName)
                .textFieldStyle(.roundedBorder)

            Picker("Root key", selection: $rootNote) {
                ForEach((48...72).map(UInt8.init), id: \.self) { note in
                    Text(MIDIUtilities.noteName(for: note)).tag(note)
                }
            }
            .pickerStyle(.menu)

            Button {
                Task { await saveSample() }
            } label: {
                Text(isSaving ? "Saving..." : "Save Custom Instrument")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .disabled(sampleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
        }
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var isCountingDown: Bool {
        if case .countdown = recorder.state { return true }
        return false
    }

    private func toggleRecording() async {
        if recorder.state == .recording {
            recorder.stopRecording()
            return
        }
        do {
            try await recorder.startCountdown()
        } catch {
            alertMessage = error.localizedDescription
            appModel.resumePerformanceAudio()
        }
    }

    private func previewRecording() {
        do {
            try recorder.playTrimmedPreview()
        } catch {
            alertMessage = error.localizedDescription
            recorder.restoreRecordingSessionIfNeeded()
        }
    }

    private func saveSample() async {
        isSaving = true
        defer { isSaving = false }
        recorder.stopPreview()
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
            appModel.resumePerformanceAudio()
        }
    }
}
