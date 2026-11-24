import SwiftUI

@main
struct YTPlayerApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var libraryRepo = LibraryRepository(context: CoreDataStack.shared.context)
    @StateObject private var settingsVM = SettingsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(router)
                .environmentObject(libraryRepo)
                .environmentObject(settingsVM)
        }
    }
}
