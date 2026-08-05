import SwiftUI

enum FavoritePadItem: Identifiable {
    case bundled(BundledPad)
    case user(UserSampleInstrument)

    var id: String {
        switch self {
        case .bundled(let pad): "b-\(pad.id)"
        case .user(let sample): "u-\(sample.id.uuidString)"
        }
    }
}

struct FavoritePadCell: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let volume: Float
    var layeredPad: BundledPad? = nil
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
                if let layeredPad {
                    LayerVolumeControls(
                        layeredPad: layeredPad,
                        labelWidth: 40,
                        valueWidth: 20
                    )
                } else {
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
}

struct LayerVolumeControls: View {
    @EnvironmentObject private var appModel: AppModel
    let layeredPad: BundledPad
    var labelWidth: CGFloat = 52
    var valueWidth: CGFloat = 24
    var labelFont: Font = .caption2.weight(.semibold)

    var body: some View {
        VStack(spacing: 4) {
            ForEach(layeredPad.layers ?? [], id: \.padID) { spec in
                if let layerPad = BundledPad.pad(withID: spec.padID) {
                    HStack(spacing: 6) {
                        Text(layerPad.layerVolumeLabel)
                            .font(labelFont)
                            .foregroundStyle(.secondary)
                            .frame(width: labelWidth, alignment: .leading)

                        Slider(
                            value: Binding(
                                get: { appModel.layerVolume(forLayerPadID: spec.padID, in: layeredPad) },
                                set: { appModel.setLayerVolume($0, forLayerPadID: spec.padID, in: layeredPad) }
                            ),
                            in: 0...1
                        )
                        .tint(AppTheme.accent)

                        Text("\(Int(appModel.layerVolume(forLayerPadID: spec.padID, in: layeredPad) * 100))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: valueWidth, alignment: .trailing)
                    }
                    .frame(height: 24)
                }
            }
        }
    }
}

struct TransposeControl: View {
    @Binding var semitones: Int
    var range: ClosedRange<Int> = -12...12
    var prominent = false

    var body: some View {
        HStack(spacing: prominent ? 10 : 6) {
            Text("Key")
                .font(prominent ? .subheadline.weight(.semibold) : .caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Button {
                semitones = max(range.lowerBound, semitones - 1)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(prominent ? .title3 : .body)
                    .foregroundStyle(semitones > range.lowerBound ? AppTheme.accent : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(semitones <= range.lowerBound)

            Text(displayText)
                .font(prominent ? .headline.monospacedDigit() : .caption.monospacedDigit().weight(.semibold))
                .frame(minWidth: prominent ? 44 : 32)

            Button {
                semitones = min(range.upperBound, semitones + 1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(prominent ? .title3 : .body)
                    .foregroundStyle(semitones < range.upperBound ? AppTheme.accent : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(semitones >= range.upperBound)
        }
    }

    private var displayText: String {
        if semitones == 0 { return "0" }
        return semitones > 0 ? "+\(semitones)" : "\(semitones)"
    }
}

struct SynthWheelControl: View {
    let title: String
    @Binding var value: Float
    var centerSnap = false
    var prominent = false

    var body: some View {
        GeometryReader { geometry in
            let wheelWidth = geometry.size.width
            let labelHeight: CGFloat = prominent ? 18 : 16
            let valueHeight: CGFloat = prominent ? 16 : 14
            let wheelHeight = max(prominent ? 120 : 80, geometry.size.height - labelHeight - valueHeight - 8)
            let thumbCap: CGFloat = prominent ? 48 : 36
            let thumbSize = min(wheelWidth * (prominent ? 0.5 : 0.38), thumbCap)

            VStack(spacing: 4) {
                Text(title)
                    .font(prominent ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(height: labelHeight)

                ZStack {
                    RoundedRectangle(cornerRadius: prominent ? 12 : 10, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                        .overlay(
                            RoundedRectangle(cornerRadius: prominent ? 12 : 10, style: .continuous)
                                .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
                        )

                    if centerSnap {
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(width: wheelWidth - 16, height: 1.5)
                    }

                    Circle()
                        .fill(AppTheme.accent)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                        .offset(y: thumbOffset(wheelHeight: wheelHeight, thumbSize: thumbSize))
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
                    .font(prominent ? .caption.monospacedDigit() : .caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(height: valueHeight)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
    }

    private func thumbOffset(wheelHeight: CGFloat, thumbSize: CGFloat) -> CGFloat {
        let range = wheelHeight - thumbSize
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

struct PerformPadsGrid: View {
    let favorites: [FavoritePadItem]
    let gridSpacing: CGFloat
    let minCellHeight: CGFloat
    let columnRange: ClosedRange<Int>
    let emptyMessage: String
    let cellContent: (FavoritePadItem) -> AnyView

    init(
        favorites: [FavoritePadItem],
        gridSpacing: CGFloat = 3,
        minCellHeight: CGFloat = 36,
        columnRange: ClosedRange<Int> = 3...5,
        emptyMessage: String = "Go to Sound Samples and tap ★ to pin sounds here.",
        @ViewBuilder cellContent: @escaping (FavoritePadItem) -> some View
    ) {
        self.favorites = favorites
        self.gridSpacing = gridSpacing
        self.minCellHeight = minCellHeight
        self.columnRange = columnRange
        self.emptyMessage = emptyMessage
        self.cellContent = { AnyView(cellContent($0)) }
    }

    var body: some View {
        GeometryReader { geometry in
            if favorites.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "star").font(.largeTitle).foregroundStyle(.secondary)
                    Text("No sounds in this set").font(.headline)
                    Text(emptyMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let layout = gridLayout(itemCount: favorites.count, availableSize: geometry.size)
                let rows = chunked(favorites, columns: layout.columns)
                VStack(spacing: gridSpacing) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, rowItems in
                        HStack(spacing: gridSpacing) {
                            if rowItems.count < layout.columns {
                                Spacer(minLength: 0)
                            }
                            ForEach(rowItems) { item in
                                cellContent(item)
                                    .frame(width: layout.cellWidth, height: layout.cellHeight)
                            }
                            if rowItems.count < layout.columns {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private func chunked(_ items: [FavoritePadItem], columns: Int) -> [[FavoritePadItem]] {
        guard columns > 0 else { return [items] }
        return stride(from: 0, to: items.count, by: columns).map { start in
            Array(items[start..<min(start + columns, items.count)])
        }
    }

    private struct GridLayoutMetrics {
        let columns: Int
        let rows: Int
        let cellWidth: CGFloat
        let cellHeight: CGFloat
    }

    private func gridLayout(itemCount: Int, availableSize: CGSize) -> GridLayoutMetrics {
        guard itemCount > 0 else {
            return GridLayoutMetrics(
                columns: columnRange.lowerBound,
                rows: 0,
                cellWidth: 0,
                cellHeight: minCellHeight
            )
        }

        let upperBound = min(itemCount, columnRange.upperBound)
        let lowerBound = max(1, min(columnRange.lowerBound, itemCount))

        var bestColumns = lowerBound
        var bestWaste = Int.max
        var bestCellSize: CGFloat = -1
        var bestBalance = Int.max

        for columns in lowerBound...upperBound {
            let rows = Int(ceil(Double(itemCount) / Double(columns)))
            let waste = columns * rows - itemCount
            let cellWidth = (availableSize.width - gridSpacing * CGFloat(columns - 1)) / CGFloat(columns)
            let cellHeight = (availableSize.height - gridSpacing * CGFloat(rows - 1)) / CGFloat(rows)
            let cellSize = min(cellWidth, cellHeight)
            let balance = abs(columns - rows)

            let isBetter = waste < bestWaste
                || (waste == bestWaste && cellSize > bestCellSize + 0.5)
                || (waste == bestWaste && abs(cellSize - bestCellSize) <= 0.5 && balance < bestBalance)

            if isBetter {
                bestColumns = columns
                bestWaste = waste
                bestCellSize = cellSize
                bestBalance = balance
            }
        }

        let rows = Int(ceil(Double(itemCount) / Double(bestColumns)))
        let cellWidth = (availableSize.width - gridSpacing * CGFloat(bestColumns - 1)) / CGFloat(bestColumns)
        let rawCellHeight = (availableSize.height - gridSpacing * CGFloat(rows - 1)) / CGFloat(rows)
        let cellHeight = max(rawCellHeight, minCellHeight)
        return GridLayoutMetrics(columns: bestColumns, rows: rows, cellWidth: cellWidth, cellHeight: cellHeight)
    }
}
