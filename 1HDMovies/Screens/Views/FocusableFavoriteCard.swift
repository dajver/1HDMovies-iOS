import SwiftUI

struct FocusableFavoriteCard: View {
    let movie: MoviesDetailsDataModel
    let cardHeight: CGFloat

    @State private var isHovered = false
    @Environment(\.isFocused) private var isFocused

    private var isHighlighted: Bool { isFocused || isHovered }

    var body: some View {
        NavigationLink(value: Route.movieDetails(url: movie.linkToDetails)) {
            VStack(alignment: .leading, spacing: 4) {
                AsyncImage(url: URL(string: movie.thumbnail)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: cardHeight)
                            .clipped()
                            .cornerRadius(8)
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: cardHeight)
                    }
                }
                Text(movie.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
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
}
