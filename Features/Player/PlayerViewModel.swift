// MARK: - PlayerViewModel.swift
// YTPlayer — Features/Player/PlayerViewModel.swift
// Swift 5.7, iOS 16.0

import Foundation
import Combine
import SwiftUI

enum PlaybackDisplayMode: String, CaseIterable {
    case music = "Music"
    case video = "Video"
}

@MainActor
final class PlayerViewModel: ObservableObject {

    enum PlayerState: Equatable {
        case idle
        case loading
        case playing
        case paused
        case ended
        case error(String)
    }

    @Published var video: VideoItem
    @Published var displayMode: PlaybackDisplayMode = .video
    @Published var playerState: PlayerState = .idle
    @Published var isFavorite: Bool = false
    @Published var isShuffle: Bool = false
    @Published var isRepeat: Bool = false
    @Published var volume: Double = 100
    @Published var showLyrics: Bool = false

    var isPlaying: Bool {
        playerState == .playing || playerState == .loading
    }

    private let initialVideoId: String
    private var isPlayerReady: Bool = false
    private var libraryRepo: LibraryRepository
    private var cancellables: Set<AnyCancellable> = []

    var sendJSCommand: ((String) -> Void)? {
        didSet {
            PlaybackService.shared.jsCommandExecutor = sendJSCommand
        }
    }

    /// Stable HTML string built once for the single `WKWebView` / `YT.Player` instance.
    let embedHTML: String

    init(video: VideoItem, libraryRepo: LibraryRepository, queue: [VideoItem] = []) {
        self.video = video
        self.initialVideoId = video.id
        self.libraryRepo = libraryRepo
        self.isFavorite = libraryRepo.isFavorite(videoId: video.id)
        self.embedHTML = PlaybackService.shared.buildEmbedHTML(videoId: video.id, autoplay: true, initialVideo: video)

        if !queue.isEmpty {
            PlaybackService.shared.updateQueue(queue)
        }
        PlaybackService.shared.play(video: video)
        bindRemoteCommands()
        observeSleepTimer()
    }

    func bindRepository(_ repo: LibraryRepository) {
        self.libraryRepo = repo
        self.isFavorite = repo.isFavorite(videoId: video.id)
    }

    func registerJSBridge(_ executor: @escaping (String) -> Void) {
        self.sendJSCommand = executor
        bindRemoteCommands()
    }

    private func bindRemoteCommands() {
        PlaybackService.shared.onRemotePlay = { [weak self] in
            Task { @MainActor in
                self?.playPlayer()
            }
        }
        PlaybackService.shared.onRemotePause = { [weak self] in
            Task { @MainActor in
                self?.pausePlayer(userInitiated: true)
            }
        }
        PlaybackService.shared.onRemoteNextTrack = { [weak self] in
            Task { @MainActor in
                self?.playNextTrack()
            }
        }
        PlaybackService.shared.onRemotePreviousTrack = { [weak self] in
            Task { @MainActor in
                self?.playPreviousTrack()
            }
        }
        PlaybackService.shared.onRemoteSeek = { [weak self] seconds in
            Task { @MainActor in
                self?.seekTo(seconds: seconds)
            }
        }
        PlaybackService.shared.onSelectVideoFromApp = { [weak self] nextVideo, queue in
            Task { @MainActor in
                guard let self = self else { return }
                if !queue.isEmpty {
                    PlaybackService.shared.updateQueue(queue)
                }
                if self.video.id != nextVideo.id {
                    self.switchTrack(to: nextVideo)
                } else if self.playerState == .paused || self.playerState == .ended || self.playerState == .idle {
                    // Same track re-opened from list after being closed/paused: resume without reloading
                    self.playPlayer()
                }
            }
        }
    }

    func handleJSMessage(_ message: String) {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String else { return }

        let currentTime = (json["currentTime"] as? Double) ?? PlaybackService.shared.currentTime
        let duration = (json["duration"] as? Double) ?? PlaybackService.shared.duration

        switch event {
        case "onReady":
            isPlayerReady = true
            PlaybackDiagnostics.shared.logPlayerEvent(
                "YT.onReady",
                source: "youtube_iframe",
                details: "videoId=\(video.id), duration=\(String(format: "%.1f", duration))s"
            )
            if !PlaybackService.shared.isUserPaused {
                playerState = .playing
                PlaybackService.shared.play(video: video)
            }
            if duration > 0 {
                PlaybackService.shared.updateProgress(currentTime: currentTime, duration: duration)
            }

        case "onDiagnostic":
            let name = (json["name"] as? String) ?? "unknown"
            let source = (json["source"] as? String) ?? "webkit_js"
            let st = (json["playerState"] as? Int).map { String($0) } ?? "-"
            PlaybackDiagnostics.shared.logPlayerEvent(
                name,
                source: source,
                details: "ytState=\(st), pos=\(String(format: "%.2f", currentTime))s"
            )

        case "onTimeUpdate":
            PlaybackService.shared.updateProgress(currentTime: currentTime, duration: duration)

        case "onRemoteCommand":
            if let cmd = json["command"] as? String {
                PlaybackDiagnostics.shared.logPlayerEvent("mediaSession.\(cmd)", source: "lock_screen")
                switch cmd {
                case "play":
                    playerState = .playing
                    PlaybackService.shared.play(video: video)
                case "pause":
                    playerState = .paused
                    PlaybackService.shared.pause(userInitiated: true)
                case "nextTrack":
                    playNextTrack()
                case "previousTrack":
                    playPreviousTrack()
                default:
                    break
                }
            }

        case "onStateChange":
            let stateCode = (json["data"] as? Int) ?? (json["state"] as? Int)
            guard let code = stateCode else { return }
            PlaybackDiagnostics.shared.logPlayerEvent(
                "YT.onStateChange(\(Self.describeYTState(code)))",
                source: PlaybackService.shared.isAppInBackground ? "ios_webkit_or_youtube_bg" : "youtube_iframe",
                details: "videoId=\(video.id), pos=\(String(format: "%.2f", currentTime))s, userPaused=\(PlaybackService.shared.isUserPaused)"
            )

            switch code {
            case -1:
                if playerState != .playing {
                    playerState = .idle
                }

            case 0:
                if isRepeat {
                    restartVideo()
                } else if PlaybackService.shared.playbackQueue.count > 1 {
                    playNextTrack()
                } else {
                    playerState = .ended
                    PlaybackService.shared.pause(userInitiated: false)
                }

            case 1:
                if playerState != .playing {
                    playerState = .playing
                }
                PlaybackService.shared.play(video: video)
                PlaybackService.shared.updateProgress(currentTime: currentTime, duration: duration)

            case 2:
                playerState = .paused
                // Preserve whether pause came from user action vs external/WebKit pause
                PlaybackService.shared.pause(userInitiated: PlaybackService.shared.isUserPaused || !PlaybackService.shared.isAppInBackground)
                PlaybackService.shared.updateProgress(currentTime: currentTime, duration: duration)

            case 3:
                playerState = .loading

            case 5:
                playerState = .idle

            default:
                break
            }

        case "onError":
            let errVal = (json["data"] as? Int) ?? (json["error"] as? Int)
            let code = errVal.map { String($0) } ?? "unknown"
            PlaybackDiagnostics.shared.logPlayerEvent("YT.onError", source: "youtube_iframe", details: "code=\(code)")
            playerState = .error("Mã lỗi trình phát YouTube: \(code)")

        default:
            break
        }
    }

    private static func describeYTState(_ code: Int) -> String {
        switch code {
        case -1: return "UNSTARTED"
        case 0:  return "ENDED"
        case 1:  return "PLAYING"
        case 2:  return "PAUSED"
        case 3:  return "BUFFERING"
        case 5:  return "CUED"
        default: return "CODE_\(code)"
        }
    }

    func togglePlayPause() {
        if playerState == .playing {
            pausePlayer(userInitiated: true)
        } else {
            playPlayer()
        }
    }

    func playPlayer() {
        playerState = .playing
        PlaybackService.shared.play(video: video)
        sendJSCommand?("window.__ytSetUserPaused && window.__ytSetUserPaused(false); if (window.player && typeof player.getPlayerState === 'function' && player.getPlayerState() !== 1 && player.getPlayerState() !== 3) { player.playVideo(); }")
    }

    func pausePlayer(userInitiated: Bool = true) {
        playerState = .paused
        PlaybackService.shared.pause(userInitiated: userInitiated)
        let pausedFlag = userInitiated ? "true" : "false"
        sendJSCommand?("window.__ytSetUserPaused && window.__ytSetUserPaused(\(pausedFlag)); if (window.player && typeof player.getPlayerState === 'function' && player.getPlayerState() === 1) { player.pauseVideo(); }")
    }

    /// Pauses playback cleanly without destroying the underlying `WKWebView` / `YT.Player` singleton.
    func stopAndClosePlayer() {
        sendJSCommand?("window.__ytSetUserPaused && window.__ytSetUserPaused(true); if (window.player && typeof player.pauseVideo === 'function') { player.pauseVideo(); }")
        playerState = .paused
        PlaybackService.shared.stop()
    }

    func restartVideo() {
        playerState = .playing
        PlaybackService.shared.play(video: video)
        sendJSCommand?("window.__ytSetUserPaused && window.__ytSetUserPaused(false); if (window.player && typeof player.seekTo === 'function') { player.seekTo(0, true); if (player.getPlayerState() !== 1) { player.playVideo(); } }")
    }

    func seekTo(seconds: TimeInterval) {
        let clamped = max(0, seconds)
        sendJSCommand?("if (window.player && typeof player.seekTo === 'function') { player.seekTo(\(clamped), true); }")
        PlaybackService.shared.updateProgress(currentTime: clamped, duration: PlaybackService.shared.duration)
    }

    func setPlayerVolume(_ newVolume: Double) {
        volume = newVolume
        let vInt = Int(newVolume)
        sendJSCommand?("if (window.player && typeof player.setVolume === 'function') { player.setVolume(\(vInt)); }")
    }

    func switchTrack(to nextVideo: VideoItem) {
        guard video.id != nextVideo.id else {
            if !isPlaying {
                playPlayer()
            }
            return
        }
        video = nextVideo
        isFavorite = libraryRepo.isFavorite(videoId: nextVideo.id)
        playerState = .loading
        addToHistory()
        PlaybackService.shared.play(video: nextVideo)
        sendJSCommand?("if (window.__ytLoadTrackIfNeeded) { window.__ytLoadTrackIfNeeded('\(nextVideo.id)'); } else if (window.player && typeof player.loadVideoById === 'function') { player.loadVideoById('\(nextVideo.id)'); }")
        Task {
            await loadFullDetailsIfNeeded()
        }
    }

    func playNextTrack() {
        playAdjacent(offset: 1)
    }

    func playPreviousTrack() {
        if PlaybackService.shared.currentTime > 5 {
            restartVideo()
            return
        }
        playAdjacent(offset: -1)
    }

    func playAdjacent(offset: Int) {
        let pool = PlaybackService.shared.playbackQueue.isEmpty
            ? VideoItem.mockItems
            : PlaybackService.shared.playbackQueue
        guard !pool.isEmpty else { return }

        if isShuffle && pool.count > 1 {
            let candidates = pool.filter { $0.id != video.id }
            if let randomTrack = candidates.randomElement() {
                switchTrack(to: randomTrack)
                return
            }
        }

        if let idx = pool.firstIndex(where: { $0.id == video.id }) {
            let nextIdx = (idx + offset + pool.count) % pool.count
            switchTrack(to: pool[nextIdx])
        } else {
            switchTrack(to: pool[0])
        }
    }

    func toggleFavorite() {
        do {
            if isFavorite {
                try libraryRepo.removeFavorite(videoId: video.id)
            } else {
                try libraryRepo.addFavorite(video)
            }
            isFavorite.toggle()
        } catch {
            print("[PlayerViewModel] toggleFavorite error: \(error.localizedDescription)")
        }
    }

    func addToHistory() {
        do {
            try libraryRepo.addToHistory(video)
        } catch {
            print("[PlayerViewModel] addToHistory error: \(error.localizedDescription)")
        }
    }

    func loadFullDetailsIfNeeded() async {
        guard video.viewCount.isEmpty || video.description.isEmpty else { return }
        guard YouTubeAPIService.shared.hasConfiguredAPIKey else { return }
        if let enriched = try? await YouTubeAPIService.shared.fetchVideoDetail(videoId: video.id) {
            self.video = enriched
            if PlaybackService.shared.currentVideo?.id == enriched.id {
                NowPlayingService.shared.updateNowPlaying(
                    video: enriched,
                    isPlaying: PlaybackService.shared.isPlaying,
                    elapsedTime: PlaybackService.shared.currentTime,
                    duration: PlaybackService.shared.duration
                )
            }
        }
    }

    private func observeSleepTimer() {
        NotificationCenter.default
            .publisher(for: Notification.Name("SleepTimerFired"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.pausePlayer(userInitiated: true)
            }
            .store(in: &cancellables)
    }
}
