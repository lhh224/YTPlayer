import SwiftUI

struct ContentView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var needsOneTimeAPISetup: Bool = !YouTubeAPIService.shared.hasConfiguredAPIKey
    @State private var oneTimeAPIKeyInput: String = ""

    var body: some View {
        ZStack(alignment: .bottom) {
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

            // Persistent Player Host: stays mounted across tabs, minimize (`∨`), and screen lock
            if let activeVideo = router.activePlayerVideo {
                PlayerView(video: activeVideo, queue: router.activePlayerQueue)
                    .id(router.playerSessionID)
                    .zIndex(10)
            }
        }
        .preferredColorScheme(settingsVM.isDarkMode ? .dark : .light)
        .sheet(isPresented: $needsOneTimeAPISetup) {
            VStack(spacing: Spacing.lg) {
                Text("Thiết lập lần đầu")
                    .font(.ytHeadline)
                    .padding(.top, Spacing.lg)

                Text("Nhập YouTube Data API v3 Key một lần duy nhất để kích hoạt tìm kiếm trực tiếp. (Nếu đã cấu hình trong Config/APIKeys.plist, bước này sẽ tự động bỏ qua).")
                    .font(.ytCaption)
                    .foregroundColor(.ytSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)

                SecureField("Dán YouTube API Key (AIzaSy...)", text: $oneTimeAPIKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled(true)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .padding(.horizontal, Spacing.lg)

                HStack(spacing: Spacing.md) {
                    Button("Để sau") {
                        needsOneTimeAPISetup = false
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Lưu & Sử dụng luôn") {
                        let trimmed = oneTimeAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            YouTubeAPIService.shared.updateAPIKey(trimmed)
                            needsOneTimeAPISetup = false
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(oneTimeAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Spacer()
            }
            .padding()
        }
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
