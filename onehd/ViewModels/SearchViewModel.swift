import Foundation

@Observable
class SearchViewModel {
    var searchResults: [MoviesDataModel] = []
    var isLoading = false
    var searchText = ""

    func search() async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            await MainActor.run { searchResults = [] }
            return
        }
        await MainActor.run { isLoading = true }
        do {
            let result = try await SearchRepository.shared.fetchSearchResult(keyword: searchText)
            await MainActor.run {
                searchResults = result
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}
