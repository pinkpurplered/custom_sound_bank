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
    let cellContent: (FavoritePadItem) -> AnyView

    init(
        favorites: [FavoritePadItem],
        gridSpacing: CGFloat = 3,
        minCellHeight: CGFloat = 36,
        columnRange: ClosedRange<Int> = 3...5,
        @ViewBuilder cellContent: @escaping (FavoritePadItem) -> some View
    ) {
        self.favorites = favorites
        self.gridSpacing = gridSpacing
        self.minCellHeight = minCellHeight
        self.columnRange = columnRange
        self.cellContent = { AnyView(cellContent($0)) }
    }

    var body: some View {
        GeometryReader { geometry in
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
                        cellContent(item).frame(height: layout.cellHeight)
                    }
                }
            }
        }
    }

    private func gridLayout(itemCount: Int, availableSize: CGSize) -> (columns: Int, cellHeight: CGFloat) {
        var bestColumns = columnRange.lowerBound
        var bestCellHeight: CGFloat = 0
        for columns in columnRange {
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
        return (bestColumns, max(cellHeight, minCellHeight))
    }
}
