import SwiftUI

struct FilterView: View {
    @State private var viewModel = FilterViewModel()
    @State private var showFilterSheet = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        let count = horizontalSizeClass == .regular ? 6 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 12), count: count)
    }

    private var cardHeight: CGFloat { horizontalSizeClass == .regular ? 220 : 160 }

    var body: some View {
        VStack(spacing: 0) {
            // Active filters summary
            activeFiltersBar

            if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.results.isEmpty && viewModel.hasSearched {
                Spacer()
                Text("No results found")
                    .foregroundColor(.gray)
                Spacer()
            } else if viewModel.results.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Use filters to find movies")
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.results) { movie in
                            FocusableMovieCard(movie: movie, width: .infinity, height: cardHeight)
                                .frame(maxWidth: .infinity)
                                .onAppear {
                                    if movie == viewModel.results.last && viewModel.canLoadMore {
                                        Task { await viewModel.loadMore() }
                                    }
                                }
                        }
                    }
                    .padding()

                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                    }
                }
            }
        }
        .background(Color.black)
        .navigationTitle("Filter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            FilterSheetView(filters: $viewModel.filters) {
                showFilterSheet = false
                Task { await viewModel.applyFilters() }
            }
        }
        .task {
            if !viewModel.hasSearched {
                viewModel.filters.type = [.movie, .tvSeries]
                await viewModel.applyFilters()
            }
        }
    }

    private var activeFiltersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(viewModel.filters.type), id: \.self) { type in
                    filterTag(type.displayName) {
                        viewModel.filters.type.remove(type)
                        Task { await viewModel.applyFilters() }
                    }
                }
                if !viewModel.filters.genre.isEmpty && viewModel.filters.genre != "All" {
                    filterTag(viewModel.filters.genre) {
                        viewModel.filters.genre = ""
                        Task { await viewModel.applyFilters() }
                    }
                }
                if !viewModel.filters.country.isEmpty {
                    filterTag(viewModel.filters.country) {
                        viewModel.filters.country = ""
                        Task { await viewModel.applyFilters() }
                    }
                }
                if !viewModel.filters.year.isEmpty {
                    filterTag(viewModel.filters.year) {
                        viewModel.filters.year = ""
                        Task { await viewModel.applyFilters() }
                    }
                }
                if viewModel.filters.sort != .defaultSort {
                    filterTag(viewModel.filters.sort.displayName) {
                        viewModel.filters.sort = .defaultSort
                        Task { await viewModel.applyFilters() }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func filterTag(_ text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.8))
        .cornerRadius(16)
    }
}

// MARK: - Filter Sheet

struct FilterSheetView: View {
    @Binding var filters: FilterOptions
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Type
                Section("Type") {
                    ForEach(FilterType.allCases, id: \.self) { type in
                        Button {
                            if filters.type.contains(type) {
                                filters.type.remove(type)
                            } else {
                                filters.type.insert(type)
                            }
                        } label: {
                            HStack {
                                Text(type.displayName)
                                    .foregroundColor(.white)
                                Spacer()
                                if filters.type.contains(type) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }

                // Genre
                Section("Genre") {
                    Picker("Genre", selection: $filters.genre) {
                        Text("All").tag("")
                        ForEach(FilterData.genres.filter { $0 != "All" }, id: \.self) { genre in
                            Text(genre).tag(genre)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Country
                Section("Country") {
                    Picker("Country", selection: $filters.country) {
                        Text("All").tag("")
                        ForEach(FilterData.countries, id: \.self) { country in
                            Text(country).tag(country)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Year
                Section("Year") {
                    Picker("Year", selection: $filters.year) {
                        Text("All").tag("")
                        ForEach(FilterData.years.filter { !$0.isEmpty }, id: \.self) { year in
                            Text(year).tag(year)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Sort
                Section("Sort By") {
                    Picker("Sort", selection: $filters.sort) {
                        ForEach(FilterSort.allCases, id: \.self) { sort in
                            Text(sort.displayName).tag(sort)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") {
                        filters = FilterOptions()
                    }
                    .foregroundColor(.red)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        onApply()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}
