// MARK: - PlayerView.swift
// YTPlayer — Features/Player/PlayerView.swift
// Swift 5.7, iOS 16.0

import SwiftUI
#if canImport(UIKit)
import MediaPlayer
import UIKit
#endif

struct PlayerView: View {
    let video: VideoItem
    @StateObject private var vm: PlayerViewModel
    @EnvironmentObject var router: AppRouter
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

    private var isMinimized: Bool {
        router.activePlayerVideo != nil && router.isPlayerMinimized
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if !isMinimized {
                Color.ytBackground.ignoresSafeArea()

                // Ambient Back-Glow in Music Mode
                if vm.displayMode == .music {
                    AsyncImageView(urlString: vm.video.thumbnailURL, aspectRatio: 1.0)
                        .blur(radius: 48)
                        .opacity(0.35)
                        .ignoresSafeArea()
                }
            }

            VStack(spacing: 0) {
                if !isMinimized {
                    topHeaderBar
                }

                // Shared Media Stage: WKWebView NEVER unmounts and ALWAYS retains >= 160x90
                // viewport bounds so WebKit never marks the media page visually idle in background.
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
                    .frame(
                        width: (!isMinimized && vm.displayMode == .video) ? nil : 160,
                        height: (!isMinimized && vm.displayMode == .video) ? nil : 90
                    )
                    .opacity((!isMinimized && vm.displayMode == .video) ? 1.0 : 0.02)
                    .allowsHitTesting(!isMinimized && vm.displayMode == .video)

                    if !isMinimized && vm.displayMode == .music {
                        musicArtworkCard
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                    }
                }
                .frame(height: isMinimized ? 0 : nil)
                .clipped()
                .animation(.spring(response: 0.42, dampingFraction: 0.84), value: vm.displayMode)

                if !isMinimized {
                    if vm.displayMode == .music {
                        musicControlsSection
                            .transition(.opacity)
                    } else {
                        videoDetailsSection
                            .transition(.opacity)
                    }
                }
            }

            if isMinimized {
                miniPlayerBar
                    .padding(.horizontal, Spacing.sm)
                    .padding(.bottom, 54)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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

    // MARK: - Persistent Mini Player Bar (above TabBar when minimized with "∨")

    private var miniPlayerBar: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                router.expandPlayer()
            } label: {
                HStack(spacing: Spacing.sm) {
                    AsyncImageView(urlString: vm.video.thumbnailURL)
                        .frame(width: 52, height: 38)
                        .cornerRadius(8)
                        .clipped()

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.video.title)
                            .font(.ytCaption)
                            .fontWeight(.semibold)
                            .foregroundColor(.ytPrimaryText)
                            .lineLimit(1)
                        Text(vm.video.channelName)
                            .font(.system(size: 11))
                            .foregroundColor(.ytSecondaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }
            }
            .buttonStyle(.plain)

            Button {
                vm.togglePlayPause()
            } label: {
                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.ytPrimaryText)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)

            Button {
                vm.playNextTrack()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.ytPrimaryText)
                    .frame(width: 30, height: 34)
            }
            .buttonStyle(.plain)

            Button {
                closePlayerCompletely()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.ytSecondaryText)
                    .frame(width: 30, height: 34)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.ytSurface)
                .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
        )
    }

    private func minimizeOrDismiss() {
        if router.activePlayerVideo != nil {
            router.minimizePlayer()
        } else {
            dismiss()
        }
    }

    private func closePlayerCompletely() {
        vm.stopAndClosePlayer()
        if router.activePlayerVideo != nil {
            router.closePlayer()
        } else {
            dismiss()
        }
    }

    // MARK: - Top Header + Glowing Red-to-Orange Segmented Capsule

    private var topHeaderBar: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                // Chevron "∨": Minimizes to persistent Mini Player so background music keeps playing
                Button {
                    minimizeOrDismiss()
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
                        closePlayerCompletely()
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
        AsyncImageView(urlString: vm.video.thumbnailURL, aspectRatio: 1.0)
            .frame(width: 236, height: 236)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.55), radius: 20, x: 0, y: 10)
            .scaleEffect(vm.isPlaying ? 1.0 : 0.92)
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: vm.isPlaying)
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

            // Full-width System Volume Slider synced directly with iPhone hardware volume
            HStack(spacing: Spacing.md) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundColor(.ytSecondaryText)
                #if canImport(UIKit)
                iOSSystemVolumeSlider()
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                #else
                Slider(value: Binding(
                    get: { vm.volume },
                    set: { vm.setPlayerVolume($0) }
                ), in: 0...100)
                .tint(.ytRed)
                #endif
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundColor(.ytSecondaryText)
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
}

#if canImport(UIKit)
// MARK: - Native iOS Hardware Volume Slider (MPVolumeView)

/// Wraps Apple's `MPVolumeView` so dragging the slider directly adjusts iPhone hardware
/// speaker/AirPods volume, and pressing the physical side volume buttons updates this
/// slider automatically in real time.
private struct iOSSystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> StyledMPVolumeView {
        let volumeView = StyledMPVolumeView(frame: .zero)
        volumeView.showsVolumeSlider = true
        volumeView.backgroundColor = .clear
        return volumeView
    }

    func updateUIView(_ uiView: StyledMPVolumeView, context: Context) {
        uiView.applyTrackStyling()
    }
}

private final class StyledMPVolumeView: MPVolumeView {
    override func layoutSubviews() {
        super.layoutSubviews()
        applyTrackStyling()
    }

    func applyTrackStyling() {
        for subview in subviews {
            if let slider = subview as? UISlider {
                slider.minimumTrackTintColor = UIColor(Color.ytRed)
                slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.22)
                var sliderFrame = slider.frame
                sliderFrame.origin.x = 0
                sliderFrame.size.width = bounds.width
                sliderFrame.origin.y = (bounds.height - sliderFrame.height) / 2.0
                slider.frame = sliderFrame
            } else {
                subview.isHidden = true
            }
        }
    }
}
#endif
