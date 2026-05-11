import Foundation

@Observable
class AllTvShowsViewModel {
    var tvShows: [MoviesDataModel] = []
    var isLoading = false
    var currentPage = 1
    var canLoadMore = true

    func fetchTvShows() async {
        guard !isLoading else { return }
        await MainActor.run { isLoading = true }
        do {
            let result = try await TvShowsRepository.shared.fetchTvShows(page: currentPage)
            await MainActor.run {
                tvShows.append(contentsOf: result)
                canLoadMore = !result.isEmpty
                currentPage += 1
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}
