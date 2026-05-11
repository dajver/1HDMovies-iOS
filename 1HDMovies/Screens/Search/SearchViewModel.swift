import Foundation

@Observable
class SearchViewModel {
    var searchResults: [MoviesDataModel] = []
    var isLoading = false
    var searchText = "" {
        didSet { debounceSearch() }
    }

    private var searchTask: Task<Void, Never>?

    private func debounceSearch() {
        searchTask?.cancel()
        let query = searchText
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            isLoading = false
            return
        }
        isLoading = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await performSearch(query: query)
        }
    }

    private func performSearch(query: String) async {
        do {
            let result = try await SearchRepository.shared.fetchSearchResult(keyword: query)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                searchResults = result
                isLoading = false
            }
        } catch {
            guard !Task.isCancelled else { return }
            await MainActor.run { isLoading = false }
        }
    }
}
