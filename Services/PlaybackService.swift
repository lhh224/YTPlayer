// PlaybackService.swift
// YTPlayer
//
// Manages single-instance playback state, shared WebKit connection pool, passive
// foreground/background lifecycle handling (zero redundant player commands on transitions),
// AudioSession management, and structured transition diagnostics logging.

import Foundation
import Combine
import WebKit
import AVFoundation
import os
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Structured Playback Transition Diagnostics

final class PlaybackDiagnostics {
    static let shared = PlaybackDiagnostics()

    private let logger = Logger(subsystem: "com.ytplayer.app", category: "PlaybackLifecycle")
    private let lock = NSLock()
    private let bootTime = CFAbsoluteTimeGetCurrent()
    private var lastLifecycleTimestamp: CFAbsoluteTime = 0
    private(set) var recentEvents: [String] = []

    private init() {}

    func markLifecycle(_ event: String, details: String = "") {
        lock.lock()
        lastLifecycleTimestamp = CFAbsoluteTimeGetCurrent()
        let elapsedMs = Int((lastLifecycleTimestamp - bootTime) * 1000)
        let entry = details.isEmpty
            ? "[+\(elapsedMs)ms] [Lifecycle] \(event)"
            : "[+\(elapsedMs)ms] [Lifecycle] \(event) | \(details)"
        appendEntryLocked(entry)
        lock.unlock()

        logger.info("\(entry, privacy: .public)")
    }

    func logPlayerEvent(_ event: String, source: String, details: String = "") {
        lock.lock()
        let now = CFAbsoluteTimeGetCurrent()
        let elapsedMs = Int((now - bootTime) * 1000)
        let sinceTransitionMs = lastLifecycleTimestamp > 0
            ? Int((now - lastLifecycleTimestamp) * 1000)
            : -1
        let transitionTag = (sinceTransitionMs >= 0 && sinceTransitionMs <= 3000)
            ? "dt_transition=\(sinceTransitionMs)ms"
            : "steady_state"
        let entry = "[+\(elapsedMs)ms] [\(source)] \(event) (\(transitionTag))\(details.isEmpty ? "" : " | \(details)")"
        appendEntryLocked(entry)
        lock.unlock()

        logger.info("\(entry, privacy: .public)")
    }

    private func appendEntryLocked(_ entry: String) {
        recentEvents.append(entry)
        if recentEvents.count > 120 {
            recentEvents.removeFirst(recentEvents.count - 120)
        }
    }
}

// MARK: - PlaybackService

final class PlaybackService: ObservableObject {

    // MARK: - Storage Keys

    private enum Keys {
        static let backgroundPlaybackEnabled = "backgroundPlaybackEnabled"
    }

    // MARK: - Shared Network & WebKit Optimization Pool

    /// Shared WebKit process pool so DNS, TLS 1.3 / HTTP3 QUIC sessions, and cached
    /// YouTube player scripts (`iframe_api`, `base.js`) persist across the app lifecycle.
    static let sharedProcessPool = WKProcessPool()

    /// Verified HTTPS origin used as `baseURL` and IFrame `origin` parameter so WKWebView
    /// sends a valid third-party `Referer` header and avoids YouTube Error 152-4 / 153.
    static let embedOrigin = "https://lhh224.github.io"
    static let embedBaseURL = URL(string: "https://lhh224.github.io")!

    // MARK: - Published State

    @Published var currentVideo: VideoItem?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isBackgroundPlaybackEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isBackgroundPlaybackEnabled, forKey: Keys.backgroundPlaybackEnabled)
            PlaybackDiagnostics.shared.markLifecycle(
                "setting.backgroundPlaybackChanged",
                details: "enabled=\(isBackgroundPlaybackEnabled)"
            )
        }
    }

    // MARK: - Lifecycle & Interruption State

    private(set) var isUserPaused: Bool = false
    private(set) var isAppInBackground: Bool = false
    private var wasPlayingBeforeInterruption: Bool = false
    private var hasRegisteredObservers: Bool = false
    private var isAudioSessionActive: Bool = false
    private var hasWarmedUpWebKit: Bool = false
    private var lastSyncedMediaSessionVideoId: String?
    private var warmupWebView: WKWebView?
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - Active Player Bridge Callbacks

    var jsCommandExecutor: ((String) -> Void)?
    var onRemotePlay: (() -> Void)?
    var onRemotePause: (() -> Void)?
    var onRemoteNextTrack: (() -> Void)?
    var onRemotePreviousTrack: (() -> Void)?
    var onRemoteSeek: ((TimeInterval) -> Void)?
    var onSelectVideoFromApp: ((VideoItem, [VideoItem]) -> Void)?

    /// Active playback queue used when advancing tracks from Lock Screen or UI.
    var playbackQueue: [VideoItem] = VideoItem.mockItems

    // MARK: - Singleton

    static let shared = PlaybackService()

    private init() {
        if UserDefaults.standard.object(forKey: Keys.backgroundPlaybackEnabled) == nil {
            self.isBackgroundPlaybackEnabled = true
        } else {
            self.isBackgroundPlaybackEnabled = UserDefaults.standard.bool(forKey: Keys.backgroundPlaybackEnabled)
        }
        registerSystemObserversIfNeeded()
    }

    // MARK: - Network & Player Script Pre-Warming

    /// Pre-warms TLS/HTTP3 connections and caches YouTube's `iframe_api` script once at launch.
    @MainActor
    func prewarmNetworkAndPlayerCache() {
        guard !hasWarmedUpWebKit else { return }
        hasWarmedUpWebKit = true

        let config = WKWebViewConfiguration()
        config.processPool = Self.sharedProcessPool
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: config)
        self.warmupWebView = wv

        let prewarmHTML = """
        <!DOCTYPE html><html><head>
        <link rel="preconnect" href="https://www.youtube.com" crossorigin>
        <link rel="preconnect" href="https://i.ytimg.com" crossorigin>
        <link rel="preconnect" href="https://googlevideo.com" crossorigin>
        <script src="https://www.youtube.com/iframe_api" async></script>
        </head><body></body></html>
        """
        wv.loadHTMLString(prewarmHTML, baseURL: Self.embedBaseURL)

        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            self?.warmupWebView = nil
        }
    }

    // MARK: - Public API (HTML & URL Builders)

    /// Builds a clean, single-instance HTML host for the official YouTube IFrame Player API:
    /// - Zero invasive DOM/visibility hacks or competing timers during foreground/background switches.
    /// - Deduplicated `navigator.mediaSession` metadata (set once per track, never per state tick).
    /// - Passive `visibilitychange`, `pagehide`, and `pageshow` telemetry forwarded for diagnostics.
    func buildEmbedHTML(videoId: String, autoplay: Bool = false, initialVideo: VideoItem? = nil) -> String {
        let autoplayValue = autoplay ? 1 : 0
        let metaVideo = initialVideo ?? currentVideo
        let safeTitle = Self.escapeJSString(metaVideo?.title ?? "YT Player")
        let safeArtist = Self.escapeJSString(metaVideo?.channelName ?? "YouTube")
        let safeThumb = Self.escapeJSString(metaVideo?.thumbnailURL ?? "https://i.ytimg.com/vi/\(videoId)/hqdefault.jpg")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <meta name="referrer" content="strict-origin-when-cross-origin">
            <link rel="preconnect" href="https://www.youtube.com" crossorigin>
            <link rel="preconnect" href="https://i.ytimg.com" crossorigin>
            <link rel="preconnect" href="https://googlevideo.com" crossorigin>
            <link rel="dns-prefetch" href="https://static.doubleclick.net">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
                #player { width: 100%; height: 100%; transform: translateZ(0); }
            </style>
        </head>
        <body>
            <div id="player"></div>
            <script>
                var player;
                var shouldAutoplayInitial = (\(autoplayValue) === 1);
                var currentLoadedVideoId = '\(videoId)';
                var lastAppliedMetaKey = '';
                window.__ytUserPaused = false;
                window.__ytMeta = {
                    title: '\(safeTitle)',
                    artist: '\(safeArtist)',
                    thumb: '\(safeThumb)'
                };

                function postToNative(payload) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ytPlayer) {
                        window.webkit.messageHandlers.ytPlayer.postMessage(JSON.stringify(payload));
                    }
                }

                // Deduplicated MediaSession metadata update: ONLY writes to MediaSession when
                // track metadata actually changes, preventing MRMediaRemote re-registration hitches.
                window.__ytUpdateMediaSession = function(title, artist, thumb) {
                    if (title) { window.__ytMeta.title = title; }
                    if (artist) { window.__ytMeta.artist = artist; }
                    if (thumb) { window.__ytMeta.thumb = thumb; }
                    if (!('mediaSession' in navigator) || typeof MediaMetadata === 'undefined') { return; }
                    var nextKey = (window.__ytMeta.title || '') + '|' + (window.__ytMeta.artist || '') + '|' + (window.__ytMeta.thumb || '');
                    if (nextKey === lastAppliedMetaKey) { return; }
                    lastAppliedMetaKey = nextKey;
                    try {
                        navigator.mediaSession.metadata = new MediaMetadata({
                            title: window.__ytMeta.title || 'YT Player',
                            artist: window.__ytMeta.artist || 'YouTube',
                            artwork: window.__ytMeta.thumb ? [
                                { src: window.__ytMeta.thumb, sizes: '480x360', type: 'image/jpeg' }
                            ] : []
                        });
                    } catch (e) {}
                };

                function installMediaSessionHandlers() {
                    if (!('mediaSession' in navigator)) { return; }
                    window.__ytUpdateMediaSession();
                    var actions = {
                        play: function() {
                            window.__ytUserPaused = false;
                            if (player && typeof player.getPlayerState === 'function' && player.getPlayerState() !== 1) {
                                player.playVideo();
                            }
                            postToNative({ event: 'onRemoteCommand', command: 'play' });
                        },
                        pause: function() {
                            window.__ytUserPaused = true;
                            if (player && typeof player.getPlayerState === 'function' && player.getPlayerState() === 1) {
                                player.pauseVideo();
                            }
                            postToNative({ event: 'onRemoteCommand', command: 'pause' });
                        },
                        nexttrack: function() {
                            postToNative({ event: 'onRemoteCommand', command: 'nextTrack' });
                        },
                        previoustrack: function() {
                            postToNative({ event: 'onRemoteCommand', command: 'previousTrack' });
                        },
                        seekto: function(details) {
                            if (details && typeof details.seekTime === 'number' && player && typeof player.seekTo === 'function') {
                                player.seekTo(details.seekTime, true);
                            }
                        }
                    };
                    Object.keys(actions).forEach(function(key) {
                        try { navigator.mediaSession.setActionHandler(key, actions[key]); } catch (e) {}
                    });
                }

                window.__ytSetUserPaused = function(paused) {
                    window.__ytUserPaused = Boolean(paused);
                };

                // Load a different track only when videoId actually differs from the loaded track
                window.__ytLoadTrackIfNeeded = function(nextVideoId) {
                    if (!nextVideoId || !player) { return; }
                    window.__ytUserPaused = false;
                    if (currentLoadedVideoId === nextVideoId) {
                        var st = (typeof player.getPlayerState === 'function') ? player.getPlayerState() : -1;
                        if (st !== 1 && st !== 3 && typeof player.playVideo === 'function') {
                            player.playVideo();
                        }
                        return;
                    }
                    currentLoadedVideoId = nextVideoId;
                    if (typeof player.loadVideoById === 'function') {
                        player.loadVideoById(nextVideoId);
                    }
                };

                // Single gentle autoplay kick on initial ready only if still idle/cued
                window.__ytTriggerAutoplay = function() {
                    setTimeout(function() {
                        if (!player || typeof player.playVideo !== 'function' || window.__ytUserPaused) { return; }
                        var st = (typeof player.getPlayerState === 'function') ? player.getPlayerState() : -1;
                        if (st === 5 || st === -1) {
                            try { player.playVideo(); } catch (e) {}
                        }
                    }, 180);
                };

                // Passive lifecycle diagnostics (zero player mutations during transitions!)
                document.addEventListener('visibilitychange', function() {
                    var st = (player && typeof player.getPlayerState === 'function') ? player.getPlayerState() : -99;
                    var cur = (player && typeof player.getCurrentTime === 'function') ? (player.getCurrentTime() || 0) : 0;
                    postToNative({
                        event: 'onDiagnostic',
                        source: 'webkit_dom',
                        name: 'visibilitychange:' + document.visibilityState,
                        playerState: st,
                        currentTime: cur
                    });
                }, { passive: true });

                window.addEventListener('pagehide', function(ev) {
                    postToNative({
                        event: 'onDiagnostic',
                        source: 'webkit_dom',
                        name: 'pagehide:persisted=' + Boolean(ev && ev.persisted)
                    });
                }, { passive: true });

                window.addEventListener('pageshow', function(ev) {
                    postToNative({
                        event: 'onDiagnostic',
                        source: 'webkit_dom',
                        name: 'pageshow:persisted=' + Boolean(ev && ev.persisted)
                    });
                }, { passive: true });

                var tag = document.createElement('script');
                tag.src = "https://www.youtube.com/iframe_api";
                var firstScriptTag = document.getElementsByTagName('script')[0];
                firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

                function onYouTubeIframeAPIReady() {
                    player = new YT.Player('player', {
                        videoId: '\(videoId)',
                        playerVars: {
                            'autoplay': \(autoplayValue),
                            'rel': 0,
                            'playsinline': 1,
                            'enablejsapi': 1,
                            'modestbranding': 1,
                            'controls': 1,
                            'origin': '\(Self.embedOrigin)'
                        },
                        events: {
                            'onReady': onPlayerReady,
                            'onStateChange': onPlayerStateChange,
                            'onError': onPlayerError
                        }
                    });
                }

                function emitProgressSnapshot(eventName, stateData) {
                    var cur = (player && typeof player.getCurrentTime === 'function') ? (player.getCurrentTime() || 0) : 0;
                    var dur = (player && typeof player.getDuration === 'function') ? (player.getDuration() || 0) : 0;
                    var payload = {
                        event: eventName,
                        currentTime: cur,
                        duration: dur
                    };
                    if (typeof stateData !== 'undefined') {
                        payload.data = stateData;
                    }
                    postToNative(payload);
                }

                function onPlayerReady(event) {
                    installMediaSessionHandlers();
                    var dur = (player && typeof player.getDuration === 'function') ? (player.getDuration() || 0) : 0;
                    postToNative({
                        event: 'onReady',
                        videoId: currentLoadedVideoId,
                        currentTime: 0,
                        duration: dur
                    });
                    if (shouldAutoplayInitial && !window.__ytUserPaused) {
                        window.__ytTriggerAutoplay();
                    }
                }

                function onPlayerStateChange(event) {
                    var state = event.data;
                    if (state === YT.PlayerState.PLAYING) {
                        window.__ytUserPaused = false;
                        if ('mediaSession' in navigator) {
                            try { navigator.mediaSession.playbackState = 'playing'; } catch (e) {}
                        }
                    } else if (state === YT.PlayerState.PAUSED) {
                        if ('mediaSession' in navigator) {
                            try { navigator.mediaSession.playbackState = 'paused'; } catch (e) {}
                        }
                    }
                    emitProgressSnapshot('onStateChange', state);
                }

                function onPlayerError(event) {
                    postToNative({
                        event: 'onError',
                        data: event.data
                    });
                }
            </script>
        </body>
        </html>
        """
    }

    /// Build the embed URL for the given video ID with standard parameters.
    func buildEmbedURL(videoId: String) -> URL? {
        var components = URLComponents(string: "https://www.youtube.com/embed/\(videoId)")
        components?.queryItems = [
            URLQueryItem(name: "rel", value: "0"),
            URLQueryItem(name: "playsinline", value: "1"),
            URLQueryItem(name: "enablejsapi", value: "1"),
            URLQueryItem(name: "modestbranding", value: "1")
        ]
        return components?.url
    }

    // MARK: - Playback State & Lock Screen Sync

    func play(video: VideoItem) {
        let isNewTrack = (currentVideo?.id != video.id)
        currentVideo = video
        isPlaying = true
        isUserPaused = false
        if isNewTrack {
            currentTime = 0
            duration = NowPlayingService.parseDurationSeconds(from: video.duration)
        }
        ensureAudioSessionConfiguredOnce()

        // Only evaluate JS MediaSession update when track ID or title actually changed
        let mediaKey = "\(video.id)|\(video.title)"
        if lastSyncedMediaSessionVideoId != mediaKey {
            lastSyncedMediaSessionVideoId = mediaKey
            let safeTitle = Self.escapeJSString(video.title)
            let safeArtist = Self.escapeJSString(video.channelName)
            let safeThumb = Self.escapeJSString(video.thumbnailURL)
            jsCommandExecutor?("if (window.__ytUpdateMediaSession) { window.__ytUpdateMediaSession('\(safeTitle)', '\(safeArtist)', '\(safeThumb)'); }")
        }

        NowPlayingService.shared.configureRemoteCommands()
        NowPlayingService.shared.updateNowPlaying(
            video: video,
            isPlaying: true,
            elapsedTime: currentTime,
            duration: duration
        )
    }

    func pause(userInitiated: Bool = true) {
        if userInitiated {
            isUserPaused = true
        }
        isPlaying = false
        NowPlayingService.shared.updatePlaybackState(
            isPlaying: false,
            elapsedTime: currentTime,
            duration: duration
        )
    }

    func stop() {
        isPlaying = false
        isUserPaused = true
        currentTime = 0
        duration = 0
        lastSyncedMediaSessionVideoId = nil
        currentVideo = nil
        NowPlayingService.shared.clearNowPlaying()
    }

    func updateProgress(currentTime: TimeInterval, duration: TimeInterval) {
        self.currentTime = max(0, currentTime)
        if duration > 0 {
            self.duration = duration
        }
        NowPlayingService.shared.updatePlaybackState(
            isPlaying: isPlaying,
            elapsedTime: self.currentTime,
            duration: self.duration
        )
    }

    func updateQueue(_ videos: [VideoItem]) {
        guard !videos.isEmpty else { return }
        playbackQueue = videos
    }

    // MARK: - ScenePhase & System Lifecycle Handling (Zero Redundant Commands)

    func recordScenePhase(_ phaseDescription: String) {
        PlaybackDiagnostics.shared.markLifecycle(
            "swiftui.scenePhase.\(phaseDescription)",
            details: "isPlaying=\(isPlaying), userPaused=\(isUserPaused), bgEnabled=\(isBackgroundPlaybackEnabled)"
        )
    }

    // MARK: - Remote Command & Sleep Timer Bridges

    func remotePlay() {
        isUserPaused = false
        ensureAudioSessionConfiguredOnce()
        PlaybackDiagnostics.shared.logPlayerEvent("remotePlay", source: "app_command")
        jsCommandExecutor?("window.__ytSetUserPaused && window.__ytSetUserPaused(false);")
        if let onRemotePlay = onRemotePlay {
            onRemotePlay()
        } else {
            if let video = currentVideo {
                play(video: video)
            }
            jsCommandExecutor?("if (window.player && typeof player.getPlayerState === 'function' && player.getPlayerState() !== 1) { player.playVideo(); }")
        }
    }

    func remotePause() {
        isUserPaused = true
        PlaybackDiagnostics.shared.logPlayerEvent("remotePause", source: "app_command")
        jsCommandExecutor?("window.__ytSetUserPaused && window.__ytSetUserPaused(true);")
        if let onRemotePause = onRemotePause {
            onRemotePause()
        } else {
            pause(userInitiated: true)
            jsCommandExecutor?("if (window.player && typeof player.getPlayerState === 'function' && player.getPlayerState() === 1) { player.pauseVideo(); }")
        }
    }

    func remoteTogglePlayPause() {
        if isPlaying {
            remotePause()
        } else {
            remotePlay()
        }
    }

    func remoteNextTrack() {
        onRemoteNextTrack?()
    }

    func remotePreviousTrack() {
        onRemotePreviousTrack?()
    }

    func remoteSeek(to positionTime: TimeInterval) {
        let clamped = max(0, positionTime)
        currentTime = clamped
        PlaybackDiagnostics.shared.logPlayerEvent("remoteSeek", source: "app_command", details: "to=\(String(format: "%.1f", clamped))s")
        if let onRemoteSeek = onRemoteSeek {
            onRemoteSeek(clamped)
        } else {
            jsCommandExecutor?("if (window.player && typeof player.seekTo === 'function') { player.seekTo(\(clamped), true); }")
        }
        NowPlayingService.shared.updatePlaybackState(
            isPlaying: isPlaying,
            elapsedTime: clamped,
            duration: duration
        )
    }

    // MARK: - System Lifecycle, Background & Interruption Observers

    func registerSystemObserversIfNeeded() {
        guard !hasRegisteredObservers else { return }
        hasRegisteredObservers = true

        NotificationCenter.default
            .publisher(for: Notification.Name("SleepTimerFired"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                PlaybackDiagnostics.shared.markLifecycle("sleepTimer.fired")
                self?.remotePause()
            }
            .store(in: &cancellables)

        #if canImport(UIKit)
        NotificationCenter.default
            .publisher(for: UIApplication.willResignActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleWillResignActive()
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleDidEnterBackground()
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleWillEnterForeground()
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: UIApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleDidBecomeActive()
            }
            .store(in: &cancellables)
        #endif

        #if os(iOS)
        NotificationCenter.default
            .publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleAudioSessionInterruption(notification)
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleAudioRouteChange(notification)
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: AVAudioSession.mediaServicesWereResetNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                PlaybackDiagnostics.shared.markLifecycle("audioSession.mediaServicesWereReset")
                self?.isAudioSessionActive = false
                self?.forceReactivateAudioSession()
                if self?.isPlaying == true && self?.isUserPaused == false {
                    self?.remotePlay()
                }
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - Private Audio Session Management

    /// Configures `.playback` with `.moviePlayback` and `.mixWithOthers` ONCE so UIProcess
    /// and `WebKit.GPU` share the audio session seamlessly without interrupting active streams.
    func ensureAudioSessionConfiguredOnce() {
        guard !isAudioSessionActive else { return }
        forceReactivateAudioSession()
    }

    private func forceReactivateAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try session.setActive(true)
            isAudioSessionActive = true
            PlaybackDiagnostics.shared.markLifecycle("audioSession.activated", details: "category=playback, mode=moviePlayback")
        } catch {
            PlaybackDiagnostics.shared.markLifecycle("audioSession.error", details: error.localizedDescription)
        }
        #endif
    }

    private static func escapeJSString(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    #if canImport(UIKit)
    private func handleWillResignActive() {
        PlaybackDiagnostics.shared.markLifecycle(
            "uiApplication.willResignActive",
            details: "isPlaying=\(isPlaying), userPaused=\(isUserPaused)"
        )
        // Intentionally send ZERO JavaScript commands here so WebKit's audio pipeline
        // is never disturbed during Notification Center / Control Center / app-switcher gestures.
    }

    private func handleDidEnterBackground() {
        isAppInBackground = true
        PlaybackDiagnostics.shared.markLifecycle(
            "uiApplication.didEnterBackground",
            details: "isPlaying=\(isPlaying), userPaused=\(isUserPaused), bgEnabled=\(isBackgroundPlaybackEnabled)"
        )

        guard currentVideo != nil else { return }

        // Only issue a pause command if the user explicitly turned OFF Background Audio in Settings.
        // Otherwise, do NOT poke playVideo()/pauseVideo()/seekTo() — let the active stream run untouched!
        if !isBackgroundPlaybackEnabled && isPlaying {
            pause(userInitiated: false)
            jsCommandExecutor?("if (window.player && typeof player.getPlayerState === 'function' && player.getPlayerState() === 1) { player.pauseVideo(); }")
        }
    }

    private func handleWillEnterForeground() {
        isAppInBackground = false
        PlaybackDiagnostics.shared.markLifecycle(
            "uiApplication.willEnterForeground",
            details: "isPlaying=\(isPlaying), userPaused=\(isUserPaused)"
        )
        // Zero JS bridge calls on foreground entry: WebKit re-attaches its video compositing
        // layer cleanly without playVideo()/seekTo()/metadata re-registration interference,
        // and user-paused videos stay strictly paused.
    }

    private func handleDidBecomeActive() {
        isAppInBackground = false
        PlaybackDiagnostics.shared.markLifecycle(
            "uiApplication.didBecomeActive",
            details: "isPlaying=\(isPlaying), userPaused=\(isUserPaused)"
        )
    }
    #endif

    #if os(iOS)
    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            isAudioSessionActive = false
            wasPlayingBeforeInterruption = isPlaying && !isUserPaused
            PlaybackDiagnostics.shared.markLifecycle(
                "audioSession.interruptionBegan",
                details: "wasPlaying=\(wasPlayingBeforeInterruption)"
            )
            if isPlaying {
                isPlaying = false
            }

        case .ended:
            forceReactivateAudioSession()
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            let shouldResume = options.contains(.shouldResume) && wasPlayingBeforeInterruption && !isUserPaused
            PlaybackDiagnostics.shared.markLifecycle(
                "audioSession.interruptionEnded",
                details: "shouldResume=\(shouldResume), userPaused=\(isUserPaused)"
            )
            wasPlayingBeforeInterruption = false
            if shouldResume {
                remotePlay()
            }

        @unknown default:
            break
        }
    }

    private func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        PlaybackDiagnostics.shared.markLifecycle("audioSession.routeChange", details: "reason=\(reasonValue)")
        if reason == .oldDeviceUnavailable && isPlaying {
            remotePause()
        }
    }
    #endif
}
