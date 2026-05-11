import SwiftUI

struct FocusableMovieCard: View {
    let movie: MoviesDataModel
    let width: CGFloat
    let height: CGFloat

    @State private var isHovered = false
    @Environment(\.isFocused) private var isFocused

    private var isHighlighted: Bool { isFocused || isHovered }

    init(movie: MoviesDataModel, width: CGFloat = 140, height: CGFloat = 200) {
        self.movie = movie
        self.width = width
        self.height = height
    }

    var body: some View {
        NavigationLink(value: Route.movieDetails(url: movie.link)) {
            MovieCardView(movie: movie, width: width, height: height)
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
