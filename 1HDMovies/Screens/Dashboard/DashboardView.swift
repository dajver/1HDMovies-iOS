import SwiftUI

struct DashboardView: View {
    var viewModel: DashboardViewModel
    @State private var navigationPath = NavigationPath()
    @State private var showAccount = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegular: Bool { horizontalSizeClass == .regular }

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
                    movieRow(title: "Action", movies: viewModel.actionMovies, seeAllRoute: .genre(.action))
                    movieRow(title: "Comedy", movies: viewModel.comedyMovies, seeAllRoute: .genre(.comedy))
                    movieRow(title: "Drama", movies: viewModel.dramaMovies, seeAllRoute: .genre(.drama))
                    movieRow(title: "Fantasy", movies: viewModel.fantasyMovies, seeAllRoute: .genre(.fantasy))
                    movieRow(title: "Horror", movies: viewModel.horrorMovies, seeAllRoute: .genre(.horror))
                    movieRow(title: "Mystery", movies: viewModel.mysteryMovies, seeAllRoute: .genre(.mystery))
                    movieRow(title: "Top IMDB", movies: viewModel.topIMDBMovies, seeAllRoute: .genre(.topIMDB))
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
                case .allMovies:
                    AllMoviesView()
                case .allTvShows:
                    AllTvShowsView()
                case .genre(let genre):
                    GenreMoviesView(genre: genre)
                case .search:
                    SearchView()
                case .favorites:
                    FavoriteView()
                case .filter:
                    FilterView()
                }
            }
            .sheet(isPresented: $showAccount) {
                AccountView()
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
                        ForEach(movies) { movie in
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
    case allMovies
    case allTvShows
    case genre(GenresEnum)
    case search
    case favorites
    case filter
}
