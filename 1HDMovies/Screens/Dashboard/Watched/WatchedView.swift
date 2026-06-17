import SwiftUI

struct WatchedView: View {
    @State private var viewModel = WatchedViewModel()
    @State private var refreshId = UUID()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 6 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private var cardHeight: CGFloat { horizontalSizeClass == .regular ? 220 : 160 }

    var body: some View {
        Group {
            if viewModel.watched.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "eye.slash")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("Nothing watched yet")
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.watched) { movie in
                            FocusableFavoriteCard(movie: movie, cardHeight: cardHeight)
                                .id("\(movie.id)-\(refreshId)")
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color.black)
        .navigationTitle("Watched")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchWatched()
            refreshId = UUID()
        }
    }
}
