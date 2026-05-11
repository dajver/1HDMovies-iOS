import SwiftUI

struct FavoriteView: View {
    @State private var viewModel = FavoriteViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 6 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private var cardHeight: CGFloat { horizontalSizeClass == .regular ? 220 : 160 }

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
                            FocusableFavoriteCard(movie: movie, cardHeight: cardHeight)
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
