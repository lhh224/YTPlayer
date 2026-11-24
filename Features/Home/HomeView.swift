import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject var router: AppRouter

    var body: some View {
        navigationContainer {
            Group {
                if vm.isLoading && vm.videos.isEmpty {
                    SkeletonList()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if vm.isUsingFallbackData, let warning = vm.errorMessage {
                                fallbackBanner(message: warning)
                            }

                            SectionHeaderView(
                                title: vm.isUsingFallbackData ? "Danh mục nổi bật (Demo)" : "Thịnh hành tại Việt Nam",
                                actionTitle: "Làm mới",
                                action: { vm.refresh() }
                            )

                            ForEach(vm.videos) { video in
                                NavigationLink(destination: PlayerView(video: video)) {
                                    VideoCardView(video: video)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .padding(.leading, Spacing.lg)
                            }
                        }
                    }
                    .refreshable {
                        await vm.loadTrending(forceRefresh: true)
                    }
                }
            }
            .navigationTitle("YT Player")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    if vm.isLoading && !vm.videos.isEmpty {
                        ProgressView()
                    }
                }
            }
        }
        .task {
            if vm.videos.isEmpty {
                await vm.loadTrending()
            }
        }
    }

    @ViewBuilder
    private func navigationContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        #if os(iOS)
        NavigationStack {
            content()
        }
        #else
        NavigationView {
            content()
        }
        #endif
    }

    private func fallbackBanner(message: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Đang hiển thị dữ liệu mẫu (YouTube API chưa sẵn sàng)")
                    .font(.ytCaption)
                    .fontWeight(.semibold)
                    .foregroundColor(.ytPrimaryText)
            }
            Text(message)
                .font(.ytCaption)
                .foregroundColor(.ytSecondaryText)
                .lineLimit(3)

            Button("Mở Cài đặt API Key") {
                router.selectedTab = 3
            }
            .font(.ytCaption)
            .foregroundColor(.ytRed)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ytSurface)
        .cornerRadius(CornerRadius.sm)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AppRouter())
    }
}
