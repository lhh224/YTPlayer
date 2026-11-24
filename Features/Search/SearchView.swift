import SwiftUI

struct SearchView: View {
    @StateObject private var vm: SearchViewModel
    @EnvironmentObject var router: AppRouter

    init(initialQuery: String = "") {
        _vm = StateObject(wrappedValue: SearchViewModel(initialQuery: initialQuery))
    }

    var body: some View {
        navigationContainer {
            VStack(spacing: 0) {
                quickSuggestionBar

                Group {
                    switch vm.state {
                    case .idle:
                        idleView
                    case .loading:
                        loadingView
                    case .loaded:
                        resultsView(videos: vm.results)
                    case .empty:
                        emptyView
                    case .error(let message):
                        errorView(message: message)
                    }
                }
            }
            .navigationTitle("Tìm kiếm")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $vm.query, prompt: "Tìm kiếm video hoặc dán link YouTube...")
            .onSubmit(of: .search) {
                vm.searchImmediate()
            }
            .onChange(of: vm.query) { _ in
                vm.search()
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

    // MARK: - Subviews

    private var quickSuggestionBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(vm.quickSuggestions, id: \.self) { tag in
                    Button {
                        vm.selectSuggestion(tag)
                    } label: {
                        Text(tag)
                            .font(.ytCaption)
                            .foregroundColor(vm.query == tag ? .white : .ytPrimaryText)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, 6)
                            .background(vm.query == tag ? Color.ytRed : Color.ytSurface)
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
        }
    }

    private var idleView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.ytSecondaryText)
            Text("Tìm kiếm video, kênh hoặc dán link YouTube")
                .font(.ytHeadline)
                .foregroundColor(.ytSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Spacer()
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Đang tìm kiếm trên YouTube...")
                .progressViewStyle(.circular)
            Spacer()
        }
    }

    private func resultsView(videos: [VideoItem]) -> some View {
        List {
            if vm.isShowingFallback, let warning = vm.apiWarningMessage {
                Section {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Kết quả từ bộ nhớ Demo (API gặp lỗi)")
                            .font(.ytCaption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        Text(warning)
                            .font(.ytCaption)
                            .foregroundColor(.ytSecondaryText)
                        Button("Cấu hình YouTube API Key trong Cài đặt") {
                            router.selectedTab = 3
                        }
                        .font(.ytCaption)
                        .foregroundColor(.ytRed)
                    }
                    .padding(.vertical, Spacing.xs)
                }
            }

            ForEach(videos) { video in
                NavigationLink(destination: PlayerView(video: video)) {
                    SearchResultRow(video: video)
                }
                .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.md, bottom: Spacing.sm, trailing: Spacing.md))
                .onAppear {
                    if video.id == videos.last?.id {
                        vm.loadMore()
                    }
                }
            }

            if vm.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyView: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "Không tìm thấy kết quả",
            subtitle: "Thử tìm kiếm với từ khóa khác hoặc dán trực tiếp đường dẫn video YouTube."
        )
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.ytRed)
            Text("Không thể kết nối YouTube Data API v3")
                .font(.ytHeadline)
                .foregroundColor(.ytPrimaryText)
            Text(message)
                .font(.ytCaption)
                .foregroundColor(.ytSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            HStack(spacing: Spacing.md) {
                Button("Thử lại") {
                    vm.searchImmediate()
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Cài đặt API Key") {
                    router.selectedTab = 3
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            Spacer()
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let video: VideoItem

    var body: some View {
        HStack(spacing: Spacing.md) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImageView(urlString: video.thumbnailURL)
                    .frame(width: 128, height: 72)
                    .cornerRadius(CornerRadius.sm)
                    .clipped()

                if !video.duration.isEmpty {
                    Text(video.duration)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(3)
                        .padding(4)
                }
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(video.title)
                    .font(.ytBodyMedium)
                    .foregroundColor(.ytPrimaryText)
                    .lineLimit(2)

                Text(video.channelName)
                    .font(.ytCaption)
                    .foregroundColor(.ytSecondaryText)
                    .lineLimit(1)

                if !video.formattedViewCount.isEmpty || !video.publishedAt.isEmpty {
                    HStack(spacing: Spacing.xs) {
                        if !video.formattedViewCount.isEmpty {
                            Text(video.formattedViewCount)
                                .font(.ytCaption)
                                .foregroundColor(.ytSecondaryText)
                        }
                        if !video.formattedViewCount.isEmpty && !video.publishedAt.isEmpty {
                            Text("•")
                                .foregroundColor(.ytSecondaryText)
                        }
                        if !video.publishedAt.isEmpty {
                            Text(video.publishedAt)
                                .font(.ytCaption)
                                .foregroundColor(.ytSecondaryText)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
            .environmentObject(AppRouter())
    }
}
