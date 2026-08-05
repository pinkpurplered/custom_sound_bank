import SwiftUI

struct LiveModeView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var userSamples: [UserSampleInstrument] = []

    private let wheelWidth: CGFloat = 92
    private let gridSpacing: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 12) {
                synthWheelsColumn
                    .frame(maxHeight: .infinity)

                VStack(spacing: 8) {
                    liveTopBar
                    padsGrid
                        .frame(maxHeight: .infinity)
                    voiceVolumeStrip
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, max(geometry.safeAreaInsets.leading, geometry.safeAreaInsets.trailing, 12))
            .padding(.vertical, 8)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .task { userSamples = await appModel.sampleLibrary.allSamples() }
        .keepScreenAwake()
        .onAppear { OrientationController.lockToLandscape() }
        .onDisappear { OrientationController.unlock() }
    }

    private var synthWheelsColumn: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                SynthWheelControl(
                    title: "Pitch",
                    value: Binding(
                        get: { (appModel.instrumentRouter.pitchBend + 1) / 2 },
                        set: { appModel.setPitchBend($0 * 2 - 1) }
                    ),
                    centerSnap: true,
                    prominent: true
                )
                .frame(width: wheelWidth)

                SynthWheelControl(
                    title: "Mod",
                    value: Binding(
                        get: { appModel.instrumentRouter.modulation },
                        set: { appModel.setModulation($0) }
                    ),
                    prominent: true
                )
                .frame(width: wheelWidth)
            }

            TransposeControl(
                semitones: Binding(
                    get: { appModel.settings.transposeSemitones },
                    set: { appModel.updateTransposeSemitones($0) }
                ),
                prominent: true
            )
            .padding(.horizontal, 4)
        }
    }

    private var liveTopBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Label("Exit", systemImage: "xmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            HStack(spacing: 5) {
                Image(systemName: midiConnected ? "cable.connector" : "cable.connector.slash")
                    .foregroundStyle(midiConnected ? .green : .secondary)
                    .font(.caption)
                Text(midiConnected ? (appModel.midiService.connectedSourceName ?? "MIDI") : "No MIDI")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(appModel.activeLiveSet?.name ?? appModel.instrumentRouter.selectedInstrument.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .lineLimit(1)
        }
        .frame(height: 28)
    }

    private var padsGrid: some View {
        PerformPadsGrid(
            favorites: allFavorites,
            gridSpacing: gridSpacing,
            minCellHeight: 44,
            columnRange: 2...6
        ) { item in
            favoritePadCell(item)
        }
    }

    private var voiceVolumeStrip: some View {
        Group {
            if case .bundled(let pad) = appModel.instrumentRouter.selectedInstrument, pad.isLayered {
                VStack(spacing: 4) {
                    LayerVolumeControls(
                        layeredPad: pad,
                        labelWidth: 44,
                        valueWidth: 28,
                        labelFont: .caption.weight(.semibold)
                    )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                HStack(spacing: 8) {
                    Text("Vol")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .leading)

                    Slider(
                        value: Binding(
                            get: { appModel.selectedInstrumentVolume },
                            set: { appModel.setSelectedInstrumentVolume($0) }
                        ),
                        in: 0...1
                    )
                    .tint(AppTheme.accent)

                    Text("\(Int(appModel.selectedInstrumentVolume * 100))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .trailing)
                }
                .frame(height: 28)
                .padding(.horizontal, 10)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
