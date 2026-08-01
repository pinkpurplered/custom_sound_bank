import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.35, green: 0.55, blue: 0.95)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let screenBackground = Color(.systemGroupedBackground)
}

struct InstrumentCard: View {
    let kind: InstrumentKind
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: kind.iconName)
                    .font(.title2)
                    .frame(height: 28)
                Text(kind.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 88, height: 88)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? AppTheme.accent : AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? AppTheme.accent : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct LevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))
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

    private struct Key: Identifiable {
        let note: UInt8
        let isBlack: Bool
        var id: UInt8 { note }
    }

    private let whiteNotes: [UInt8] = [60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79]
    private let blackNotes: [UInt8] = [61, 63, 66, 68, 70, 73, 75, 78]

    var body: some View {
        GeometryReader { geometry in
            let whiteKeyCount = CGFloat(whiteNotes.count)
            let whiteWidth = geometry.size.width / whiteKeyCount
            let whiteHeight = geometry.size.height
            let blackWidth = whiteWidth * 0.62
            let blackHeight = whiteHeight * 0.62

            ZStack(alignment: .topLeading) {
                HStack(spacing: 1) {
                    ForEach(whiteNotes, id: \.self) { note in
                        PianoKeyView(
                            label: MIDIUtilities.noteName(for: note),
                            isBlack: false,
                            width: whiteWidth - 1,
                            height: whiteHeight
                        ) {
                            onNote(note, 100, true)
                        } onRelease: {
                            onNote(note, 0, false)
                        }
                    }
                }

                ForEach(blackNotes, id: \.self) { note in
                    let index = whiteIndexBeforeBlack(note)
                    PianoKeyView(
                        label: "",
                        isBlack: true,
                        width: blackWidth,
                        height: blackHeight
                    ) {
                        onNote(note, 100, true)
                    } onRelease: {
                        onNote(note, 0, false)
                    }
                    .offset(x: whiteWidth * CGFloat(index) - blackWidth / 2, y: 0)
                }
            }
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    private func whiteIndexBeforeBlack(_ note: UInt8) -> Int {
        let map: [UInt8: Int] = [
            61: 1, 63: 2, 66: 4, 68: 5, 70: 6,
            73: 8, 75: 9, 78: 11
        ]
        return map[note] ?? 0
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
                    if !isPressed {
                        isPressed = true
                        onPress()
                    }
                }
                .onEnded { _ in
                    if isPressed {
                        isPressed = false
                        onRelease()
                    }
                }
        )
    }
}
