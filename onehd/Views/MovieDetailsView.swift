import SwiftUI

struct MovieDetailsView: View {
    let movieUrl: String
    @State private var viewModel = MovieDetailsViewModel()
    @State private var isFavorite = false

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 100)
            } else if let movie = viewModel.movieDetails {
                VStack(alignment: .leading, spacing: 16) {
                    // Poster
                    AsyncImage(url: URL(string: movie.thumbnail)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .cornerRadius(12)
                        default:
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 300)
                                .cornerRadius(12)
                        }
                    }

                    // Title & Quality
                    VStack(alignment: .leading, spacing: 8) {
                        Text(movie.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        if !movie.quality.isEmpty {
                            Text(movie.quality)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .cornerRadius(4)
                        }

                        // Description
                        if !movie.description.isEmpty {
                            Text(movie.description)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                        }

                        // Details grid
                        detailsSection(movie: movie)
                    }
                    .padding(.horizontal)

                    // Watch button (for movies)
                    if movie.seasonsList == nil || movie.seasonsList!.isEmpty {
                        NavigationLink(value: Route.watchMovie(url: movie.watchMovieLinkWithEpisodeId)) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Watch Now")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    // Favorite button
                    Button {
                        viewModel.toggleFavorite()
                        isFavorite = viewModel.isFavorite()
                    } label: {
                        HStack {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                            Text(isFavorite ? "Remove from Favorites" : "Add to Favorites")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFavorite ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    // Seasons & Episodes (for TV shows)
                    if let seasons = movie.seasonsList, !seasons.isEmpty {
                        seasonsSection(seasons: seasons)
                    }

                    // You May Also Like
                    if !viewModel.youMayAlsoLike.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You May Also Like")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    ForEach(viewModel.youMayAlsoLike) { movie in
                                        NavigationLink(value: Route.movieDetails(url: movie.link)) {
                                            MovieCardView(movie: movie)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
        }
        .background(Color.black)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchDetails(url: movieUrl)
            isFavorite = viewModel.isFavorite()
            await viewModel.fetchYouMayAlsoLike(url: movieUrl)
        }
    }

    @ViewBuilder
    private func detailsSection(movie: MoviesDetailsDataModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !movie.cast.isEmpty { detailRow("Cast", movie.cast) }
            if !movie.genre.isEmpty { detailRow("Genre", movie.genre) }
            if !movie.duration.isEmpty { detailRow("Duration", "\(movie.duration) min") }
            if !movie.country.isEmpty { detailRow("Country", movie.country) }
            if !movie.imdb.isEmpty { detailRow("IMDB", movie.imdb) }
            if !movie.release.isEmpty { detailRow("Release", movie.release) }
            if !movie.production.isEmpty { detailRow("Production", movie.production) }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private func seasonsSection(seasons: [MovieSeasonDataModel]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Seasons")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(seasons) { season in
                        Button {
                            viewModel.selectSeason(season)
                        } label: {
                            Text(season.seasonNumber)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(viewModel.selectedSeason?.seasonId == season.seasonId ? Color.red : Color.gray.opacity(0.5))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Episodes
            if !viewModel.selectedEpisodes.isEmpty {
                Text("Episodes")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.selectedEpisodes) { episode in
                            NavigationLink(value: Route.watchMovie(url: episode.link)) {
                                VStack(spacing: 4) {
                                    Text(episode.episodeNumber)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    if !episode.episodeName.isEmpty {
                                        Text(episode.episodeName)
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.5))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}
