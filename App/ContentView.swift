import SwiftUI

struct ContentView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var settingsVM: SettingsViewModel

    var body: some View {
        TabView(selection: $router.selectedTab) {
            HomeView()
                .tabItem {
                    Label("Trang chủ", systemImage: "house")
                }
                .tag(0)

            SearchView()
                .tabItem {
                    Label("Tìm kiếm", systemImage: "magnifyingglass")
                }
                .tag(1)

            LibraryView()
                .tabItem {
                    Label("Thư viện", systemImage: "books.vertical")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Cài đặt", systemImage: "gear")
                }
                .tag(3)
        }
        .tint(.ytRed)
        .preferredColorScheme(settingsVM.isDarkMode ? .dark : .light)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppRouter())
            .environmentObject(LibraryRepository(context: CoreDataStack.shared.context))
            .environmentObject(SettingsViewModel())
    }
}
