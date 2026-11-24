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

    private var libraryRepo: LibraryRepository
    private var cancellables: Set<AnyCancellable> = []

    var sendJSCommand: ((String) -> Void)?

    var embedHTML: String {
        PlaybackService.shared.buildEmbedHTML(videoId: video.id, autoplay: true)
    }

    init(video: VideoItem, libraryRepo: LibraryRepository) {
        self.video = video
        self.libraryRepo = libraryRepo
        self.isFavorite = libraryRepo.isFavorite(videoId: video.id)

        observeSleepTimer()
    }

    func bindRepository(_ repo: LibraryRepository) {
        self.libraryRepo = repo
        self.isFavorite = repo.isFavorite(videoId: video.id)
    }

    func handleJSMessage(_ message: String) {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let event = json["event"] as? String else { return }

        switch event {
        case "onReady":
            playerState = .playing

        case "onStateChange":
            let stateCode = (json["data"] as? Int) ?? (json["state"] as? Int)
            guard let code = stateCode else { return }
            switch code {
            case -1: playerState = .idle
            case 0:
                if isRepeat {
                    restartVideo()
                } else {
                    playerState = .ended
                    PlaybackService.shared.pause()
                }
            case 1:
                playerState = .playing
                PlaybackService.shared.play(video: video)
            case 2:
                playerState = .paused
                PlaybackService.shared.pause()
            case 3: playerState = .loading
            case 5: playerState = .idle
            default: break
            }

        case "onError":
            let errVal = (json["data"] as? Int) ?? (json["error"] as? Int)
            let code = errVal.map { String($0) } ?? "unknown"
            playerState = .error("Mã lỗi trình phát YouTube: \(code)")

        default:
            break
        }
    }

    func togglePlayPause() {
        if playerState == .playing {
            pausePlayer()
        } else {
            playPlayer()
        }
    }

    func playPlayer() {
        playerState = .playing
        PlaybackService.shared.play(video: video)
        sendJSCommand?("if (window.player && typeof player.playVideo === 'function') { player.playVideo(); }")
    }

    func pausePlayer() {
        playerState = .paused
        PlaybackService.shared.pause()
        sendJSCommand?("if (window.player && typeof player.pauseVideo === 'function') { player.pauseVideo(); }")
    }

    func restartVideo() {
        sendJSCommand?("if (window.player && typeof player.seekTo === 'function') { player.seekTo(0, true); player.playVideo(); }")
        playerState = .playing
    }

    func setPlayerVolume(_ newVolume: Double) {
        volume = newVolume
        let vInt = Int(newVolume)
        sendJSCommand?("if (window.player && typeof player.setVolume === 'function') { player.setVolume(\(vInt)); }")
    }

    func switchTrack(to nextVideo: VideoItem) {
        video = nextVideo
        isFavorite = libraryRepo.isFavorite(videoId: nextVideo.id)
        addToHistory()
        sendJSCommand?("if (window.player && typeof player.loadVideoById === 'function') { player.loadVideoById('\(nextVideo.id)'); }")
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
        }
    }

    private func observeSleepTimer() {
        NotificationCenter.default
            .publisher(for: Notification.Name("SleepTimerFired"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.pausePlayer()
            }
            .store(in: &cancellables)
    }
}
