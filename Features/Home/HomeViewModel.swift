// MARK: - HomeViewModel.swift
// YTPlayer — Features/Home/HomeViewModel.swift
// Swift 5.7, iOS 16.0

import Foundation
import Combine
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {

    enum ViewState: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case error(String)
    }

    @Published var state: ViewState = .idle
    @Published var videos: [VideoItem] = []
    @Published var errorMessage: String?
    @Published var isUsingFallbackData: Bool = false
    @Published var isPersonalizedFeed: Bool = false
    @Published var recommendationSummary: String = ""

    var isLoading: Bool {
        state == .loading
    }

    private let apiService: YouTubeAPIService
    private var activeLoadTask: Task<Void, Never>?
    private var lastHabitSignature: String = ""

    init(apiService: YouTubeAPIService = .shared) {
        self.apiService = apiService
    }

    /// Computes a lightweight signature of the user's current watch history, favorites,
    /// and recent searches so Home automatically updates when habits evolve.
    private func computeHabitSignature(repo: LibraryRepository?) -> String {
        let histIDs = (repo?.fetchHistory().prefix(6).map { $0.id } ?? []).joined(separator: ",")
        let favIDs = (repo?.fetchFavorites().prefix(4).map { $0.id } ?? []).joined(separator: ",")
        let searches = SearchHistoryStore.shared.entries.prefix(3).map { $0.query.lowercased() }.joined(separator: ",")
        return "\(histIDs)|\(favIDs)|\(searches)"
    }

    /// Automatically loads the Home feed on app entry (immune to SwiftUI `.task` view-remount
    /// cancellations) and refreshes whenever viewing habits have changed.
    func ensureFeedLoaded(repo: LibraryRepository?, forceRefresh: Bool = false) {
        let currentSig = computeHabitSignature(repo: repo)
        let shouldReload = forceRefresh
            || videos.isEmpty
            || isUsingFallbackData
            || (currentSig != lastHabitSignature && state != .loading)

        guard shouldReload else { return }
        activeLoadTask?.cancel()
        activeLoadTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.performFeedLoad(repo: repo, forceRefresh: forceRefresh)
        }
    }

    /// Kept compatible with pull-to-refresh (`await vm.loadTrending(repo: ..., forceRefresh: true)`).
    func loadTrending(repo: LibraryRepository? = nil, forceRefresh: Bool = false) async {
        activeLoadTask?.cancel()
        let task: Task<Void, Never> = Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.performFeedLoad(repo: repo, forceRefresh: forceRefresh)
        }
        activeLoadTask = task
        await task.value
    }

    func refresh(repo: LibraryRepository? = nil) {
        ensureFeedLoaded(repo: repo, forceRefresh: true)
    }

    // MARK: - Core Habit-Based Recommendation & Auto-Retry Loader

    private func performFeedLoad(repo: LibraryRepository?, forceRefresh: Bool) async {
        if forceRefresh {
            apiService.clearCache()
        }
        if videos.isEmpty || isUsingFallbackData {
            state = .loading
        }
        errorMessage = nil

        let history = repo?.fetchHistory() ?? []
        let favorites = repo?.fetchFavorites() ?? []
        let recentSearches = SearchHistoryStore.shared.entries
        let seeds = HabitRecommendationBuilder.buildRecommendationQueries(
            history: history,
            favorites: favorites,
            recentSearches: recentSearches,
            maxSeeds: 2
        )

        // Retry once automatically on cold start if iOS network interface is still waking up
        for attempt in 0..<2 {
            do {
                if !seeds.isEmpty {
                    let combined = try await fetchPersonalizedFeed(
                        seeds: seeds,
                        watchedHistory: history
                    )
                    guard !Task.isCancelled else { return }
                    videos = combined
                    isPersonalizedFeed = true
                    recommendationSummary = seeds.joined(separator: " • ")
                } else {
                    let fetched = try await apiService.fetchTrending(regionCode: "VN")
                    guard !Task.isCancelled else { return }
                    videos = fetched.items
                    isPersonalizedFeed = false
                    recommendationSummary = ""
                }

                isUsingFallbackData = false
                errorMessage = nil
                lastHabitSignature = computeHabitSignature(repo: repo)
                state = videos.isEmpty ? .empty : .loaded
                return
            } catch is CancellationError {
                // Never treat a cancelled task as an API failure or lock into Demo fallback
                return
            } catch {
                if attempt == 0 {
                    try? await Task.sleep(nanoseconds: 650_000_000)
                    guard !Task.isCancelled else { return }
                    continue
                }
                let message = error.localizedDescription
                errorMessage = message
                if videos.isEmpty {
                    isUsingFallbackData = true
                    isPersonalizedFeed = false
                    videos = VideoItem.mockItems
                }
                state = videos.isEmpty ? .error(message) : .loaded
            }
        }
    }

    private func fetchPersonalizedFeed(
        seeds: [String],
        watchedHistory: [VideoItem]
    ) async throws -> [VideoItem] {
        let watchedIDs = Set(watchedHistory.prefix(10).map { $0.id })
        var freshItems: [VideoItem] = []
        var rewatchedCandidates: [VideoItem] = []
        var seenIDs = Set<String>()

        func appendUnique(_ list: [VideoItem], prioritizeUnwatched: Bool) {
            for item in list where !seenIDs.contains(item.id) {
                seenIDs.insert(item.id)
                if prioritizeUnwatched && watchedIDs.contains(item.id) {
                    rewatchedCandidates.append(item)
                } else {
                    freshItems.append(item)
                }
            }
        }

        // 1. Fetch recommendations from top viewing/search habits
        for seed in seeds {
            if let res = try? await apiService.searchVideos(query: seed) {
                appendUnique(res.items, prioritizeUnwatched: true)
            }
        }

        // 2. Blend Vietnam Trending videos for fresh discovery (costs only 1 quota unit)
        if let trending = try? await apiService.fetchTrending(regionCode: "VN") {
            appendUnique(trending.items, prioritizeUnwatched: true)
        }

        let merged = freshItems + rewatchedCandidates
        if merged.isEmpty {
            // Surface real API error if both habit search and trending failed
            let fallbackTrending = try await apiService.fetchTrending(regionCode: "VN")
            return fallbackTrending.items
        }
        return merged
    }
}
