import SwiftUI

struct FavoriteView: View {
    @State private var viewModel = FavoriteViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        Group {
            if viewModel.favorites.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "heart.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("No favorites yet")
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.favorites) { movie in
                            NavigationLink(value: Route.movieDetails(url: movie.linkToDetails)) {
                                VStack(alignment: .leading, spacing: 4) {
                                    AsyncImage(url: URL(string: movie.thumbnail)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(height: 160)
                                                .clipped()
                                                .cornerRadius(8)
                                        default:
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(height: 160)
                                        }
                                    }
                                    Text(movie.name)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .lineLimit(2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color.black)
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchFavorites()
        }
    }
}
