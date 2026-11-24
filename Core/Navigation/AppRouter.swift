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
}
