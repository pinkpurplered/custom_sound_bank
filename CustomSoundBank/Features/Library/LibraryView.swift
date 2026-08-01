import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var samples: [UserSampleInstrument] = []
    @State private var renameTarget: UserSampleInstrument?
    @State private var renameText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                if samples.isEmpty {
                    ContentUnavailableView(
                        "No custom samples",
                        systemImage: "waveform",
                        description: Text("Record a sound in the Record tab to build your library.")
                    )
                } else {
                    ForEach(samples) { sample in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(sample.name)
                                    .font(.headline)
                                Text("Root: \(MIDIUtilities.noteName(for: sample.rootNote))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Use") {
                                Task {
                                    await appModel.selectUserInstrument(sample)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .swipeActions {
                            Button("Rename") {
                                renameTarget = sample
                                renameText = sample.name
                            }
                            Button("Delete", role: .destructive) {
                                Task { await delete(sample) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .task { await reload() }
            .refreshable { await reload() }
            .alert("Rename Sample", isPresented: Binding(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Save") {
                    Task { await rename() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Library", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func reload() async {
        samples = await appModel.sampleLibrary.allSamples()
    }

    private func delete(_ sample: UserSampleInstrument) async {
        do {
            try await appModel.sampleLibrary.delete(id: sample.id)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rename() async {
        guard let renameTarget else { return }
        do {
            try await appModel.sampleLibrary.rename(id: renameTarget.id, to: renameText)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
        self.renameTarget = nil
    }
}
