// MARK: - PlayerView.swift
// YTPlayer — Features/Player/PlayerView.swift
// Swift 5.7, iOS 16.0
//
// Minimalist Premium Entertainment UI (Apple Music & YouTube OLED style).
// Preserves single-instance WKWebView, persistent audio session, and stable background playback.

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
    @ObservedObject private var playbackService = PlaybackService.shared
    @ObservedObject private var sleepTimer = SleepTimerService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showUpNextSheet = false
    @State private var showPlaylistSheet = false
    @State private var playlistTargetVideo: VideoItem? = nil
    @State private var showSleepTimerSheet = false
    @State private var newPlaylistName = ""
    @State private var isSeeking = false
    @State private var scrubProgress: Double = 0
    @State private var isSubscribed = false
    @State private var copiedLinkToast = false

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

    private var miniPlayerBottomPadding: CGFloat {
        #if canImport(UIKit)
        let bottomInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.safeAreaInsets.bottom ?? 0
        return bottomInset > 0 ? 52 : 74
        #else
        return 68
        #endif
    }

    private var isMinimized: Bool {
        router.activePlayerVideo != nil && (!router.isPlayerPresented || router.isPlayerMinimized)
    }

    private var effectiveCurrentTime: TimeInterval {
        if isSeeking {
            let dur = playbackService.duration > 0 ? playbackService.duration : 1
            return scrubProgress * dur
        }
        return playbackService.currentTime
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if !isMinimized {
                // OLED Black Background with subtle dynamic gradient in Music Mode
                Color.black.ignoresSafeArea()

                if vm.displayMode == .music {
                    musicDynamicBackground
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
                    .cornerRadius((!isMinimized && vm.displayMode == .video) ? 14 : 0)
                    .clipped()
                    .padding(.horizontal, (!isMinimized && vm.displayMode == .video) ? 12 : 0)
                    .opacity((!isMinimized && vm.displayMode == .video) ? 1.0 : 0.02)
                    .allowsHitTesting(!isMinimized && vm.displayMode == .video)

                    if !isMinimized && vm.displayMode == .music {
                        musicArtworkCard
                            .transition(.scale(scale: 0.94).combined(with: .opacity))
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

            if router.isPlayerPresented && router.isPlayerMinimized {
                miniPlayerBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, miniPlayerBottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        #if os(iOS)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        #endif
        .sheet(isPresented: $showUpNextSheet) {
            upNextSheetView
        }
        .sheet(isPresented: $showPlaylistSheet) {
            playlistSheetView
        }
        .sheet(isPresented: $showSleepTimerSheet) {
            sleepTimerSheetView
        }
        .onAppear {
            vm.bindRepository(libraryRepo)
            vm.addToHistory()
        }
        .task {
            await vm.loadFullDetailsIfNeeded()
        }
    }

    // MARK: - Dynamic Ambient Glow (Music Mode)

    private var musicDynamicBackground: some View {
        ZStack {
            // Soft Radial Glow from artwork top
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0x6E / 255.0, green: 0x12 / 255.0, blue: 0x1A / 255.0).opacity(0.85),
                    Color(red: 0x3A / 255.0, green: 0x08 / 255.0, blue: 0x0E / 255.0).opacity(0.55),
                    Color.black
                ]),
                center: .top,
                startRadius: 40,
                endRadius: 520
            )
            .ignoresSafeArea()

            AsyncImageView(urlString: vm.video.thumbnailURL, aspectRatio: 1.0)
                .blur(radius: 64)
                .opacity(0.20)
                .ignoresSafeArea()
        }
    }

    // MARK: - Top Header (Images 4 & 5)

    private var topHeaderBar: some View {
        VStack(spacing: 8) {
            HStack {
                // Down Chevron: Minimizes to persistent Mini Player
                Button {
                    minimizeOrDismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("YT Player")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                HStack(spacing: 6) {
                    Button {
                        vm.toggleFavorite()
                    } label: {
                        Image(systemName: vm.isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundColor(vm.isFavorite ? Color.ytRed : .white)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)

                    Button {
                        closePlayerCompletely()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            // Mode Switcher: [ 🎵 Music ] | [ 🎬 Video ] with Red-Orange Gradient Capsule
            HStack(spacing: 4) {
                modePillButton(mode: .music, title: "Music", icon: "music.note")
                modePillButton(mode: .video, title: "Video", icon: "film")
            }
            .padding(3)
            .background(
                Capsule()
                    .fill(Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0).opacity(0.95))
            )
            .padding(.bottom, 6)
        }
    }

    private func modePillButton(mode: PlaybackDisplayMode, title: String, icon: String) -> some View {
        let isSelected = (vm.displayMode == mode)
        return Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                vm.displayMode = mode
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.vertical, 7)
            .padding(.horizontal, 24)
            .background(
                Group {
                    if isSelected {
                        Capsule().fill(Color.ytModeGradient)
                    } else {
                        Capsule().fill(Color.clear)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Persistent Mini Player Bar (Image 2 & 3)

    private var miniPlayerBar: some View {
        Button {
            router.expandPlayer()
        } label: {
            HStack(spacing: 12) {
                AsyncImageView(urlString: vm.video.thumbnailURL)
                    .aspectRatio(16 / 9, contentMode: .fill)
                    .frame(width: 50, height: 38)
                    .cornerRadius(8)
                    .clipped()

                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.video.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(vm.video.channelName)
                        .font(.system(size: 11))
                        .foregroundColor(Color.ytSubheadlineMuted)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Button {
                    vm.togglePlayPause()
                } label: {
                    Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)

                Button {
                    closePlayerCompletely()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 32, height: 38)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0).opacity(0.96))

                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.16), Color.ytRed.opacity(0.24), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(0.6), radius: 14, x: 0, y: 6)
            )
        }
        .buttonStyle(.plain)
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

    // MARK: - Music Mode Artwork Card (Image 4)

    private var musicArtworkCard: some View {
        AsyncImageView(urlString: vm.video.thumbnailURL, aspectRatio: 1.0)
            .aspectRatio(1.0, contentMode: .fit)
            .frame(maxWidth: 310, maxHeight: 310)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.65), radius: 26, x: 0, y: 14)
            .scaleEffect(vm.isPlaying ? 1.0 : 0.94)
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: vm.isPlaying)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
    }

    // MARK: - Music Controls Section (Image 4: Audio Wave, Red Slider, 5 Transport, 4 Actions, Up Next)

    private var musicControlsSection: some View {
        VStack(spacing: 16) {
            // Track Info Row: Waveform + Title & Channel + Heart + Add to Playlist
            HStack(spacing: 12) {
                Image(systemName: vm.isPlaying ? "waveform" : "waveform.slash")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.ytRed)

                VStack(alignment: .leading, spacing: 3) {
                    Text(vm.video.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(vm.video.channelName)
                        .font(.system(size: 13))
                        .foregroundColor(Color.ytSubheadlineMuted)
                        .lineLimit(1)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        vm.toggleFavorite()
                    } label: {
                        ZStack {
                            Circle().fill(Color(red: 0x24 / 255.0, green: 0x24 / 255.0, blue: 0x26 / 255.0)).frame(width: 36, height: 36)
                            Image(systemName: vm.isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 15))
                                .foregroundColor(vm.isFavorite ? Color.ytRed : .white)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        playlistTargetVideo = vm.video
                        showPlaylistSheet = true
                    } label: {
                        ZStack {
                            Circle().fill(Color(red: 0x24 / 255.0, green: 0x24 / 255.0, blue: 0x26 / 255.0)).frame(width: 36, height: 36)
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            // Red Progress Bar Slider with White Circular Knob
            musicProgressBarView
                .padding(.horizontal, 20)

            // 5 Transport Controls: Shuffle, Previous, Big White Play/Pause (64pt), Next, Repeat
            HStack(spacing: 24) {
                Button {
                    vm.isShuffle.toggle()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(vm.isShuffle ? Color.ytRed : Color.ytSubheadlineMuted)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Button {
                    vm.playPreviousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                // Large White Circular Play/Pause (64pt)
                Button {
                    vm.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 64, height: 64)
                            .shadow(color: Color.white.opacity(0.3), radius: 14)

                        Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Color.black)
                            .offset(x: vm.isPlaying ? 0 : 2)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    vm.playNextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                Button {
                    vm.isRepeat.toggle()
                } label: {
                    Image(systemName: "repeat")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(vm.isRepeat ? Color.ytRed : Color.ytSubheadlineMuted)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)

            // 4 Quick Action Buttons (Image 4): Hẹn giờ, Danh sách, Chia sẻ, Tự động phát
            HStack(spacing: 12) {
                quickActionButton(
                    icon: "timer",
                    title: sleepTimer.isActive ? sleepTimer.remainingFormatted : "Hẹn giờ",
                    isActive: sleepTimer.isActive
                ) {
                    showSleepTimerSheet = true
                }

                quickActionButton(
                    icon: "list.bullet.rectangle",
                    title: "Danh sách",
                    isActive: false
                ) {
                    playlistTargetVideo = vm.video
                    showPlaylistSheet = true
                }

                Button {
                    shareVideo(vm.video)
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0))
                                .frame(width: 58, height: 50)
                            Image(systemName: "link")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                        Text("Chia sẻ")
                            .font(.system(size: 11))
                            .foregroundColor(Color.ytSubheadlineMuted)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                quickActionButton(
                    icon: "play.rectangle",
                    title: "Tự động phát",
                    isActive: vm.isAutoplayNext
                ) {
                    vm.isAutoplayNext.toggle()
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 4)

            // Bottom Drawer: [ ☰ Danh sách phát tiếp theo (Up Next)    ⌃ ]
            Button {
                showUpNextSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Danh sách phát tiếp theo (Up Next)")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.up")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    private func quickActionButton(icon: String, title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isActive ? Color(red: 0x3A / 255.0, green: 0x12 / 255.0, blue: 0x14 / 255.0) : Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0))
                        .frame(width: 58, height: 50)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isActive ? Color.ytRed : .white)
                }
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(isActive ? Color.ytRed : Color.ytSubheadlineMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Red Progress Bar with White Knob (Image 4)

    private var musicProgressBarView: some View {
        let dur = playbackService.duration > 0 ? playbackService.duration : 1.0
        let cur = effectiveCurrentTime
        let pct = max(0.0, min(1.0, cur / dur))

        return VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: 4)

                    // Active red progress track
                    Capsule()
                        .fill(Color.ytRed)
                        .frame(width: max(0, geo.size.width * CGFloat(pct)), height: 4)

                    // White knob
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: Color.black.opacity(0.4), radius: 3)
                        .offset(x: max(0, min(geo.size.width - 14, geo.size.width * CGFloat(pct) - 7)))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isSeeking = true
                            scrubProgress = max(0.0, min(1.0, Double(value.location.x / geo.size.width)))
                        }
                        .onEnded { value in
                            let targetPct = max(0.0, min(1.0, Double(value.location.x / geo.size.width)))
                            let targetSec = targetPct * dur
                            vm.seekTo(seconds: targetSec)
                            isSeeking = false
                        }
                )
            }
            .frame(height: 18)

            // Elapsed & Total duration labels (e.g. "18:24" / "1:25:24")
            HStack {
                Text(formatDurationSeconds(cur))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.ytSubheadlineMuted)
                Spacer()
                Text(formatDurationSeconds(dur))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(Color.ytSubheadlineMuted)
            }
        }
    }

    private func formatDurationSeconds(_ sec: TimeInterval) -> String {
        guard sec > 0, !sec.isNaN else { return "0:00" }
        let total = Int(sec)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Video Mode Details Section (Image 5)

    private var videoDetailsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Title (2 lines)
                Text(vm.video.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .padding(.horizontal, 16)

                // Channel Row + Subscribe Button (Image 5)
                HStack(spacing: 10) {
                    // Avatar circle with initials
                    Circle()
                        .fill(Color.ytRed)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Text(String(vm.video.channelName.prefix(2)).uppercased())
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vm.video.channelName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(vm.video.formattedViewCount.isEmpty ? "YouTube Official" : "\(vm.video.formattedViewCount) lượt xem")
                            .font(.system(size: 12))
                            .foregroundColor(Color.ytSubheadlineMuted)
                    }

                    Spacer()

                    // "Đăng ký" (Subscribe) red capsule pill button (Image 5)
                    Button {
                        isSubscribed.toggle()
                    } label: {
                        Text(isSubscribed ? "Đã đăng ký" : "Đăng ký")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(isSubscribed ? Color(red: 0x2C / 255.0, green: 0x2C / 255.0, blue: 0x2E / 255.0) : Color.ytRed)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                // Action Pills Row: [ 👍 24K ] [ + Danh sách phát ] [ ↗ Chia sẻ ] [ 🔗 Sao chép ]
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            vm.toggleFavorite()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: vm.isFavorite ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    .foregroundColor(vm.isFavorite ? Color.ytRed : .white)
                                Text(vm.isFavorite ? "Đã thích" : "Thích")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            playlistTargetVideo = vm.video
                            showPlaylistSheet = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "plus")
                                    .foregroundColor(Color.ytRed)
                                Text("Danh sách phát")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            shareVideo(vm.video)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.up.right")
                                Text("Chia sẻ")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0)))
                        }
                        .buttonStyle(.plain)

                        Button {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = "https://www.youtube.com/watch?v=\(vm.video.id)"
                            #endif
                            copiedLinkToast = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copiedLinkToast = false
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: copiedLinkToast ? "checkmark" : "link")
                                Text(copiedLinkToast ? "Đã chép" : "Sao chép")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                }

                // Collapsible Description Card (Image 5)
                if !vm.video.description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Mô tả video")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: vm.showLyrics ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(Color.ytSubheadlineMuted)
                        }

                        Text(vm.video.description)
                            .font(.system(size: 12))
                            .foregroundColor(Color.ytSubheadlineMuted)
                            .lineLimit(vm.showLyrics ? nil : 3)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0)))
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.showLyrics.toggle()
                        }
                    }
                }

                // Related Videos List ("Video liên quan" - Image 5)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Video liên quan")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                    let relatedList = PlaybackService.shared.playbackQueue.filter { $0.id != vm.video.id }
                    ForEach(relatedList.isEmpty ? VideoItem.mockItems.filter { $0.id != vm.video.id } : relatedList) { item in
                        HStack(spacing: 12) {
                            Button {
                                vm.switchTrack(to: item)
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack(alignment: .bottomTrailing) {
                                        AsyncImageView(urlString: item.thumbnailURL)
                                            .aspectRatio(16 / 9, contentMode: .fill)
                                            .frame(width: 120, height: 68)
                                            .cornerRadius(12)
                                            .clipped()

                                        if !item.duration.isEmpty {
                                            Text(item.duration)
                                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(Color.black.opacity(0.85))
                                                .cornerRadius(3)
                                                .padding(4)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)

                                        Text(item.channelName)
                                            .font(.system(size: 11))
                                            .foregroundColor(Color.ytSubheadlineMuted)
                                            .lineLimit(1)

                                        if !item.formattedViewCount.isEmpty {
                                            Text(item.formattedViewCount)
                                                .font(.system(size: 11))
                                                .foregroundColor(Color.ytSubheadlineMuted)
                                        }
                                    }

                                    Spacer(minLength: 4)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Menu {
                                Button {
                                    PlaybackService.shared.playbackQueue.append(item)
                                } label: {
                                    Label("Phát tiếp theo", systemImage: "text.insert")
                                }

                                Button {
                                    playlistTargetVideo = item
                                    showPlaylistSheet = true
                                } label: {
                                    Label("Lưu vào danh sách phát", systemImage: "text.badge.plus")
                                }

                                Button {
                                    shareVideo(item)
                                } label: {
                                    Label("Chia sẻ", systemImage: "square.and.arrow.up")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color.ytSubheadlineMuted)
                                    .frame(width: 32, height: 32)
                                    .contentShape(Rectangle())
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Up Next Sheet

    private var upNextSheetView: some View {
        let queueSource = PlaybackService.shared.playbackQueue.isEmpty
            ? VideoItem.mockItems
            : PlaybackService.shared.playbackQueue

        return VStack(spacing: 0) {
            HStack {
                Text("Danh sách phát tiếp theo")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button("Đóng") {
                    showUpNextSheet = false
                }
                .foregroundColor(Color.ytRed)
            }
            .padding(16)

            List(queueSource.filter { $0.id != vm.video.id }) { item in
                Button {
                    vm.switchTrack(to: item)
                    showUpNextSheet = false
                } label: {
                    LibraryRowView(video: item)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.black)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
            .listStyle(.plain)
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Playlist Sheet

    private var playlistSheetView: some View {
        let targetVideo = playlistTargetVideo ?? vm.video

        return VStack(spacing: 16) {
            HStack {
                Text("Lưu vào Danh sách phát")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button("Xong") {
                    showPlaylistSheet = false
                }
                .foregroundColor(Color.ytRed)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            HStack {
                TextField("Tên danh sách phát mới...", text: $newPlaylistName)
                    .textFieldStyle(.roundedBorder)
                Button("+ Tạo") {
                    if !newPlaylistName.trimmingCharacters(in: .whitespaces).isEmpty {
                        libraryRepo.createPlaylist(name: newPlaylistName, initialVideo: targetVideo)
                        newPlaylistName = ""
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 16)

            List(libraryRepo.fetchPlaylists()) { pl in
                let contains = pl.items.contains(where: { $0.id == targetVideo.id })
                Button {
                    libraryRepo.toggleVideo(targetVideo, inPlaylistId: pl.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(pl.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text("\(pl.items.count) bài")
                                .font(.system(size: 12))
                                .foregroundColor(Color.ytSubheadlineMuted)
                        }
                        Spacer()
                        Image(systemName: contains ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundColor(contains ? Color.ytRed : Color.ytSubheadlineMuted)
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.black)
            }
            .listStyle(.plain)
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Sleep Timer Sheet

    private var sleepTimerSheetView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Hẹn giờ tắt nhạc")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button("Đóng") {
                    showSleepTimerSheet = false
                }
                .foregroundColor(Color.ytRed)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            if sleepTimer.isActive {
                VStack(spacing: 8) {
                    Text("Đang hẹn giờ: \(sleepTimer.remainingFormatted)")
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.ytRed)

                    Button("Hủy hẹn giờ") {
                        sleepTimer.cancel()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding()
            }

            VStack(spacing: 12) {
                ForEach([15, 30, 45, 60], id: \.self) { mins in
                    Button {
                        sleepTimer.start(minutes: mins)
                        showSleepTimerSheet = false
                    } label: {
                        HStack {
                            Text("\(mins) phút")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13))
                                .foregroundColor(Color.ytSubheadlineMuted)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func shareVideo(_ targetVideo: VideoItem) {
        guard let url = URL(string: "https://www.youtube.com/watch?v=\(targetVideo.id)") else { return }
        #if canImport(UIKit)
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        #endif
    }
}
