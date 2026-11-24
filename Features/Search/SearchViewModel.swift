// MARK: - SearchViewModel.swift
// YTPlayer — Features/Search/SearchViewModel.swift
// Swift 5.7, iOS 16.0

import Foundation
import Combine
import SwiftUI

@MainActor
final class SearchViewModel: ObservableObject {

    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case error(String)
    }

    @Published var query: String = ""
    @Published var results: [VideoItem] = []
    @Published var state: ViewState = .idle
    @Published var nextPageToken: String?
    @Published var isLoadingMore: Bool = false
    @Published var apiWarningMessage: String?
    @Published var isShowingFallback: Bool = false

    let quickSuggestions = ["Sơn Tùng M-TP", "Đen Vâu", "Lofi Girl", "Ed Sheeran", "Rick Astley", "Despacito"]

    private let apiService: YouTubeAPIService
    private var searchTask: Task<Void, Never>?

    init(initialQuery: String = "", apiService: YouTubeAPIService = .shared) {
        self.apiService = apiService
        self.query = initialQuery
        if !initialQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchImmediate()
        }
    }

    /// Triggers a debounced search (400 ms). Cancels any in-flight search task first.
    func search() {
        searchTask?.cancel()

        let currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentQuery.isEmpty else {
            clear()
            return
        }

        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 400_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await performSearch(query: currentQuery, pageToken: nil, append: false)
        }
    }

    /// Runs search immediately (e.g. when tapping Search button or quick tag).
    func searchImmediate() {
        searchTask?.cancel()
        let currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentQuery.isEmpty else {
            clear()
            return
        }
        searchTask = Task {
            await performSearch(query: currentQuery, pageToken: nil, append: false)
        }
    }

    func selectSuggestion(_ tag: String) {
        query = tag
        searchImmediate()
    }

    /// Loads the next page of results if a page token is available.
    func loadMore() {
        guard let token = nextPageToken, !isLoadingMore, state == .loaded else { return }
        let currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentQuery.isEmpty else { return }

        isLoadingMore = true
        Task {
            await performSearch(query: currentQuery, pageToken: token, append: true)
            isLoadingMore = false
        }
    }

    /// Resets the search state.
    func clear() {
        searchTask?.cancel()
        searchTask = nil
        results = []
        nextPageToken = nil
        apiWarningMessage = nil
        isShowingFallback = false
        state = .idle
    }

    // MARK: - Private Methods

    @MainActor
    private func performSearch(query: String, pageToken: String?, append: Bool) async {
        if !append {
            state = .loading
            apiWarningMessage = nil
            isShowingFallback = false
        }

        do {
            let searchResult = try await apiService.searchVideos(query: query, pageToken: pageToken)
            guard !Task.isCancelled else { return }

            if append {
                let existingIDs = Set(results.map { $0.id })
                let uniqueNew = searchResult.items.filter { !existingIDs.contains($0.id) }
                results.append(contentsOf: uniqueNew)
            } else {
                results = searchResult.items
            }
            nextPageToken = searchResult.nextPageToken
            state = results.isEmpty ? .empty : .loaded
        } catch {
            guard !Task.isCancelled else { return }
            let errText = error.localizedDescription
            apiWarningMessage = errText

            let filtered = VideoItem.mockItems.filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.channelName.localizedCaseInsensitiveContains(query) ||
                $0.description.localizedCaseInsensitiveContains(query)
            }
            if !filtered.isEmpty {
                results = filtered
                isShowingFallback = true
                nextPageToken = nil
                state = .loaded
            } else {
                results = []
                state = .error(errText)
            }
        }
    }
}
