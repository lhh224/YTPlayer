import Foundation
import SwiftUI
import Combine

// MARK: - AppRoute

enum AppRoute: Hashable {
    case videoDetail(VideoItem)
    case searchResults(String)
}

// MARK: - AppRouter

final class AppRouter: ObservableObject {

    // MARK: - Published State

    @Published var selectedTab: Int = 0
    @Published var routes: [AppRoute] = []

    /// Persistent player overlay state so playback continues seamlessly when
    /// minimizing (`∨`), switching tabs, or locking the iPhone screen.
    @Published var activePlayerVideo: VideoItem? = nil
    @Published var activePlayerQueue: [VideoItem] = []
    @Published var isPlayerMinimized: Bool = false
    @Published var playerSessionID: UUID = UUID()

    // MARK: - Navigation Actions

    func navigate(to route: AppRoute) {
        routes.append(route)
    }

    func popToRoot() {
        routes.removeAll()
    }

    func pop() {
        guard !routes.isEmpty else { return }
        routes.removeLast()
    }

    // MARK: - Persistent Player Presentation

    @MainActor
    func presentPlayer(video: VideoItem, queue: [VideoItem] = []) {
        if !queue.isEmpty {
            activePlayerQueue = queue
            PlaybackService.shared.updateQueue(queue)
        }
        if activePlayerVideo == nil {
            playerSessionID = UUID()
            activePlayerVideo = video
            isPlayerMinimized = false
        } else {
            activePlayerVideo = video
            isPlayerMinimized = false
            PlaybackService.shared.onSelectVideoFromApp?(video, queue)
        }
    }

    @MainActor
    func minimizePlayer() {
        guard activePlayerVideo != nil else { return }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            isPlayerMinimized = true
        }
    }

    @MainActor
    func expandPlayer() {
        guard activePlayerVideo != nil else { return }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            isPlayerMinimized = false
        }
    }

    @MainActor
    func closePlayer() {
        withAnimation(.easeOut(duration: 0.2)) {
            isPlayerMinimized = false
            activePlayerVideo = nil
        }
    }
}
