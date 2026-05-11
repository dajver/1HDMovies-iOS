import SwiftUI

struct MostPopularCarouselView: View {
    let movies: [MostPopularMoviesDataModel]
    let onTap: (MostPopularMoviesDataModel) -> Void
    @State private var currentIndex = 0

    var body: some View {
        if !movies.isEmpty {
            VStack(spacing: 8) {
                TabView(selection: $currentIndex) {
                    ForEach(Array(movies.enumerated()), id: \.element.id) { index, movie in
                        ZStack(alignment: .bottomLeading) {
                            AsyncImage(url: URL(string: movie.thumbnail)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 220)
                                        .clipped()
                                default:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(height: 220)
                                        .overlay { ProgressView() }
                                }
                            }

                            LinearGradient(
                                gradient: Gradient(colors: [.clear, .black.opacity(0.8)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(movie.name)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                Text(movie.quality)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                if !movie.description.isEmpty {
                                    Text(movie.description)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(2)
                                }
                            }
                            .padding()
                        }
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .tag(index)
                        .onTapGesture { onTap(movie) }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 220)

                // Page indicators below the carousel
                HStack(spacing: 6) {
                    ForEach(0..<movies.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.white : Color.gray.opacity(0.5))
                            .frame(width: 7, height: 7)
                    }
                }
            }
        }
    }
}
