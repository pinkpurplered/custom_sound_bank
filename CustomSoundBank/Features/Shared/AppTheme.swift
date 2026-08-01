import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.35, green: 0.55, blue: 0.95)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let screenBackground = Color(.systemBackground)

    static func categoryColor(_ category: PadCategory) -> Color {
        switch category {
        case .piano: Color(red: 0.30, green: 0.52, blue: 0.95)
        case .musicBox: Color(red: 0.25, green: 0.72, blue: 0.62)
        case .organ: Color(red: 0.90, green: 0.45, blue: 0.30)
        case .guitar: Color(red: 0.82, green: 0.58, blue: 0.22)
        case .bass: Color(red: 0.55, green: 0.35, blue: 0.78)
        case .strings: Color(red: 0.55, green: 0.38, blue: 0.88)
        case .choir: Color(red: 0.92, green: 0.42, blue: 0.62)
        case .brass: Color(red: 0.95, green: 0.68, blue: 0.20)
        case .woodwind: Color(red: 0.28, green: 0.68, blue: 0.48)
        case .synthLead: Color(red: 0.95, green: 0.55, blue: 0.25)
        case .synthPad: Color(red: 0.45, green: 0.65, blue: 0.95)
        case .ethnic: Color(red: 0.72, green: 0.48, blue: 0.32)
        case .percussion: Color(red: 0.58, green: 0.58, blue: 0.62)
        }
    }
}

private struct ScalePressButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SamplePadCard: View {
    let title: String
    var subtitle: String?
    let icon: String
    let color: Color
    let isSelected: Bool
    var isFavorite = false
    var isPreviewing = false
    var onFavoriteToggle: (() -> Void)?
    let onSelect: () -> Void
    let onPreview: () -> Void

    var body: some View {
        Button {
            onSelect()
            onPreview()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    if let onFavoriteToggle {
                        Button(action: onFavoriteToggle) {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(isFavorite ? .yellow : .secondary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Button(action: onPreview) {
                        Image(systemName: isPreviewing ? "speaker.wave.2.fill" : "play.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isPreviewing ? color : .secondary)
                            .symbolEffect(.variableColor.iterative, isActive: isPreviewing)
                            .frame(width: 28, height: 28)
                            .background(color.opacity(isPreviewing ? 0.22 : 0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 8)

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                        .frame(width: 36, height: 36)
                        .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        if let subtitle {
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                if isSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                        Text("Selected")
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(color)
                    .padding(.top, 8)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? color.opacity(0.12) : AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? color : color.opacity(0.2),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(ScalePressButtonStyle())
    }
}

struct CategoryFilterChip: View {
    let title: String
    let icon: String?
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? .white : color)
            .background(
                Capsule().fill(isSelected ? color : color.opacity(0.12))
            )
            .overlay(
                Capsule().strokeBorder(color.opacity(isSelected ? 0 : 0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PadButton: View {
    let title: String
    var icon: String?
    let color: Color
    let isSelected: Bool
    var compact = false
    var isFavorite = false
    var showFavoriteButton = false
    var onFavoriteToggle: (() -> Void)?
    let action: () -> Void

    @State private var isPressed = false

    private var cornerRadius: CGFloat { compact ? 6 : 12 }
    private var font: Font { compact ? .caption2.weight(.semibold) : .caption.weight(.semibold) }
    private var lineLimit: Int { compact ? 3 : 2 }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if compact {
                        Text(title)
                    } else {
                        VStack(spacing: 6) {
                            if let icon {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .opacity(isSelected ? 1 : 0.85)
                            }
                            Text(title)
                        }
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
                .font(font)
                .multilineTextAlignment(.center)
                .lineLimit(lineLimit)
                .minimumScaleFactor(compact ? 0.6 : 0.7)
                .frame(maxWidth: .infinity, maxHeight: compact ? .infinity : nil)
                .foregroundStyle(isSelected ? .white : .primary)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isSelected ? color : color.opacity(isPressed ? (compact ? 0.32 : 0.28) : (compact ? 0.18 : 0.14)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            isSelected ? color : color.opacity(compact ? 0.3 : 0.35),
                            lineWidth: isSelected ? (compact ? 2 : 2.5) : (compact ? 0.5 : 1)
                        )
                )
                .scaleEffect(isPressed ? (compact ? 0.95 : 0.94) : 1)
                .animation(.easeOut(duration: compact ? 0.08 : 0.12), value: isPressed)

                if showFavoriteButton, let onFavoriteToggle {
                    Button(action: onFavoriteToggle) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isFavorite ? .yellow : .secondary)
                            .padding(5)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

struct LevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                Capsule()
                    .fill(level > 0.8 ? Color.red : AppTheme.accent)
                    .frame(width: geometry.size.width * CGFloat(level))
            }
        }
        .frame(height: 10)
    }
}

struct OnScreenKeyboard: View {
    let onNote: (UInt8, UInt8, Bool) -> Void

    private let whiteNotes: [UInt8] = [60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79]
    private let blackNotes: [UInt8] = [61, 63, 66, 68, 70, 73, 75, 78]
    private let blackOffsets: [UInt8: Int] = [
        61: 1, 63: 2, 66: 4, 68: 5, 70: 6, 73: 8, 75: 9, 78: 11
    ]

    var body: some View {
        GeometryReader { geometry in
            let whiteWidth = geometry.size.width / CGFloat(whiteNotes.count)
            let blackWidth = whiteWidth * 0.62
            let blackHeight = geometry.size.height * 0.62

            ZStack(alignment: .topLeading) {
                HStack(spacing: 1) {
                    ForEach(whiteNotes, id: \.self) { note in
                        PianoKeyView(
                            label: MIDIUtilities.noteName(for: note),
                            isBlack: false,
                            width: whiteWidth - 1,
                            height: geometry.size.height
                        ) { onNote(note, 100, true) } onRelease: { onNote(note, 0, false) }
                    }
                }

                ForEach(blackNotes, id: \.self) { note in
                    PianoKeyView(label: "", isBlack: true, width: blackWidth, height: blackHeight) {
                        onNote(note, 100, true)
                    } onRelease: {
                        onNote(note, 0, false)
                    }
                    .offset(x: whiteWidth * CGFloat(blackOffsets[note] ?? 0) - blackWidth / 2)
                }
            }
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color(.separator), lineWidth: 0.5))
    }
}

private struct PianoKeyView: View {
    let label: String
    let isBlack: Bool
    let width: CGFloat
    let height: CGFloat
    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressed = false

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: isBlack ? 4 : 6, style: .continuous)
                .fill(isBlack ? Color.black.opacity(isPressed ? 0.7 : 1) : Color.white.opacity(isPressed ? 0.85 : 1))
                .shadow(color: .black.opacity(isBlack ? 0.3 : 0.08), radius: 1, y: 1)

            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)
            }
        }
        .frame(width: width, height: height)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed { isPressed = true; onPress() }
                }
                .onEnded { _ in
                    if isPressed { isPressed = false; onRelease() }
                }
        )
    }
}
