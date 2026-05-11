import SwiftUI

struct GenreMoviesView: View {
    let genre: GenresEnum
    @State private var viewModel: GenreMoviesViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(genre: GenresEnum) {
        self.genre = genre
        self._viewModel = State(initialValue: GenreMoviesViewModel(genre: genre))
    }

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 6 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private var cardHeight: CGFloat { horizontalSizeClass == .regular ? 220 : 160 }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.movies) { movie in
                    FocusableMovieCard(movie: movie, width: .infinity, height: cardHeight)
                        .frame(maxWidth: .infinity)
                    .onAppear {
                        if movie == viewModel.movies.last && viewModel.canLoadMore {
                            Task { await viewModel.fetchMovies() }
                        }
                    }
                }
            }
            .padding()

            if viewModel.isLoading {
                ProgressView()
                    .padding()
            }
        }
        .background(Color.black)
        .navigationTitle(genre.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchMovies()
        }
    }
}
