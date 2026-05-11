import SwiftUI

struct AllTvShowsView: View {
    @State private var viewModel = AllTvShowsViewModel()
    @State private var filterVM = FilterViewModel()
    @State private var isFiltering = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 6 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private var cardHeight: CGFloat { horizontalSizeClass == .regular ? 220 : 160 }

    private var displayedShows: [MoviesDataModel] {
        isFiltering ? filterVM.results : viewModel.tvShows
    }

    private var showLoading: Bool {
        isFiltering ? filterVM.isLoading : viewModel.isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            FilterBarView(filters: $filterVM.filters) {
                filterVM.filters.type = [.tvSeries]
                isFiltering = hasActiveFilters
                if isFiltering {
                    Task { await filterVM.applyFilters() }
                }
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(displayedShows) { movie in
                        FocusableMovieCard(movie: movie, width: .infinity, height: cardHeight)
                            .frame(maxWidth: .infinity)
                            .onAppear {
                                if !isFiltering && movie == viewModel.tvShows.last && viewModel.canLoadMore {
                                    Task { await viewModel.fetchTvShows() }
                                }
                                if isFiltering && movie == filterVM.results.last && filterVM.canLoadMore {
                                    Task { await filterVM.loadMore() }
                                }
                            }
                    }
                }
                .padding()

                if showLoading {
                    ProgressView()
                        .padding()
                }

                if isFiltering && !filterVM.isLoading && filterVM.results.isEmpty && filterVM.hasSearched {
                    Text("No results found")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
        }
        .background(Color.black)
        .navigationTitle("All TV Shows")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchTvShows()
        }
    }

    private var hasActiveFilters: Bool {
        !filterVM.filters.genre.isEmpty || !filterVM.filters.country.isEmpty ||
        !filterVM.filters.year.isEmpty || filterVM.filters.sort != .defaultSort
    }
}
