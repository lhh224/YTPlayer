import SwiftUI

struct LibraryView: View {
    @StateObject private var vm = LibraryViewModel()
    @EnvironmentObject var libraryRepo: LibraryRepository

    @State private var showClearHistoryConfirm = false

    var body: some View {
        navigationContainer {
            VStack(spacing: 0) {
                Picker("Tab", selection: $vm.selectedTab) {
                    Text("Yêu thích (\(vm.favoriteItems.count))").tag(LibraryTab.favorites)
                    Text("Lịch sử (\(vm.historyItems.count))").tag(LibraryTab.history)
                }
                .pickerStyle(.segmented)
                .padding(Spacing.md)

                switch vm.selectedTab {
                case .favorites:
                    favoritesContent
                case .history:
                    historyContent
                }
            }
            .navigationTitle("Thư viện")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    if vm.selectedTab == .history && !vm.historyItems.isEmpty {
                        Button("Xóa tất cả") {
                            showClearHistoryConfirm = true
                        }
                        .foregroundColor(.ytRed)
                    }
                }
            }
            .confirmationDialog(
                "Xóa toàn bộ lịch sử xem?",
                isPresented: $showClearHistoryConfirm,
                titleVisibility: .visible
            ) {
                Button("Xóa tất cả", role: .destructive) {
                    vm.clearHistory(repo: libraryRepo)
                }
                Button("Hủy", role: .cancel) {}
            } message: {
                Text("Hành động này không thể hoàn tác.")
            }
            .onAppear {
                vm.loadData(repo: libraryRepo)
            }
            .onReceive(libraryRepo.objectWillChange) { _ in
                vm.loadData(repo: libraryRepo)
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

    // MARK: - Favorites

    private var favoritesContent: some View {
        Group {
            if vm.favoriteItems.isEmpty {
                EmptyStateView(
                    icon: "heart",
                    title: "Chưa có video yêu thích",
                    subtitle: "Nhấn biểu tượng trái tim khi xem video để thêm vào đây."
                )
            } else {
                List {
                    ForEach(vm.favoriteItems) { video in
                        NavigationLink(destination: PlayerView(video: video, queue: vm.favoriteItems)) {
                            LibraryRowView(video: video)
                        }
                        .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.md, bottom: Spacing.sm, trailing: Spacing.md))
                    }
                    .onDelete { indexSet in
                        vm.deleteFavorites(at: indexSet, repo: libraryRepo)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - History

    private var historyContent: some View {
        Group {
            if vm.historyItems.isEmpty {
                EmptyStateView(
                    icon: "clock",
                    title: "Chưa có lịch sử xem",
                    subtitle: "Các video bạn đã xem sẽ xuất hiện ở đây."
                )
            } else {
                List {
                    ForEach(vm.historyItems) { video in
                        NavigationLink(destination: PlayerView(video: video, queue: vm.historyItems)) {
                            LibraryRowView(video: video)
                        }
                        .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.md, bottom: Spacing.sm, trailing: Spacing.md))
                    }
                    .onDelete { indexSet in
                        vm.deleteHistory(at: indexSet, repo: libraryRepo)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Library Row

struct LibraryRowView: View {
    let video: VideoItem

    var body: some View {
        HStack(spacing: Spacing.md) {
            AsyncImageView(urlString: video.thumbnailURL)
                .frame(width: 120, height: 68)
                .cornerRadius(CornerRadius.sm)
                .clipped()

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(video.title)
                    .font(.ytBodyMedium)
                    .foregroundColor(.ytPrimaryText)
                    .lineLimit(2)

                Text(video.channelName)
                    .font(.ytCaption)
                    .foregroundColor(.ytSecondaryText)

                if !video.duration.isEmpty {
                    Text(video.duration)
                        .font(.ytCaption)
                        .foregroundColor(.ytSecondaryText)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

struct LibraryView_Previews: PreviewProvider {
    static var previews: some View {
        LibraryView()
            .environmentObject(LibraryRepository(context: CoreDataStack.shared.context))
    }
}
