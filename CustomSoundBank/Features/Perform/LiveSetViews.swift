import SwiftUI

struct LiveSetToolbar: View {
    @EnvironmentObject private var appModel: AppModel
    let onAddSound: () -> Void

    @State private var showNewSetAlert = false
    @State private var newSetName = ""

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Menu {
                    ForEach(appModel.liveSets) { set in
                        Button {
                            appModel.selectLiveSet(id: set.id)
                        } label: {
                            if appModel.activeLiveSetID == set.id {
                                Label(set.name, systemImage: "checkmark")
                            } else {
                                Text(set.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(appModel.activeLiveSet?.name ?? "Live Set")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.accent)
                }

                Spacer(minLength: 0)

                if appModel.liveSetIsDirty {
                    Text("Unsaved")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                Button("Save") {
                    appModel.saveActiveLiveSet()
                }
                .font(.subheadline.weight(.semibold))
                .disabled(!appModel.liveSetIsDirty)

                Button {
                    newSetName = appModel.suggestedLiveSetName()
                    showNewSetAlert = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.accent)
            }

            Button(action: onAddSound) {
                Label("Add Sound", systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .alert("New Live Set", isPresented: $showNewSetAlert) {
            TextField("Name", text: $newSetName)
            Button("Create") {
                let name = newSetName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                appModel.createLiveSet(named: name)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose sounds, set volumes, then tap Save.")
        }
    }
}

struct AddSoundSheet: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var userSamples: [UserSampleInstrument] = []
    @State private var searchText = ""

    private var filteredPads: [BundledPad] {
        let pads = BundledPad.catalog
        guard !searchText.isEmpty else { return pads }
        return pads.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
            || $0.category.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredUserSamples: [UserSampleInstrument] {
        guard !searchText.isEmpty else { return userSamples }
        return userSamples.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !filteredUserSamples.isEmpty {
                    Section("Your Recordings") {
                        ForEach(filteredUserSamples) { sample in
                            soundRow(
                                title: sample.name,
                                subtitle: "Custom sample",
                                icon: "waveform",
                                color: AppTheme.accent,
                                isInSet: appModel.isFavorite(sample: sample)
                            ) {
                                Task {
                                    await appModel.addUserSampleToActiveLiveSet(sample)
                                    dismiss()
                                }
                            }
                        }
                    }
                }

                ForEach(PadCategory.allCases) { category in
                    let pads = filteredPads.filter { $0.category == category }
                    if !pads.isEmpty {
                        Section(category.displayName) {
                            ForEach(pads) { pad in
                                soundRow(
                                    title: pad.displayName,
                                    subtitle: pad.isLayered ? "Layered" : category.displayName,
                                    icon: category.iconName,
                                    color: AppTheme.categoryColor(category),
                                    isInSet: appModel.isFavorite(pad: pad)
                                ) {
                                    appModel.addBundledPadToActiveLiveSet(pad)
                                    dismiss()
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search sounds")
            .navigationTitle("Add Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task { userSamples = await appModel.sampleLibrary.allSamples() }
    }

    private func soundRow(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        isInSet: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if isInSet {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }
}
