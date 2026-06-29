import Foundation

@Observable
class GenreMoviesViewModel {
    var movies: [MoviesDataModel] = []
    var isLoading = false
    var currentPage = 1
    var canLoadMore = true
    let genre: TagRef

    init(genre: TagRef) {
        self.genre = genre
    }

    func fetchMovies() async {
        guard !isLoading else { return }
        await MainActor.run { isLoading = true }
        do {
            let result = try await GenresRepository.shared.fetchMoviesByGenre(genreUrl: genre.url, page: currentPage)
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
