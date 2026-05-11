import SwiftUI

struct AllTvShowsView: View {
    @State private var viewModel = AllTvShowsViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 6 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private var cardHeight: CGFloat { horizontalSizeClass == .regular ? 220 : 160 }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.tvShows) { movie in
                    FocusableMovieCard(movie: movie, width: .infinity, height: cardHeight)
                        .frame(maxWidth: .infinity)
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
