import SwiftUI

struct FocusableChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused
    @State private var isHovered = false

    private var isHighlighted: Bool { isFocused || isHovered }

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.red : (isHighlighted ? Color.gray.opacity(0.8) : Color.gray.opacity(0.5)))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isHighlighted ? Color.white : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isHighlighted)
        .onHover { isHovered = $0 }
        .focusable()
    }
}

struct FocusableEpisodeChip: View {
    let episodeNumber: String
    let episodeName: String
    var isWatched: Bool = false

    @Environment(\.isFocused) private var isFocused
    @State private var isHovered = false

    private var isHighlighted: Bool { isFocused || isHovered }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if isWatched {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                Text(episodeNumber)
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            if !episodeName.isEmpty {
                Text(episodeName)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
        .foregroundColor(.white)
        .opacity(isWatched && !isHighlighted ? 0.6 : 1)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHighlighted ? Color.white : (isWatched ? Color.green.opacity(0.6) : Color.clear), lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.15), value: isHighlighted)
        .onHover { isHovered = $0 }
        .focusable()
    }

    private var backgroundColor: Color {
        if isHighlighted { return Color.gray.opacity(0.8) }
        return isWatched ? Color.green.opacity(0.18) : Color.gray.opacity(0.5)
    }
}
