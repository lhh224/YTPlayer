import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var visitedTabs: Set<Int> = [0]
    @State private var needsOneTimeAPISetup: Bool = false
    @State private var oneTimeAPIKeyInput: String = ""

    private var isFullScreenPlayerPresented: Bool {
        router.isPlayerPresented && !router.isPlayerMinimized
    }

    /// Dynamic bottom scroll clearance so scrollable content flows visibly behind
    /// the floating capsule bar (and Mini Player) while never being obscured at the bottom.
    private var bottomScrollClearance: CGFloat {
        if router.isPlayerPresented && router.isPlayerMinimized {
            return 134
        }
        return 72
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Layer 1: Persistent Tab Host — preserves scroll position, search results,
            // and navigation stacks across tab switches with zero reload/flicker.
            ZStack {
                ForEach(YTBottomTab.allCases) { tab in
                    if visitedTabs.contains(tab.rawValue) {
                        let isActive = (router.selectedTab == tab.rawValue)
                        tabView(for: tab)
                            .safeAreaInset(edge: .bottom, spacing: 0) {
                                Color.clear
                                    .frame(height: bottomScrollClearance)
                                    .allowsHitTesting(false)
                            }
                            .opacity(isActive ? 1 : 0)
                            .allowsHitTesting(isActive)
                            .accessibilityHidden(!isActive)
                    }
                }
            }
            .tint(.ytRed)
            .animation(nil, value: router.selectedTab)

            // Layer 2: Single-Instance Persistent Player Host — mounted once and reused
            // across the entire app lifecycle so WKWebView & YT.Player are never recreated.
            if let activeVideo = router.activePlayerVideo {
                PlayerView(video: activeVideo, queue: router.activePlayerQueue)
                    .opacity(router.isPlayerPresented ? 1 : 0)
                    .allowsHitTesting(router.isPlayerPresented)
                    .accessibilityHidden(!router.isPlayerPresented)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                    .zIndex(isFullScreenPlayerPresented ? 30 : (router.isPlayerPresented ? 15 : -1))
            }

            // Layer 3: Floating Capsule Bottom Navigation Bar
            if !isFullScreenPlayerPresented {
                FloatingTabBar(
                    selectedTab: Binding(
                        get: { router.selectedTab },
                        set: { newTab in
                            activateTab(newTab)
                        }
                    )
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
                .zIndex(20)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .preferredColorScheme(settingsVM.isDarkMode ? .dark : .light)
        .onChange(of: router.selectedTab) { newTab in
            if !visitedTabs.contains(newTab) {
                visitedTabs.insert(newTab)
            }
        }
        .onAppear {
            visitedTabs.insert(router.selectedTab)
            if !YouTubeAPIService.shared.hasConfiguredAPIKey {
                needsOneTimeAPISetup = true
            }
        }
        .sheet(isPresented: $needsOneTimeAPISetup) {
            oneTimeAPISetupSheet
        }
    }

    private func activateTab(_ newTab: Int) {
        guard newTab != router.selectedTab else { return }
        if !visitedTabs.contains(newTab) {
            visitedTabs.insert(newTab)
        }
        #if canImport(UIKit)
        if router.selectedTab == YTBottomTab.search.rawValue {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
        #endif
        router.selectedTab = newTab
    }

    @ViewBuilder
    private func tabView(for tab: YTBottomTab) -> some View {
        switch tab {
        case .home:
            HomeView()
        case .search:
            SearchView()
        case .library:
            LibraryView()
        case .settings:
            SettingsView()
        }
    }

    private var oneTimeAPISetupSheet: some View {
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppRouter())
            .environmentObject(LibraryRepository(context: CoreDataStack.shared.context))
            .environmentObject(SettingsViewModel())
    }
}
