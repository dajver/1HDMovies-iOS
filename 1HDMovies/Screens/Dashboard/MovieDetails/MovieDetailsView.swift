import SwiftUI

struct MovieDetailsView: View {
    let movieUrl: String
    @State private var viewModel = MovieDetailsViewModel()
    @State private var isFavorite = false
    @State private var isWatched = false
    @State private var showPoster = false
    @Namespace private var posterNamespace
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegular: Bool { horizontalSizeClass == .regular }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 100)
                } else if let movie = viewModel.movieDetails {
                    if isRegular {
                        iPadLayout(movie: movie)
                    } else {
                        iPhoneLayout(movie: movie)
                    }
                }
            }
        }
        .background(Color.black)
        .navigationTitle(viewModel.movieDetails?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showPoster) {
            FullScreenImageView(imageUrl: viewModel.movieDetails?.thumbnail ?? "")
                .navigationTransition(.zoom(sourceID: "poster", in: posterNamespace))
        }
        .onAppear {
            viewModel.refreshWatchedEpisodes()
        }
        .task {
            await viewModel.fetchDetails(url: movieUrl)
            if let movie = viewModel.movieDetails {
                FavoriteRepository.shared.refreshFavoriteIfNeeded(movie)
            }
            isFavorite = viewModel.isFavorite()
            isWatched = viewModel.isWatched()
            await viewModel.fetchYouMayAlsoLike(url: movieUrl)
        }
    }

    // MARK: - iPad / TV layout (side-by-side)
    @ViewBuilder
    private func iPadLayout(movie: MoviesDetailsDataModel) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 24) {
                // Left: Poster
                AsyncImage(url: URL(string: movie.thumbnail)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 280, height: 400)
                            .cornerRadius(16)
                            .contentShape(Rectangle())
                            .matchedTransitionSource(id: "poster", in: posterNamespace)
                            .onTapGesture { showPoster = true }
                    default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 280, height: 400)
                            .cornerRadius(16)
                    }
                }

                // Right: Info
                VStack(alignment: .leading, spacing: 12) {
                    Text(movie.name)
                        .font(.title)
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

                    if !movie.description.isEmpty {
                        Text(movie.description)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                    }

                    detailsSection(movie: movie)

                    HStack(spacing: 12) {
                        if movie.seasonsList == nil || movie.seasonsList!.isEmpty {
                            NavigationLink(value: Route.watchMovie(url: movie.watchMovieLinkWithEpisodeId)) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Watch Now")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.red)
                                .cornerRadius(12)
                            }
                        }

                        actionButtons
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 32)
            .padding(.top)

            // Seasons & Episodes
            if let seasons = movie.seasonsList, !seasons.isEmpty {
                seasonsSection(seasons: seasons)
            }

            // You May Also Like
            youMayAlsoLikeSection()
        }
        .padding(.vertical)
    }

    // MARK: - iPhone layout (vertical)
    @ViewBuilder
    private func iPhoneLayout(movie: MoviesDetailsDataModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Poster
            HStack {
                Spacer()
                AsyncImage(url: URL(string: movie.thumbnail)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .cornerRadius(12)
                            .contentShape(Rectangle())
                            .matchedTransitionSource(id: "poster", in: posterNamespace)
                            .onTapGesture { showPoster = true }
                    default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 140, height: 200)
                            .cornerRadius(12)
                    }
                }
                Spacer()
            }

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

                if !movie.description.isEmpty {
                    Text(movie.description)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                }

                detailsSection(movie: movie)
            }
            .padding(.horizontal)

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

            actionButtons
                .padding(.horizontal)

            if let seasons = movie.seasonsList, !seasons.isEmpty {
                seasonsSection(seasons: seasons)
            }

            youMayAlsoLikeSection()
        }
        .padding(.vertical)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.toggleFavorite()
                isFavorite = viewModel.isFavorite()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                    Text(isFavorite ? "Favorited" : "Favorite")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isFavorite ? Color.red.opacity(0.8) : Color.blue)
                .cornerRadius(10)
            }

            Button {
                viewModel.toggleWatched()
                isWatched = viewModel.isWatched()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isWatched ? "eye.fill" : "eye.slash")
                    Text(isWatched ? "Watched" : "Not Watched")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isWatched ? Color.green.opacity(0.8) : Color.gray.opacity(0.5))
                .cornerRadius(10)
            }
        }
    }

    // MARK: - Shared sections

    @ViewBuilder
    private func youMayAlsoLikeSection() -> some View {
        if !viewModel.youMayAlsoLike.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("You May Also Like")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(viewModel.youMayAlsoLike) { movie in
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

    @ViewBuilder
    private func detailsSection(movie: MoviesDetailsDataModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !movie.casts.isEmpty {
                tagRow("Cast", movie.casts)
            } else if !movie.cast.isEmpty {
                detailRow("Cast", movie.cast)
            }
            if !movie.genres.isEmpty {
                tagRow("Genre", movie.genres)
            } else if !movie.genre.isEmpty {
                detailRow("Genre", movie.genre)
            }
            if !movie.duration.isEmpty { detailRow("Duration", "\(movie.duration) min") }
            if !movie.countries.isEmpty {
                tagRow("Country", movie.countries)
            } else if !movie.country.isEmpty {
                detailRow("Country", movie.country)
            }
            if !movie.imdb.isEmpty { detailRow("IMDB", movie.imdb) }
            if !movie.years.isEmpty {
                tagRow("Year", movie.years)
            } else if !movie.release.isEmpty {
                detailRow("Release", movie.release)
            }
            if !movie.productions.isEmpty {
                tagRow("Production", movie.productions)
            } else if !movie.production.isEmpty {
                detailRow("Production", movie.production)
            }
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

    // Clickable chips (genre, cast, country, production, year); each pushes its listing.
    private func tagRow(_ label: String, _ tags: [TagRef]) -> some View {
        HStack(alignment: .top) {
            Text("\(label):")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 80, alignment: .leading)
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    NavigationLink(value: Route.tag(tag)) {
                        Text(tag.name)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.12))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func seasonsSection(seasons: [MovieSeasonDataModel]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Seasons")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(seasons) { season in
                            FocusableChip(
                                text: season.seasonNumber,
                                isSelected: viewModel.selectedSeason?.seasonId == season.seasonId,
                                action: { viewModel.selectSeason(season) }
                            )
                            .id(season.seasonId)
                        }
                    }
                    .padding(.horizontal)
                }
                .onAppear {
                    if let lastSeason = seasons.last {
                        proxy.scrollTo(lastSeason.seasonId, anchor: .trailing)
                    }
                }
            }

            if !viewModel.selectedEpisodes.isEmpty {
                Text("Episodes")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.selectedEpisodes.enumerated()), id: \.element.id) { index, episode in
                            NavigationLink(value: Route.watchEpisode(episodes: viewModel.selectedEpisodes, currentIndex: index)) {
                                FocusableEpisodeChip(
                                    episodeNumber: episode.episodeNumber,
                                    episodeName: episode.episodeName,
                                    isWatched: viewModel.watchedEpisodeLinks.contains(episode.link)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if viewModel.watchedEpisodeLinks.contains(episode.link) {
                                    Button(role: .destructive) {
                                        WatchedEpisodeRepository.shared.removeWatched(episodeLink: episode.link)
                                        viewModel.refreshWatchedEpisodes()
                                    } label: {
                                        Label("Mark as unwatched", systemImage: "eye.slash")
                                    }
                                } else {
                                    Button {
                                        WatchedEpisodeRepository.shared.markWatched(episodeLink: episode.link)
                                        viewModel.refreshWatchedEpisodes()
                                    } label: {
                                        Label("Mark as watched", systemImage: "eye")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

// Simple wrapping flow layout: lays subviews left-to-right, wrapping to a new
// line when the next subview would overflow the available width. Used for the
// genre chips on the details screen.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                totalHeight += rowHeight + lineSpacing
                widestRow = max(widestRow, x - spacing)
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        widestRow = max(widestRow, x - spacing)
        let width = maxWidth == .infinity ? widestRow : maxWidth
        return CGSize(width: max(width, 0), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
