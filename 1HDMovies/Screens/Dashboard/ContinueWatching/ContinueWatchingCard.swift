import SwiftUI

struct ContinueWatchingCard: View {
    let item: ContinueWatchingItem
    let width: CGFloat
    let height: CGFloat

    @State private var isHovered = false
    @Environment(\.isFocused) private var isFocused

    private var isHighlighted: Bool { isFocused || isHovered }

    var body: some View {
        NavigationLink(value: Route.watchEpisode(episodes: item.episodes, currentIndex: item.nextIndex)) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    AsyncImage(url: URL(string: item.thumbnail)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Rectangle().fill(Color.gray.opacity(0.3))
                        }
                    }
                    .frame(width: width, height: height)
                    .clipped()
                    .cornerRadius(8)

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(radius: 4)
                }
                .overlay(alignment: .bottomLeading) {
                    if item.remaining > 0 {
                        Text("\(item.remaining) left")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                            .padding(6)
                    }
                }

                Text(item.showName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(nextLabel)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(width: width)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHighlighted ? Color.white : Color.clear, lineWidth: 3)
            )
            .brightness(isHighlighted ? 0.15 : 0)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isHighlighted)
        .onHover { isHovered = $0 }
    }

    private var nextLabel: String {
        let parts = [item.nextEpisode.episodeNumber, item.nextEpisode.episodeName]
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "Up next" : "Next: " + parts.joined(separator: " · ")
    }
}
