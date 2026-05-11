import SwiftUI

struct AllTvShowsView: View {
    @State private var viewModel = AllTvShowsViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.tvShows) { movie in
                    NavigationLink(value: Route.movieDetails(url: movie.link)) {
                        MovieCardView(movie: movie, width: .infinity, height: 160)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if movie == viewModel.tvShows.last && viewModel.canLoadMore {
                            Task { await viewModel.fetchTvShows() }
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
        .navigationTitle("All TV Shows")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchTvShows()
        }
    }
}
