// MARK: - LibraryViewModel.swift
// YTPlayer — Features/Library/LibraryViewModel.swift
// Swift 5.7, iOS 16.0

import Foundation
import SwiftUI
import Combine

enum LibraryTab: Hashable {
    case favorites
    case history
}

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var selectedTab: LibraryTab = .favorites
    @Published var favoriteItems: [VideoItem] = []
    @Published var historyItems: [VideoItem] = []

    init() {}

    func loadData(repo: LibraryRepository) {
        self.favoriteItems = repo.fetchFavorites()
        self.historyItems = repo.fetchHistory()
    }

    func deleteFavorites(at offsets: IndexSet, repo: LibraryRepository) {
        for index in offsets {
            let item = favoriteItems[index]
            try? repo.removeFavorite(videoId: item.id)
        }
        favoriteItems.remove(atOffsets: offsets)
    }

    func deleteHistory(at offsets: IndexSet, repo: LibraryRepository) {
        for index in offsets {
            let item = historyItems[index]
            try? repo.removeHistoryItem(videoId: item.id)
        }
        historyItems.remove(atOffsets: offsets)
    }

    func clearHistory(repo: LibraryRepository) {
        try? repo.clearHistory()
        historyItems = []
    }
}
