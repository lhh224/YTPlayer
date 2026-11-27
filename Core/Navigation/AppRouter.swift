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

    /// Single-instance persistent player host state: once mounted on first playback,
    /// the single `WKWebView` / `YT.Player` instance is reused for the entire app session.
    @Published var activePlayerVideo: VideoItem? = nil
    @Published var activePlayerQueue: [VideoItem] = []
    @Published var isPlayerPresented: Bool = false
    @Published var isPlayerMinimized: Bool = false

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

    // MARK: - Single-Instance Player Presentation

    @MainActor
    func presentPlayer(video: VideoItem, queue: [VideoItem] = []) {
        if !queue.isEmpty {
            activePlayerQueue = queue
            PlaybackService.shared.updateQueue(queue)
        }
        if activePlayerVideo == nil {
            activePlayerVideo = video
            isPlayerMinimized = false
            isPlayerPresented = true
        } else {
            activePlayerVideo = video
            isPlayerMinimized = false
            isPlayerPresented = true
            PlaybackService.shared.onSelectVideoFromApp?(video, queue)
        }
    }

    @MainActor
    func minimizePlayer() {
        guard isPlayerPresented else { return }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            isPlayerMinimized = true
        }
    }

    @MainActor
    func expandPlayer() {
        guard activePlayerVideo != nil else { return }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            isPlayerPresented = true
            isPlayerMinimized = false
        }
    }

    @MainActor
    func closePlayer() {
        withAnimation(.easeOut(duration: 0.2)) {
            isPlayerMinimized = false
            isPlayerPresented = false
        }
    }
}
