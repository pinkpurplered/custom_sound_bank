import SwiftUI

struct BrowsePadsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var userSamples: [UserSampleInstrument] = []
    @State private var searchText = ""
    @State private var selectedCategory: PadCategory?
    @State private var previewingID: String?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var filteredBundledPads: [BundledPad] {
        var pads = BundledPad.catalog
        if let selectedCategory {
            pads = pads.filter { $0.category == selectedCategory }
        }
        if isSearching {
            pads = pads.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchText)
                || $0.category.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        return pads
    }

    private var filteredUserSamples: [UserSampleInstrument] {
        guard isSearching else { return userSamples }
        return userSamples.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var visibleCategories: [PadCategory] {
        if let selectedCategory { return [selectedCategory] }
        if isSearching {
            let categories = Set(filteredBundledPads.map(\.category))
            return PadCategory.allCases.filter { categories.contains($0) }
        }
        return PadCategory.allCases.filter { !BundledPad.pads(for: $0).isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerBanner
                    categoryFilterBar

                    if isSearching && filteredBundledPads.isEmpty && filteredUserSamples.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .padding(.top, 40)
                    } else {
                        bundledSections
                        if !filteredUserSamples.isEmpty {
                            customSection
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(AppTheme.screenBackground)
            .navigationTitle("Sound Samples")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search instruments")
        }
        .task { userSamples = await appModel.sampleLibrary.allSamples() }
    }

    private var headerBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(BundledPad.catalog.count) built-in sounds")
                    .font(.subheadline.weight(.semibold))

                Text("Tap to select & preview middle C. Star ★ to pin on Live.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.top, 4)
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryFilterChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    color: AppTheme.accent,
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(PadCategory.allCases) { category in
                    let count = BundledPad.pads(for: category).count
                    if count > 0 {
                        CategoryFilterChip(
                            title: "\(category.displayName) (\(count))",
                            icon: category.iconName,
                            color: AppTheme.categoryColor(category),
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var bundledSections: some View {
        if isSearching {
            searchResultsSection
        } else {
            ForEach(visibleCategories) { category in
                categorySection(category)
            }
        }
    }

    private func categorySection(_ category: PadCategory) -> some View {
        let pads = BundledPad.pads(for: category)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: category.iconName)
                    .foregroundStyle(AppTheme.categoryColor(category))
                Text(category.displayName)
                    .font(.headline)
                Text("\(pads.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(pads) { pad in
                    bundledCard(pad)
                }
            }
        }
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredBundledPads) { pad in
                    bundledCard(pad)
                }
            }
        }
    }

    private func bundledCard(_ pad: BundledPad) -> some View {
        SamplePadCard(
            title: pad.displayName,
            subtitle: pad.category.displayName,
            icon: pad.category.iconName,
            color: AppTheme.categoryColor(pad.category),
            isSelected: appModel.isPadSelected(pad),
            isFavorite: appModel.isFavorite(pad: pad),
            isPreviewing: previewingID == pad.id,
            onFavoriteToggle: { appModel.toggleFavorite(pad: pad) },
            onSelect: { appModel.selectBundledPad(pad) },
            onPreview: { previewBundled(pad) }
        )
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .foregroundStyle(AppTheme.accent)
                Text("Your Recordings")
                    .font(.headline)
                Text("\(filteredUserSamples.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredUserSamples) { sample in
                    userSampleCard(sample)
                }
            }
        }
    }

    private func userSampleCard(_ sample: UserSampleInstrument) -> some View {
        SamplePadCard(
            title: sample.name,
            subtitle: "Root: \(MIDIUtilities.noteName(for: sample.rootNote))",
            icon: "mic.fill",
            color: AppTheme.accent,
            isSelected: appModel.isUserSampleSelected(sample),
            isFavorite: appModel.isFavorite(sample: sample),
            isPreviewing: previewingID == sample.id.uuidString,
            onFavoriteToggle: { appModel.toggleFavorite(sample: sample) },
            onSelect: { Task { await appModel.selectUserInstrument(sample) } },
            onPreview: { Task { await previewUser(sample) } }
        )
    }

    private func previewBundled(_ pad: BundledPad) {
        previewingID = pad.id
        appModel.previewBundledPad(pad)
        clearPreviewing(after: 1.3, id: pad.id)
    }

    private func previewUser(_ sample: UserSampleInstrument) async {
        let id = sample.id.uuidString
        previewingID = id
        await appModel.previewUserInstrument(sample)
        clearPreviewing(after: 1.3, id: id)
    }

    private func clearPreviewing(after seconds: Double, id: String) {
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            if previewingID == id {
                previewingID = nil
            }
        }
    }
}
