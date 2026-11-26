// MARK: - NowPlayingService.swift
// YTPlayer — Services/NowPlayingService.swift
// Swift 5.7, iOS 16.0
//
// Coordinates Lock Screen & Control Center metadata.
// IMPORTANT: On iOS, `WKWebView` runs its HTML5 `<video>` decoder inside a separate
// `WebKit.GPU` XPC process which automatically owns `MPNowPlayingInfoCenter` and
// `MPRemoteCommandCenter` via WebKit's native `navigator.mediaSession`. Writing to
// `MPNowPlayingInfoCenter` or `MPRemoteCommandCenter` simultaneously from UIProcess on iOS
// causes `MRMediaRemote` double-ownership conflicts that force-pause `<video>`!
// Therefore, on iOS we delegate Lock Screen display & remote commands to WebKit's native
// `navigator.mediaSession` bridge, while keeping direct `MPNowPlayingInfoCenter` updates
// active on macOS / standalone unit-test environments where `WKWebView` is not mounted.

import Foundation
import MediaPlayer
#if canImport(UIKit)
import UIKit
private typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
private typealias PlatformImage = NSImage
#endif

final class NowPlayingService {

    // MARK: - Singleton

    static let shared = NowPlayingService()

    // MARK: - Private Properties

    private let artworkCache = NSCache<NSString, PlatformImage>()
    private var currentArtworkTask: Task<Void, Never>?
    private var lastLoadedVideoId: String?
    private var lastLoadedArtwork: MPMediaItemArtwork?
    private var isRemoteCommandsConfigured = false

    private init() {}

    // MARK: - Remote Command Center Setup

    func configureRemoteCommands() {
        #if os(iOS)
        // Handled directly inside WKWebView's `navigator.mediaSession.setActionHandler`
        // (`WebKit.GPU`) and forwarded via `ytPlayer` JS bridge to avoid double-ownership pauses.
        return
        #else
        guard !isRemoteCommandsConfigured else { return }
        isRemoteCommandsConfigured = true

        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            guard PlaybackService.shared.currentVideo != nil else { return .noActionableNowPlayingItem }
            PlaybackService.shared.remotePlay()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            guard PlaybackService.shared.currentVideo != nil else { return .noActionableNowPlayingItem }
            PlaybackService.shared.remotePause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            guard PlaybackService.shared.currentVideo != nil else { return .noActionableNowPlayingItem }
            PlaybackService.shared.remoteTogglePlayPause()
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { _ in
            guard PlaybackService.shared.currentVideo != nil else { return .noActionableNowPlayingItem }
            PlaybackService.shared.remoteNextTrack()
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { _ in
            guard PlaybackService.shared.currentVideo != nil else { return .noActionableNowPlayingItem }
            PlaybackService.shared.remotePreviousTrack()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent,
                  PlaybackService.shared.currentVideo != nil else {
                return .noActionableNowPlayingItem
            }
            PlaybackService.shared.remoteSeek(to: positionEvent.positionTime)
            return .success
        }
        #endif
    }

    // MARK: - Now Playing Metadata Updates

    func updateNowPlaying(
        video: VideoItem,
        isPlaying: Bool,
        elapsedTime: TimeInterval = 0,
        duration: TimeInterval = 0
    ) {
        #if os(iOS)
        // Metadata is pushed to `window.__ytUpdateMediaSession` inside `WKWebView` so
        // `WebKit.GPU` publishes Lock Screen info without interrupting HTML5 video playback.
        return
        #else
        let resolvedDuration = duration > 0 ? duration : Self.parseDurationSeconds(from: video.duration)
        let isLive = video.duration.uppercased() == "LIVE"

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: video.title,
            MPMediaItemPropertyArtist: video.channelName,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(0, elapsedTime),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]

        if isLive {
            info[MPNowPlayingInfoPropertyIsLiveStream] = true
        } else if resolvedDuration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = resolvedDuration
        }

        if lastLoadedVideoId == video.id, let cachedArtwork = lastLoadedArtwork {
            info[MPMediaItemPropertyArtwork] = cachedArtwork
        } else if let cachedImg = artworkCache.object(forKey: video.thumbnailURL as NSString) {
            let artwork = makeMediaArtwork(from: cachedImg)
            lastLoadedVideoId = video.id
            lastLoadedArtwork = artwork
            info[MPMediaItemPropertyArtwork] = artwork
        } else {
            loadArtworkAsync(for: video)
        }

        let applyBlock = {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        }

        if Thread.isMainThread {
            applyBlock()
        } else {
            DispatchQueue.main.async(execute: applyBlock)
        }
        #endif
    }

    func updatePlaybackState(isPlaying: Bool, elapsedTime: TimeInterval? = nil, duration: TimeInterval? = nil) {
        #if os(iOS)
        return
        #else
        let applyBlock = {
            guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
            info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
            if let elapsedTime = elapsedTime {
                info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(0, elapsedTime)
            }
            if let duration = duration, duration > 0 {
                info[MPMediaItemPropertyPlaybackDuration] = duration
            }
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        }

        if Thread.isMainThread {
            applyBlock()
        } else {
            DispatchQueue.main.async(execute: applyBlock)
        }
        #endif
    }

    func clearNowPlaying() {
        currentArtworkTask?.cancel()
        currentArtworkTask = nil
        lastLoadedVideoId = nil
        lastLoadedArtwork = nil

        #if !os(iOS)
        let clearBlock = {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            MPNowPlayingInfoCenter.default().playbackState = .stopped
        }
        if Thread.isMainThread {
            clearBlock()
        } else {
            DispatchQueue.main.async(execute: clearBlock)
        }
        #endif
    }

    // MARK: - Helpers

    /// Parses human-readable duration strings such as `"4:15"` or `"1:02:05"` into seconds.
    static func parseDurationSeconds(from formatted: String) -> TimeInterval {
        let trimmed = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.uppercased() != "LIVE" else { return 0 }
        let parts = trimmed.split(separator: ":").compactMap { Double($0) }
        switch parts.count {
        case 3:
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        case 2:
            return parts[0] * 60 + parts[1]
        case 1:
            return parts[0]
        default:
            return 0
        }
    }

    private func loadArtworkAsync(for video: VideoItem) {
        currentArtworkTask?.cancel()
        guard let url = URL(string: video.thumbnailURL) else { return }
        let targetVideoId = video.id
        let cacheURLString = video.thumbnailURL

        currentArtworkTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let image = PlatformImage(data: data) else { return }
                self.artworkCache.setObject(image, forKey: cacheURLString as NSString)
                let artwork = self.makeMediaArtwork(from: image)

                await MainActor.run {
                    guard PlaybackService.shared.currentVideo?.id == targetVideoId else { return }
                    self.lastLoadedVideoId = targetVideoId
                    self.lastLoadedArtwork = artwork
                    if var info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                        info[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                    }
                }
            } catch {}
        }
    }

    private func makeMediaArtwork(from image: PlatformImage) -> MPMediaItemArtwork {
        let size = image.size.width > 0 && image.size.height > 0
            ? image.size
            : CGSize(width: 480, height: 360)
        return MPMediaItemArtwork(boundsSize: size) { _ in image }
    }
}
