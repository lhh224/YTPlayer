import SwiftUI

struct HomeView: View {
    @StateObject private var vm = HomeViewModel()
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var libraryRepo: LibraryRepository
    @ObservedObject private var playbackService = PlaybackService.shared

    @State private var selectedVideoForPlaylist: VideoItem? = nil
    @State private var showPlaylistSheet = false
    @State private var showActivitySheet = false
    @State private var newPlaylistName = ""

    private var historyVideos: [VideoItem] {
        let history = libraryRepo.fetchHistory()
        if !history.isEmpty {
            return history
        }
        // Graceful initial fallback items if history is empty on first launch
        return Array(VideoItem.mockItems.prefix(4))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Custom Header (Image 3)
                homeHeaderBar

                if vm.isLoading && vm.videos.isEmpty {
                    SkeletonList()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
                            if vm.isUsingFallbackData, let warning = vm.errorMessage {
                                fallbackBanner(message: warning)
                            }

                            // 1. Khu vực Nghe tiếp (Horizontal Scroll)
                            continueListeningSection

                            // 2. Khu vực Đề xuất cho bạn (Vertical List)
                            recommendedSection
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 130) // Space for FloatingTabBar and MiniPlayer
                    }
                    .refreshable {
                        await vm.loadTrending(repo: libraryRepo, forceRefresh: true)
                    }
                }
            }
        }
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
        .sheet(isPresented: $showPlaylistSheet) {
            playlistSheetView
        }
        .sheet(isPresented: $showActivitySheet) {
            activitySheetView
        }
        .onAppear {
            vm.ensureFeedLoaded(repo: libraryRepo)
        }
        .onReceive(libraryRepo.objectWillChange) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                if router.selectedTab == 0 {
                    vm.ensureFeedLoaded(repo: libraryRepo)
                }
            }
        }
    }

    // MARK: - Header Bar (Image 3: Red YouTube Play Logo + YT Player + Bell)

    private var homeHeaderBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                // Red YouTube Play Badge
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.ytRed)
                        .frame(width: 30, height: 21)

                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: 0.5)
                }

                Text("YT Player")
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundColor(.white)
            }

            Spacer()

            // Notification & Activity Bell
            Button {
                #if canImport(UIKit)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                #endif
                showActivitySheet = true
            } label: {
                Image(systemName: SleepTimerService.shared.isActive ? "bell.badge.fill" : "bell")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(SleepTimerService.shared.isActive ? Color.ytRed : .white)
                    .frame(width: 38, height: 38)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .background(Color.black)
    }

    // MARK: - Section 1: Nghe tiếp (Continue Listening horizontal scroll)

    private var continueListeningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                router.selectedTab = YTBottomTab.library.rawValue
            } label: {
                HStack(spacing: 6) {
                    Text("Nghe tiếp")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.ytSubheadlineMuted)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(historyVideos) { video in
                        let isThisPlaying = playbackService.isPlaying && playbackService.currentVideo?.id == video.id

                        Button {
                            router.presentPlayer(video: video, queue: historyVideos)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack {
                                    AsyncImageView(urlString: video.thumbnailURL)
                                        .aspectRatio(16 / 10, contentMode: .fill)
                                        .frame(width: 154, height: 96)
                                        .cornerRadius(16)
                                        .clipped()

                                    // Frosted Dark Circle with Pause icon if actively playing (Image 3)
                                    if isThisPlaying {
                                        ZStack {
                                            Circle()
                                                .fill(Color.black.opacity(0.65))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Circle().stroke(Color.white.opacity(0.2), lineWidth: 1)
                                                )

                                            Image(systemName: "pause.fill")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(video.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    Text(video.channelName)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color.ytSubheadlineMuted)
                                        .lineLimit(1)
                                }
                                .frame(width: 154, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Section 2: Đề xuất cho bạn (Vertical List)

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Đề xuất cho bạn")
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            ForEach(vm.videos) { video in
                Button {
                    router.presentPlayer(video: video, queue: vm.videos)
                } label: {
                    VideoCardView(video: video) {
                        selectedVideoForPlaylist = video
                        showPlaylistSheet = true
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Playlist Sheet

    private var playlistSheetView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Lưu vào danh sách phát")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button("Xong") {
                    showPlaylistSheet = false
                }
                .foregroundColor(.ytRed)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            HStack {
                TextField("Tên danh sách phát mới...", text: $newPlaylistName)
                    .textFieldStyle(.roundedBorder)
                Button("+ Tạo") {
                    if let vid = selectedVideoForPlaylist, !newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty {
                        libraryRepo.createPlaylist(name: newPlaylistName, initialVideo: vid)
                        newPlaylistName = ""
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 16)

            List(libraryRepo.fetchPlaylists()) { pl in
                let contains = selectedVideoForPlaylist != nil && pl.items.contains(where: { $0.id == selectedVideoForPlaylist?.id })
                Button {
                    if let vid = selectedVideoForPlaylist {
                        libraryRepo.toggleVideo(vid, inPlaylistId: pl.id)
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pl.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text("\(pl.items.count) bài")
                                .font(.system(size: 12))
                                .foregroundColor(Color.ytSubheadlineMuted)
                        }
                        Spacer()
                        Image(systemName: contains ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundColor(contains ? .ytRed : Color.ytSubheadlineMuted)
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.black)
            }
            .listStyle(.plain)
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Activity & Notifications Sheet

    private var activitySheetView: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Hoạt động & Trạng thái")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button("Đóng") {
                    showActivitySheet = false
                }
                .foregroundColor(Color.ytRed)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 20))
                        .foregroundColor(SleepTimerService.shared.isActive ? Color.ytRed : Color.ytSubheadlineMuted)
                        .frame(width: 36, height: 36)
                        .background(Color.ytSurfaceSecondary)
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hẹn giờ tắt nhạc")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text(SleepTimerService.shared.isActive ? "Còn lại \(SleepTimerService.shared.remainingFormatted)" : "Chưa bật")
                            .font(.system(size: 12))
                            .foregroundColor(Color.ytSubheadlineMuted)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color.ytSurfaceOLED)
                .cornerRadius(14)

                HStack(spacing: 12) {
                    Image(systemName: "music.note.house.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color.ytRed)
                        .frame(width: 36, height: 36)
                        .background(Color.ytSurfaceSecondary)
                        .cornerRadius(10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Thư viện cá nhân")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        Text("\(libraryRepo.fetchFavorites().count) yêu thích • \(libraryRepo.fetchHistory().count) lịch sử • \(libraryRepo.fetchPlaylists().count) playlist")
                            .font(.system(size: 12))
                            .foregroundColor(Color.ytSubheadlineMuted)
                    }
                    Spacer()
                }
                .padding(14)
                .background(Color.ytSurfaceOLED)
                .cornerRadius(14)

                Button {
                    showActivitySheet = false
                    Task {
                        await vm.loadTrending(repo: libraryRepo, forceRefresh: true)
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Làm mới đề xuất trang chủ")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.ytRed)
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func fallbackBanner(message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Đang hiển thị dữ liệu mẫu (YouTube API chưa sẵn sàng)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(Color.ytSubheadlineMuted)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.ytSurfaceOLED)
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AppRouter())
            .environmentObject(LibraryRepository(context: CoreDataStack.shared.context))
    }
}
