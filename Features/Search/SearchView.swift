import SwiftUI

struct SearchView: View {
    @StateObject private var vm: SearchViewModel
    @EnvironmentObject var router: AppRouter
    @State private var showClearHistoryConfirm = false

    init(initialQuery: String = "") {
        _vm = StateObject(wrappedValue: SearchViewModel(initialQuery: initialQuery))
    }

    var body: some View {
        navigationContainer {
            Group {
                switch vm.state {
                case .idle:
                    searchHistoryView
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
            .navigationTitle("Tìm kiếm")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    if vm.state == .idle && !vm.searchHistory.isEmpty {
                        Button("Xóa lịch sử") {
                            showClearHistoryConfirm = true
                        }
                        .font(.ytCaption)
                        .foregroundColor(.ytRed)
                    }
                }
            }
            .searchable(text: $vm.query, prompt: "Tìm kiếm trên YouTube hoặc dán link...")
            .onSubmit(of: .search) {
                vm.searchImmediate()
            }
            .onChange(of: vm.query) { newValue in
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    vm.clear()
                } else {
                    vm.search()
                }
            }
            .confirmationDialog(
                "Xóa toàn bộ lịch sử tìm kiếm?",
                isPresented: $showClearHistoryConfirm,
                titleVisibility: .visible
            ) {
                Button("Xóa tất cả", role: .destructive) {
                    vm.clearSearchHistory()
                }
                Button("Hủy", role: .cancel) {}
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

    // MARK: - YouTube-Style Search History View

    private var searchHistoryView: some View {
        Group {
            if vm.searchHistory.isEmpty {
                VStack(spacing: Spacing.lg) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.ytSecondaryText)
                    Text("Lịch sử tìm kiếm của bạn sẽ hiển thị tại đây")
                        .font(.ytSubheadline)
                        .foregroundColor(.ytSecondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                    Spacer()
                }
            } else {
                List {
                    ForEach(vm.searchHistory) { entry in
                        HStack(spacing: Spacing.md) {
                            Button {
                                vm.selectHistoryEntry(entry)
                            } label: {
                                HStack(spacing: Spacing.md) {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .font(.system(size: 16))
                                        .foregroundColor(.ytSecondaryText)
                                        .frame(width: 24)

                                    Text(entry.query)
                                        .font(.ytBody)
                                        .foregroundColor(.ytPrimaryText)
                                        .lineLimit(1)

                                    Spacer(minLength: 4)

                                    if let thumb = entry.thumbnailURL, !thumb.isEmpty {
                                        AsyncImageView(urlString: thumb)
                                            .frame(width: 52, height: 30)
                                            .cornerRadius(4)
                                            .clipped()
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            // YouTube-style diagonal arrow to copy term into search box for editing
                            Button {
                                vm.fillQueryFromHistory(entry)
                            } label: {
                                Image(systemName: "arrow.up.left")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.ytSecondaryText)
                                    .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: Spacing.md, bottom: 6, trailing: Spacing.sm))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                vm.deleteHistoryEntry(entry)
                            } label: {
                                Label("Xóa", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Search Results & States

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
                    }
                    .padding(.vertical, Spacing.xs)
                }
            }

            ForEach(videos) { video in
                Button {
                    vm.recordOpenedResult(video)
                    router.presentPlayer(video: video, queue: videos)
                } label: {
                    SearchResultRow(video: video)
                }
                .buttonStyle(.plain)
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

            Button("Thử lại") {
                vm.searchImmediate()
            }
            .buttonStyle(PrimaryButtonStyle())
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
