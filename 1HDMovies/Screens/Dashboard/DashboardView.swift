import SwiftUI

struct DashboardView: View {
    var viewModel: DashboardViewModel
    @State private var navigationPath = NavigationPath()
    @State private var showAccount = false
    @State private var continueWatching = ContinueWatchingViewModel()
    var notificationService = NewEpisodeService.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegular: Bool { horizontalSizeClass == .regular }

    // Same content as the top slider, shown as poster cards that open details.
    // Stored (not computed) so the instances/identities stay stable across renders.
    @State private var newReleases: [MoviesDataModel] = []

    private func rebuildNewReleases() {
        newReleases = viewModel.mostPopular.map {
            MoviesDataModel(name: $0.name, thumbnail: $0.thumbnail, link: $0.link,
                            type: .movie, quality: $0.quality, other: "")
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.isMostPopularLoading {
                        ProgressView()
                            .frame(height: isRegular ? 380 : 220)
                    } else {
                        MostPopularCarouselView(movies: viewModel.mostPopular) { movie in
                            navigationPath.append(Route.watchMovie(url: movie.link))
                        }
                    }

                    continueWatchingRow

                    movieRow(title: "New Releases", movies: newReleases)

                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        let topMovies = viewModel.dashboardMovies.filter { $0.type == .movie }
                        let topTvShows = viewModel.dashboardMovies.filter { $0.type == .tvShow }

                        movieRow(title: "Top Movies", movies: topMovies)
                        movieRow(title: "Top TV Shows", movies: topTvShows)
                    }

                    movieRow(title: "Movies", movies: viewModel.movies, seeAllRoute: .allMovies)
                    movieRow(title: "TV Shows", movies: viewModel.tvShows, seeAllRoute: .allTvShows)
                    movieRow(title: "Action", movies: viewModel.actionMovies, seeAllRoute: .tag(GenresEnum.action.ref))
                    movieRow(title: "Comedy", movies: viewModel.comedyMovies, seeAllRoute: .tag(GenresEnum.comedy.ref))
                    movieRow(title: "Drama", movies: viewModel.dramaMovies, seeAllRoute: .tag(GenresEnum.drama.ref))
                    movieRow(title: "Fantasy", movies: viewModel.fantasyMovies, seeAllRoute: .tag(GenresEnum.fantasy.ref))
                    movieRow(title: "Horror", movies: viewModel.horrorMovies, seeAllRoute: .tag(GenresEnum.horror.ref))
                    movieRow(title: "Mystery", movies: viewModel.mysteryMovies, seeAllRoute: .tag(GenresEnum.mystery.ref))
                    movieRow(title: "Animation", movies: viewModel.animationMovies, seeAllRoute: .tag(GenresEnum.animation.ref))
                    movieRow(title: "Top IMDB", movies: viewModel.topIMDBMovies, seeAllRoute: .tag(GenresEnum.topIMDB.ref))
                }
                .padding(.vertical)
            }
            .background(Color.black)
            .navigationTitle("1HD Movies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        NavigationLink(value: Route.search) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white)
                        }
                        NavigationLink(value: Route.notifications) {
                            Image(systemName: "bell.fill")
                                .foregroundColor(.white)
                                .overlay(alignment: .topTrailing) {
                                    if notificationService.unreadCount > 0 {
                                        Text("\(min(notificationService.unreadCount, 99))")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.red)
                                            .clipShape(Capsule())
                                            .offset(x: 8, y: -8)
                                    }
                                }
                        }
                        NavigationLink(value: Route.favorites) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                        }
                        Button {
                            showAccount = true
                        } label: {
                            Image(systemName: "person.circle")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .movieDetails(let url):
                    MovieDetailsView(movieUrl: url)
                case .watchMovie(let url):
                    WatchMovieView(movieUrl: url)
                case .watchEpisode(let episodes, let currentIndex):
                    WatchMovieView(movieUrl: episodes[currentIndex].link, episodes: episodes, currentEpisodeIndex: currentIndex)
                case .allMovies:
                    AllMoviesView()
                case .allTvShows:
                    AllTvShowsView()
                case .tag(let tag):
                    GenreMoviesView(genre: tag)
                case .search:
                    SearchView()
                case .favorites:
                    FavoriteView()
                case .watched:
                    WatchedView()
                case .notifications:
                    NotificationsView()
                case .filter:
                    FilterView()
                }
            }
            .sheet(isPresented: $showAccount) {
                AccountView()
            }
            .onAppear {
                notificationService.refresh()
                continueWatching.refresh()
                rebuildNewReleases()
            }
            .onChange(of: viewModel.mostPopular.count) { _, _ in
                rebuildNewReleases()
            }
        }
    }

    @ViewBuilder
    private var continueWatchingRow: some View {
        if !continueWatching.items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Continue Watching")
                    .font(isRegular ? .title3 : .headline)
                    .foregroundColor(.white)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: isRegular ? 16 : 12) {
                        ForEach(continueWatching.items) { item in
                            ContinueWatchingCard(item: item,
                                                 width: isRegular ? 180 : 140,
                                                 height: isRegular ? 260 : 200)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    @ViewBuilder
    private func movieRow(title: String, movies: [MoviesDataModel], seeAllRoute: Route? = nil) -> some View {
        if !movies.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(isRegular ? .title3 : .headline)
                        .foregroundColor(.white)
                    Spacer()
                    if let route = seeAllRoute {
                        NavigationLink(value: route) {
                            Text("See All")
                                .font(isRegular ? .body : .caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: isRegular ? 16 : 12) {
                        ForEach(movies, id: \.link) { movie in
                            FocusableMovieCard(movie: movie,
                                               width: isRegular ? 180 : 140,
                                               height: isRegular ? 260 : 200)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

enum Route: Hashable {
    case movieDetails(url: String)
    case watchMovie(url: String)
    case watchEpisode(episodes: [MovieEpisodesDataModel], currentIndex: Int)
    case allMovies
    case allTvShows
    case tag(TagRef)
    case search
    case favorites
    case watched
    case notifications
    case filter
}
