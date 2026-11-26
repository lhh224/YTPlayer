// MARK: - PlayerView.swift
// YTPlayer — Features/Player/PlayerView.swift
// Swift 5.7, iOS 16.0

import SwiftUI

struct PlayerView: View {
    let video: VideoItem
    @StateObject private var vm: PlayerViewModel
    @EnvironmentObject var libraryRepo: LibraryRepository
    @Environment(\.dismiss) private var dismiss
    @State private var showUpNextSheet = false
    @State private var showPlaylistSheet = false
    @State private var newPlaylistName = ""

    init(video: VideoItem, queue: [VideoItem] = []) {
        self.video = video
        _vm = StateObject(
            wrappedValue: PlayerViewModel(
                video: video,
                libraryRepo: LibraryRepository(context: CoreDataStack.shared.context),
                queue: queue
            )
        )
    }

    var body: some View {
        ZStack {
            Color.ytBackground.ignoresSafeArea()

            // Ambient Back-Glow in Music Mode
            if vm.displayMode == .music {
                AsyncImageView(urlString: vm.video.thumbnailURL, aspectRatio: 1.0)
                    .blur(radius: 48)
                    .opacity(0.35)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                topHeaderBar

                // Shared Media Stage
                ZStack {
                    YouTubeWebView(
                        html: vm.embedHTML,
                        onPlayerEvent: { message in
                            vm.handleJSMessage(message)
                        },
                        commandHandler: { executeJS in
                            vm.registerJSBridge(executeJS)
                        }
                    )
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .opacity(vm.displayMode == .video ? 1 : 0.01)
                    .frame(height: vm.displayMode == .video ? nil : 1)

                    if vm.displayMode == .music {
                        musicArtworkCard
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.84), value: vm.displayMode)

                if vm.displayMode == .music {
                    musicControlsSection
                        .transition(.opacity)
                } else {
                    videoDetailsSection
                        .transition(.opacity)
                }
            }
        }
        #if os(iOS)
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showUpNextSheet) {
            upNextSheetView
        }
        .sheet(isPresented: $showPlaylistSheet) {
            playlistSheetView
        }
        .onAppear {
            vm.bindRepository(libraryRepo)
            vm.addToHistory()
        }
        .task {
            await vm.loadFullDetailsIfNeeded()
        }
    }

    // MARK: - Top Header + Glowing Red-to-Orange Segmented Capsule

    private var topHeaderBar: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                // Chevron "∨" ONLY — no "Thu nhỏ" text
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.ytPrimaryText)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("YT Player")
                    .font(.ytHeadline)
                    .foregroundColor(.ytPrimaryText)

                Spacer()

                HStack(spacing: 4) {
                    Button {
                        vm.toggleFavorite()
                    } label: {
                        Image(systemName: vm.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundColor(vm.isFavorite ? .ytRed : .ytPrimaryText)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)

                    Button {
                        vm.stopAndClosePlayer()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.ytSecondaryText)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.md)

            // Glowing Red-to-Orange Gradient Border Capsule
            HStack(spacing: 4) {
                ForEach(PlaybackDisplayMode.allCases, id: \.self) { mode in
                    let isSelected = (vm.displayMode == mode)
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                            vm.displayMode = mode
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: mode == .music ? "music.note" : "film")
                                .font(.caption)
                            Text(mode.rawValue)
                                .font(.ytCaption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(isSelected ? .white : .ytSecondaryText)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 18)
                        .background(
                            Capsule()
                                .fill(isSelected
                                      ? LinearGradient(
                                          colors: [Color.ytRed.opacity(0.32), Color.orange.opacity(0.24)],
                                          startPoint: .topLeading,
                                          endPoint: .bottomTrailing
                                      )
                                      : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom))
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isSelected
                                    ? LinearGradient(colors: [.ytRed, .orange], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                                    lineWidth: 1.2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Capsule().fill(Color.ytSurface.opacity(0.85)))
            .padding(.bottom, Spacing.xs)
        }
        .padding(.top, Spacing.xs)
    }

    // MARK: - Music Mode Views (20px Rounded Square Artwork + Audio Wave + "+ Playlist")

    private var musicArtworkCard: some View {
        ZStack {
            if vm.showLyrics {
                ScrollView {
                    Text(vm.video.description.isEmpty ? "Chưa có lời bài hát cho bản thu này." : vm.video.description)
                        .font(.ytCaption)
                        .foregroundColor(.ytPrimaryText)
                        .multilineTextAlignment(.center)
                        .padding(Spacing.lg)
                }
                .frame(width: 236, height: 236)
                .background(RoundedRectangle(cornerRadius: 20).fill(Color.ytSurface))
            } else {
                AsyncImageView(urlString: vm.video.thumbnailURL, aspectRatio: 1.0)
                    .frame(width: 236, height: 236)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.55), radius: 20, x: 0, y: 10)
                    .scaleEffect(vm.isPlaying ? 1.0 : 0.92)
                    .animation(.spring(response: 0.45, dampingFraction: 0.78), value: vm.isPlaying)
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    private var musicControlsSection: some View {
        VStack(spacing: Spacing.lg) {
            // Meta Row: Audio Wave Indicator + Title/Subtitle + Heart + "+ Playlist"
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: vm.isPlaying ? "waveform" : "waveform.slash")
                            .font(.caption)
                            .foregroundColor(.ytRed)
                        Text(vm.video.title)
                            .font(.ytHeadline)
                            .foregroundColor(.ytPrimaryText)
                            .lineLimit(1)
                    }
                    Text(vm.video.channelName)
                        .font(.ytSubheadline)
                        .foregroundColor(.ytSecondaryText)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        vm.toggleFavorite()
                    } label: {
                        Image(systemName: vm.isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(vm.isFavorite ? .ytRed : .ytSecondaryText)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.ytSurface))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showPlaylistSheet = true
                    } label: {
                        Image(systemName: "text.badge.plus")
                            .foregroundColor(.ytPrimaryText)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.ytSurface))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Crisp White Transport Controls
            HStack(spacing: Spacing.xl) {
                Button {
                    vm.isShuffle.toggle()
                } label: {
                    Image(systemName: "shuffle")
                        .foregroundColor(vm.isShuffle ? .ytRed : .ytSecondaryText)
                }
                .buttonStyle(.plain)

                Button {
                    vm.playPreviousTrack()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title3)
                        .foregroundColor(.ytPrimaryText)
                }
                .buttonStyle(.plain)

                Button {
                    vm.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.ytPrimaryText)
                            .frame(width: 58, height: 58)
                            .shadow(color: Color.white.opacity(0.25), radius: 12)
                        Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(Color.ytBackground)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    vm.playNextTrack()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title3)
                        .foregroundColor(.ytPrimaryText)
                }
                .buttonStyle(.plain)

                Button {
                    vm.isRepeat.toggle()
                } label: {
                    Image(systemName: "repeat")
                        .foregroundColor(vm.isRepeat ? .ytRed : .ytSecondaryText)
                }
                .buttonStyle(.plain)
            }

            // Volume + "[ 📄 Lời bài hát ]"
            HStack(spacing: Spacing.md) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundColor(.ytSecondaryText)
                Slider(value: Binding(
                    get: { vm.volume },
                    set: { vm.setPlayerVolume($0) }
                ), in: 0...100)
                .tint(.ytRed)

                Button {
                    withAnimation { vm.showLyrics.toggle() }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.text")
                        Text("Lời bài hát")
                    }
                    .font(.ytCaption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.ytSurface))
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            // Sliding Drawer: [ ☰ Danh sách phát tiếp theo (Up Next) ^ ]
            Button {
                showUpNextSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption)
                        .foregroundColor(.ytSecondaryText)
                    Text("Danh sách phát tiếp theo (Up Next)")
                        .font(.ytCaption)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(.caption)
                }
                .foregroundColor(.ytPrimaryText)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.ytSurface))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.md)
    }

    // MARK: - Video Mode Views

    private var videoDetailsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VideoInfoView(
                    video: vm.video,
                    isFavorite: vm.isFavorite,
                    onFavoriteTap: {
                        vm.toggleFavorite()
                    },
                    onAddToPlaylistTap: {
                        showPlaylistSheet = true
                    }
                )
            }
        }
    }

    // MARK: - Sheets

    private var upNextSheetView: some View {
        let queueSource = PlaybackService.shared.playbackQueue.isEmpty
            ? VideoItem.mockItems
            : PlaybackService.shared.playbackQueue
        return List(queueSource.filter { $0.id != vm.video.id }) { item in
            Button {
                vm.switchTrack(to: item)
                showUpNextSheet = false
            } label: {
                SearchResultRow(video: item)
            }
            .buttonStyle(.plain)
        }
    }

    private var playlistSheetView: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                Text("Lưu vào Danh sách phát")
                    .font(.ytHeadline)
                Spacer()
                Button("Xong") {
                    showPlaylistSheet = false
                }
                .foregroundColor(.ytRed)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.lg)

            HStack {
                TextField("Tên danh sách phát mới...", text: $newPlaylistName)
                    .textFieldStyle(.roundedBorder)
                Button("+ Tạo") {
                    libraryRepo.createPlaylist(name: newPlaylistName, initialVideo: vm.video)
                    newPlaylistName = ""
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, Spacing.lg)

            List(libraryRepo.fetchPlaylists()) { pl in
                let contains = pl.items.contains(where: { $0.id == vm.video.id })
                Button {
                    libraryRepo.toggleVideo(vm.video, inPlaylistId: pl.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(pl.name)
                                .font(.ytBodyMedium)
                            Text("\(pl.items.count) bài")
                                .font(.ytCaption)
                                .foregroundColor(.ytSecondaryText)
                        }
                        Spacer()
                        Image(systemName: contains ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundColor(contains ? .ytRed : .ytSecondaryText)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func playAdjacent(offset: Int) {
        vm.playAdjacent(offset: offset)
    }
}
