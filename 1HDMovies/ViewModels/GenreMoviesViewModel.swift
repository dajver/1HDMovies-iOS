import Foundation

@Observable
class GenreMoviesViewModel {
    var movies: [MoviesDataModel] = []
    var isLoading = false
    var currentPage = 1
    var canLoadMore = true
    let genre: GenresEnum

    init(genre: GenresEnum) {
        self.genre = genre
    }

    func fetchMovies() async {
        guard !isLoading else { return }
        await MainActor.run { isLoading = true }
        do {
            let result = try await GenresRepository.shared.fetchMoviesByGenre(genre: genre, page: currentPage)
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
