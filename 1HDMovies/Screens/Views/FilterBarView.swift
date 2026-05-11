import SwiftUI

struct FilterBarView: View {
    @Binding var filters: FilterOptions
    let onChanged: () -> Void
    @State private var showGenrePicker = false
    @State private var showCountryPicker = false
    @State private var showYearPicker = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Genre
                Menu {
                    Button("All") {
                        filters.genre = ""
                        onChanged()
                    }
                    ForEach(FilterData.genres.filter { $0 != "All" }, id: \.self) { genre in
                        Button {
                            filters.genre = genre
                            onChanged()
                        } label: {
                            HStack {
                                Text(genre)
                                if filters.genre == genre {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    chipLabel("Genre", value: filters.genre)
                }

                // Country
                Menu {
                    Button("All") {
                        filters.country = ""
                        onChanged()
                    }
                    ForEach(FilterData.countries, id: \.self) { country in
                        Button {
                            filters.country = country
                            onChanged()
                        } label: {
                            HStack {
                                Text(country)
                                if filters.country == country {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    chipLabel("Country", value: filters.country)
                }

                // Year
                Menu {
                    Button("All") {
                        filters.year = ""
                        onChanged()
                    }
                    ForEach(FilterData.years.filter { !$0.isEmpty }, id: \.self) { year in
                        Button {
                            filters.year = year
                            onChanged()
                        } label: {
                            HStack {
                                Text(year)
                                if filters.year == year {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    chipLabel("Year", value: filters.year)
                }

                // Sort
                Menu {
                    ForEach(FilterSort.allCases, id: \.self) { sort in
                        Button {
                            filters.sort = sort
                            onChanged()
                        } label: {
                            HStack {
                                Text(sort.displayName)
                                if filters.sort == sort {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    chipLabel("Sort", value: filters.sort == .defaultSort ? "" : filters.sort.displayName)
                }

                // Reset
                if !filters.genre.isEmpty || !filters.country.isEmpty || !filters.year.isEmpty || filters.sort != .defaultSort {
                    Button {
                        filters.genre = ""
                        filters.country = ""
                        filters.year = ""
                        filters.sort = .defaultSort
                        onChanged()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func chipLabel(_ title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(value.isEmpty ? title : value)
                .font(.caption)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundColor(value.isEmpty ? .gray : .white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(value.isEmpty ? Color.gray.opacity(0.2) : Color.red.opacity(0.8))
        .cornerRadius(20)
    }
}
