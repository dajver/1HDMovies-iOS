import SwiftUI

struct GenreMoviesView: View {
    let genre: GenresEnum
    @State private var viewModel: GenreMoviesViewModel

    init(genre: GenresEnum) {
        self.genre = genre
        self._viewModel = State(initialValue: GenreMoviesViewModel(genre: genre))
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.movies) { movie in
                    NavigationLink(value: Route.movieDetails(url: movie.link)) {
                        MovieCardView(movie: movie, width: .infinity, height: 160)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
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
