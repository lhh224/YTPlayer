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
    @Published var searchHistory: [SearchHistoryEntry] = []

    private let apiService: YouTubeAPIService
    private let historyStore: SearchHistoryStore
    private var searchTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    init(
        initialQuery: String = "",
        apiService: YouTubeAPIService = .shared,
        historyStore: SearchHistoryStore = .shared
    ) {
        self.apiService = apiService
        self.historyStore = historyStore
        self.searchHistory = historyStore.entries
        self.query = initialQuery

        historyStore.$entries
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updated in
                self?.searchHistory = updated
            }
            .store(in: &cancellables)

        if !initialQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchImmediate()
        }
    }

    /// Filtered search history matching current text when idle or typing, just like YouTube.
    var matchingHistoryEntries: [SearchHistoryEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return searchHistory }
        return searchHistory.filter { $0.query.localizedCaseInsensitiveContains(trimmed) }
    }

    /// Triggers a debounced search (450 ms). Cancels any in-flight search task first.
    func search() {
        searchTask?.cancel()

        let currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentQuery.isEmpty else {
            clear()
            return
        }

        searchTask = Task {
            do {
                try await Task.sleep(nanoseconds: 450_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await performSearch(query: currentQuery, pageToken: nil, append: false, saveToHistory: false)
        }
    }

    /// Runs search immediately (e.g. pressing Search on keyboard or tapping a history item)
    /// and saves the query into persistent YouTube-style search history.
    func searchImmediate() {
        searchTask?.cancel()
        let currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentQuery.isEmpty else {
            clear()
            return
        }
        historyStore.record(query: currentQuery)
        searchTask = Task {
            await performSearch(query: currentQuery, pageToken: nil, append: false, saveToHistory: true)
        }
    }

    /// Selects a past query from search history and executes search immediately.
    func selectHistoryEntry(_ entry: SearchHistoryEntry) {
        query = entry.query
        searchImmediate()
    }

    /// Fills query box with a history term without submitting (YouTube `↖` button behavior).
    func fillQueryFromHistory(_ entry: SearchHistoryEntry) {
        searchTask?.cancel()
        query = entry.query + " "
    }

    /// Records the search query + clicked video thumbnail when user opens a search result.
    func recordOpenedResult(_ video: VideoItem) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveQuery = trimmed.isEmpty ? video.title : trimmed
        historyStore.record(query: effectiveQuery, thumbnailURL: video.thumbnailURL)
    }

    func deleteHistoryEntry(_ entry: SearchHistoryEntry) {
        historyStore.remove(query: entry.query)
    }

    func clearSearchHistory() {
        historyStore.clearAll()
    }

    /// Loads the next page of results if a page token is available.
    func loadMore() {
        guard let token = nextPageToken, !isLoadingMore, state == .loaded else { return }
        let currentQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentQuery.isEmpty else { return }

        isLoadingMore = true
        Task {
            await performSearch(query: currentQuery, pageToken: token, append: true, saveToHistory: false)
            isLoadingMore = false
        }
    }

    /// Resets the active search results back to the Search History view.
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
    private func performSearch(query: String, pageToken: String?, append: Bool, saveToHistory: Bool) async {
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
                if saveToHistory, let firstThumb = searchResult.items.first?.thumbnailURL {
                    historyStore.record(query: query, thumbnailURL: firstThumb)
                }
            }
            nextPageToken = searchResult.nextPageToken
            state = results.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            return
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
