import SwiftUI

enum LibraryActiveView: Hashable {
    case main
    case favorites
    case history
    case playlistDetail(UserPlaylist)
}

struct LibraryView: View {
    @StateObject private var vm = LibraryViewModel()
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var libraryRepo: LibraryRepository

    @State private var activeView: LibraryActiveView = .main
    @State private var showCreatePlaylistDialog = false
    @State private var newPlaylistName = ""
    @State private var showClearHistoryConfirm = false

    private var playlists: [UserPlaylist] {
        let list = libraryRepo.fetchPlaylists()
        if !list.isEmpty { return list }
        // Default sample playlists if none created yet
        return [
            UserPlaylist(id: "pl_chill", name: "Nhạc chill", items: Array(VideoItem.mockItems.prefix(2))),
            UserPlaylist(id: "pl_ballad", name: "Ballad Việt", items: Array(VideoItem.mockItems.suffix(2))),
            UserPlaylist(id: "pl_live", name: "Quốc Thiên Live", items: [VideoItem.mockItems[0]])
        ]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                switch activeView {
                case .main:
                    mainLibraryContent
                case .favorites:
                    detailListView(title: "Bài hát yêu thích", items: vm.favoriteItems, isHistory: false)
                case .history:
                    detailListView(title: "Xem gần đây", items: vm.historyItems, isHistory: true)
                case .playlistDetail(let pl):
                    playlistDetailView(playlist: pl)
                }
            }
        }
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
        .alert("Tạo Playlist mới", isPresented: $showCreatePlaylistDialog) {
            TextField("Tên playlist...", text: $newPlaylistName)
            Button("Tạo") {
                if !newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty {
                    libraryRepo.createPlaylist(name: newPlaylistName)
                    newPlaylistName = ""
                }
            }
            Button("Hủy", role: .cancel) { newPlaylistName = "" }
        }
        .onAppear {
            vm.loadData(repo: libraryRepo)
        }
        .onReceive(libraryRepo.objectWillChange) { _ in
            vm.loadData(repo: libraryRepo)
        }
    }

    // MARK: - Main Library Overview (Matching Image 2)

    private var mainLibraryContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: "Thư viện" (Image 2)
            Text("Thư viện")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 1. Top Card with 3 Sections (Favorites, History, Playlists)
                    VStack(spacing: 0) {
                        libraryGroupRow(
                            icon: "heart.fill",
                            title: "Bài hát yêu thích",
                            subtitle: "\(vm.favoriteItems.count) bài hát",
                            action: { activeView = .favorites }
                        )

                        Divider()
                            .background(Color.white.opacity(0.08))
                            .padding(.leading, 64)

                        libraryGroupRow(
                            icon: "clock.arrow.circlepath",
                            title: "Xem gần đây",
                            subtitle: "\(vm.historyItems.count) video",
                            action: { activeView = .history }
                        )

                        Divider()
                            .background(Color.white.opacity(0.08))
                            .padding(.leading, 64)

                        libraryGroupRow(
                            icon: "music.note.list",
                            title: "Playlist của tôi",
                            subtitle: "\(playlists.count) playlist",
                            action: { /* Scroll to playlist or stay */ }
                        )
                    }
                    .background(Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0))
                    .cornerRadius(18)
                    .padding(.horizontal, 16)

                    // 2. Playlist Section Header (+ Tạo playlist in Red)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Playlist")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            Button {
                                showCreatePlaylistDialog = true
                            } label: {
                                Text("+ Tạo playlist")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.ytRed)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)

                        // Playlist Items List
                        VStack(spacing: 12) {
                            ForEach(playlists) { pl in
                                HStack(spacing: 14) {
                                    // Thumbnail
                                    let thumb = pl.items.first?.thumbnailURL ?? VideoItem.mockItems[0].thumbnailURL
                                    AsyncImageView(urlString: thumb)
                                        .aspectRatio(1.0, contentMode: .fill)
                                        .frame(width: 58, height: 58)
                                        .cornerRadius(12)
                                        .clipped()

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(pl.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        Text("\(pl.items.count) bài hát")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color.ytSubheadlineMuted)
                                    }

                                    Spacer()

                                    Menu {
                                        if let first = pl.items.first {
                                            Button {
                                                router.presentPlayer(video: first, queue: pl.items)
                                            } label: {
                                                Label("Phát tất cả", systemImage: "play.fill")
                                            }
                                        }

                                        Button(role: .destructive) {
                                            libraryRepo.deletePlaylist(id: pl.id)
                                        } label: {
                                            Label("Xóa playlist", systemImage: "trash")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(Color.ytSubheadlineMuted)
                                            .frame(width: 36, height: 36)
                                            .contentShape(Rectangle())
                                    }
                                }
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    activeView = .playlistDetail(pl)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 130)
            }
        }
    }

    private func libraryGroupRow(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Red Rounded Square Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0x3A / 255.0, green: 0x12 / 255.0, blue: 0x14 / 255.0))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color.ytRed)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color.ytSubheadlineMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0x54 / 255.0, green: 0x54 / 255.0, blue: 0x58 / 255.0))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detail List View (Favorites or History)

    private func detailListView(title: String, items: [VideoItem], isHistory: Bool) -> some View {
        VStack(spacing: 0) {
            // Header with Back button
            HStack(spacing: 12) {
                Button {
                    activeView = .main
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Thư viện")
                            .font(.system(size: 16))
                    }
                    .foregroundColor(Color.ytRed)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                if isHistory && !items.isEmpty {
                    Button("Xóa") {
                        showClearHistoryConfirm = true
                    }
                    .foregroundColor(Color.ytRed)
                } else {
                    Spacer().frame(width: 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: isHistory ? "clock" : "heart")
                        .font(.system(size: 44))
                        .foregroundColor(Color.ytSubheadlineMuted)
                    Text(isHistory ? "Chưa có lịch sử xem" : "Chưa có bài hát yêu thích")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
            } else {
                List {
                    ForEach(items) { video in
                        Button {
                            router.presentPlayer(video: video, queue: items)
                        } label: {
                            LibraryRowView(video: video)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onDelete { offsets in
                        if isHistory {
                            vm.deleteHistory(at: offsets, repo: libraryRepo)
                        } else {
                            vm.deleteFavorites(at: offsets, repo: libraryRepo)
                        }
                    }
                }
                .listStyle(.plain)
                .background(Color.black)
                .padding(.bottom, 110)
            }
        }
        .confirmationDialog("Xóa toàn bộ lịch sử?", isPresented: $showClearHistoryConfirm) {
            Button("Xóa tất cả", role: .destructive) {
                vm.clearHistory(repo: libraryRepo)
            }
            Button("Hủy", role: .cancel) {}
        }
    }

    // MARK: - Playlist Detail View

    private func playlistDetailView(playlist: UserPlaylist) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    activeView = .main
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Thư viện")
                            .font(.system(size: 16))
                    }
                    .foregroundColor(Color.ytRed)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(playlist.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                if let first = playlist.items.first {
                    Button {
                        router.presentPlayer(video: first, queue: playlist.items)
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.ytRed)
                    }
                } else {
                    Spacer().frame(width: 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if playlist.items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Text("Playlist này chưa có bài hát nào.")
                        .font(.system(size: 15))
                        .foregroundColor(Color.ytSubheadlineMuted)
                    Spacer()
                }
            } else {
                List {
                    ForEach(playlist.items) { video in
                        Button {
                            router.presentPlayer(video: video, queue: playlist.items)
                        } label: {
                            LibraryRowView(video: video)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.black)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
                .listStyle(.plain)
                .background(Color.black)
                .padding(.bottom, 110)
            }
        }
    }
}

// MARK: - Library Row
struct LibraryRowView: View {
    let video: VideoItem

    var body: some View {
        HStack(spacing: 12) {
            AsyncImageView(urlString: video.thumbnailURL)
                .aspectRatio(16 / 9, contentMode: .fill)
                .frame(width: 100, height: 60)
                .cornerRadius(10)
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text(video.channelName)
                        .font(.system(size: 12))
                        .foregroundColor(Color.ytSubheadlineMuted)

                    if !video.duration.isEmpty {
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(Color.ytSubheadlineMuted)
                        Text(video.duration)
                            .font(.system(size: 12))
                            .foregroundColor(Color.ytSubheadlineMuted)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }
}

struct LibraryView_Previews: PreviewProvider {
    static var previews: some View {
        LibraryView()
            .environmentObject(AppRouter())
            .environmentObject(LibraryRepository(context: CoreDataStack.shared.context))
    }
}
