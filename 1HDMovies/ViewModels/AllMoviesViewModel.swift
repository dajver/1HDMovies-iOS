import Foundation

@Observable
class AllMoviesViewModel {
    var movies: [MoviesDataModel] = []
    var isLoading = false
    var currentPage = 1
    var canLoadMore = true

    func fetchMovies() async {
        guard !isLoading else { return }
        await MainActor.run { isLoading = true }
        do {
            let result = try await MoviesRepository.shared.fetchMovies(page: currentPage)
            await MainActor.run {
                movies.append(contentsOf: result)
                canLoadMore = !result.isEmpty
                currentPage += 1
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}
