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

    var isLoading: Bool {
        state == .loading
    }

    private let apiService: YouTubeAPIService

    init(apiService: YouTubeAPIService = .shared) {
        self.apiService = apiService
    }

    @MainActor
    func loadTrending(forceRefresh: Bool = false) async {
        if forceRefresh {
            apiService.clearCache()
        }
        state = .loading
        errorMessage = nil

        do {
            let fetched = try await apiService.fetchTrending()
            videos = fetched.items
            isUsingFallbackData = false
            state = videos.isEmpty ? .empty : .loaded
        } catch {
            let message = error.localizedDescription
            errorMessage = message
            isUsingFallbackData = true
            videos = VideoItem.mockItems
            state = videos.isEmpty ? .error(message) : .loaded
        }
    }

    func refresh() {
        Task {
            await loadTrending(forceRefresh: true)
        }
    }
}
