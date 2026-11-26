import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var libraryRepo: LibraryRepository

    private var sectionHeaderTitle: String {
        if vm.isUsingFallbackData {
            return "Danh mục nổi bật (Demo)"
        }
        return vm.isPersonalizedFeed ? "Đề xuất cho bạn" : "Thịnh hành tại Việt Nam"
    }

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
                                title: sectionHeaderTitle,
                                actionTitle: "Làm mới",
                                action: { vm.refresh(repo: libraryRepo) }
                            )

                            if vm.isPersonalizedFeed && !vm.recommendationSummary.isEmpty && !vm.isUsingFallbackData {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 11))
                                        .foregroundColor(.ytRed)
                                    Text("Dựa trên thói quen xem: \(vm.recommendationSummary)")
                                        .font(.ytCaption)
                                        .foregroundColor(.ytSecondaryText)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, Spacing.lg)
                                .padding(.bottom, Spacing.sm)
                            }

                            ForEach(vm.videos) { video in
                                Button {
                                    router.presentPlayer(video: video, queue: vm.videos)
                                } label: {
                                    VideoCardView(video: video)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .padding(.leading, Spacing.lg)
                            }
                        }
                    }
                    .refreshable {
                        await vm.loadTrending(repo: libraryRepo, forceRefresh: true)
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
        .onAppear {
            vm.ensureFeedLoaded(repo: libraryRepo)
        }
        .onReceive(libraryRepo.objectWillChange) { _ in
            // Refresh Home recommendations in background after user watches/favorites new videos
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if router.selectedTab == 0 {
                    vm.ensureFeedLoaded(repo: libraryRepo)
                }
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
            .environmentObject(LibraryRepository(context: CoreDataStack.shared.context))
    }
}
