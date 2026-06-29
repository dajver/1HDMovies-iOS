import Foundation

@Observable
class DashboardViewModel {
    var mostPopular: [MostPopularMoviesDataModel] = []
    var dashboardMovies: [MoviesDataModel] = []
    var movies: [MoviesDataModel] = []
    var tvShows: [MoviesDataModel] = []
    var actionMovies: [MoviesDataModel] = []
    var comedyMovies: [MoviesDataModel] = []
    var dramaMovies: [MoviesDataModel] = []
    var fantasyMovies: [MoviesDataModel] = []
    var horrorMovies: [MoviesDataModel] = []
    var mysteryMovies: [MoviesDataModel] = []
    var animationMovies: [MoviesDataModel] = []
    var topIMDBMovies: [MoviesDataModel] = []
    var isLoading = true
    var isMostPopularLoading = true

    func fetchAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchMostPopular() }
            group.addTask { await self.fetchDashboard() }
            group.addTask { await self.fetchMovies() }
            group.addTask { await self.fetchTvShows() }
            group.addTask { await self.fetchGenreMovies(.action) }
            group.addTask { await self.fetchGenreMovies(.comedy) }
            group.addTask { await self.fetchGenreMovies(.drama) }
            group.addTask { await self.fetchGenreMovies(.fantasy) }
            group.addTask { await self.fetchGenreMovies(.horror) }
            group.addTask { await self.fetchGenreMovies(.mystery) }
            group.addTask { await self.fetchGenreMovies(.animation) }
            group.addTask { await self.fetchGenreMovies(.topIMDB) }
        }
    }

    @MainActor
    private func fetchMostPopular() async {
        do {
            mostPopular = try await MostPopularRepository.shared.fetchMostPopular()
        } catch {}
        isMostPopularLoading = false
    }

    @MainActor
    private func fetchDashboard() async {
        do {
            dashboardMovies = try await DashboardRepository.shared.fetchDashboard()
        } catch {}
        isLoading = false
    }

    @MainActor
    private func fetchMovies() async {
        do {
            movies = try await MoviesRepository.shared.fetchMovies(page: 1)
        } catch {}
    }

    @MainActor
    private func fetchTvShows() async {
        do {
            tvShows = try await TvShowsRepository.shared.fetchTvShows(page: 1)
        } catch {}
    }

    @MainActor
    private func fetchGenreMovies(_ genre: GenresEnum) async {
        do {
            let result = try await GenresRepository.shared.fetchMoviesByGenre(genre: genre, page: 1)
            switch genre {
            case .action: actionMovies = result
            case .comedy: comedyMovies = result
            case .drama: dramaMovies = result
            case .fantasy: fantasyMovies = result
            case .horror: horrorMovies = result
            case .mystery: mysteryMovies = result
            case .animation: animationMovies = result
            case .topIMDB: topIMDBMovies = result
            }
        } catch {}
    }
}
