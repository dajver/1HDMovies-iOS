import SwiftUI

struct MovieRowView: View {
    let title: String
    let movies: [MoviesDataModel]
    let onMovieTap: (MoviesDataModel) -> Void
    var onSeeAllTap: (() -> Void)? = nil

    var body: some View {
        if !movies.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    if let seeAll = onSeeAllTap {
                        Button("See All") { seeAll() }
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(movies) { movie in
                            MovieCardView(movie: movie)
                                .onTapGesture { onMovieTap(movie) }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}
