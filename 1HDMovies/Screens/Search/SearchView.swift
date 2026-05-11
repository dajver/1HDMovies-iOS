import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 6 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private var cardHeight: CGFloat { horizontalSizeClass == .regular ? 220 : 160 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search movies, TV shows...", text: $viewModel.searchText)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                        viewModel.searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            .padding()
            .frame(maxWidth: horizontalSizeClass == .regular ? 600 : .infinity)

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                Spacer()
                Text("No results found")
                    .foregroundColor(.gray)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.searchResults) { movie in
                            FocusableMovieCard(movie: movie, width: .infinity, height: cardHeight)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color.black)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
    }
}
