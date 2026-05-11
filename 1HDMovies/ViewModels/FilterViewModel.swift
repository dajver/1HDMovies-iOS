import Foundation

@Observable
class FilterViewModel {
    var results: [MoviesDataModel] = []
    var isLoading = false
    var filters = FilterOptions()
    var hasSearched = false
    var currentPage = 1
    var canLoadMore = true

    func applyFilters() async {
        await MainActor.run {
            isLoading = true
            hasSearched = true
            currentPage = 1
            results = []
            canLoadMore = true
        }
        do {
            let result = try await FilterRepository.shared.fetchFiltered(options: filters, page: 1)
            await MainActor.run {
                results = result
                canLoadMore = !result.isEmpty
                currentPage = 2
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    func loadMore() async {
        guard !isLoading, canLoadMore else { return }
        await MainActor.run { isLoading = true }
        do {
            let result = try await FilterRepository.shared.fetchFiltered(options: filters, page: currentPage)
            await MainActor.run {
                results.append(contentsOf: result)
                canLoadMore = !result.isEmpty
                currentPage += 1
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    func resetFilters() {
        filters = FilterOptions()
        results = []
        hasSearched = false
        currentPage = 1
        canLoadMore = true
    }
}
