// PlaybackService.swift
// YTPlayer
//
// Manages playback state, shared WebKit connection/cache pool, background audio
// persistence, WebKit MediaSession Lock Screen integration, and YouTube IFrame HTML.

import Foundation
import Combine
import WebKit
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

final class PlaybackService: ObservableObject {

    // MARK: - Storage Keys

    private enum Keys {
        static let backgroundPlaybackEnabled = "backgroundPlaybackEnabled"
    }

    // MARK: - Shared Network & WebKit Optimization Pool

    /// Shared WebKit process pool so DNS, TLS 1.3 / HTTP3 QUIC sessions, and cached
    /// YouTube player scripts (`iframe_api`, `base.js`) persist across video opens.
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
            syncBackgroundFlagToWebView()
        }
    }

    // MARK: - Background & Interruption State

    private(set) var isUserPaused: Bool = false
    private(set) var isAppInBackground: Bool = false
    private var backgroundTransitionDate: Date?
    private var wasPlayingBeforeInterruption: Bool = false
    private var hasRegisteredObservers: Bool = false
    private var isAudioSessionActive: Bool = false
    private var hasWarmedUpWebKit: Bool = false
    private var warmupWebView: WKWebView?
    private var cancellables: Set<AnyCancellable> = []

    #if canImport(UIKit)
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    #endif

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

    /// Pre-warms TLS/HTTP3 connections and caches YouTube's `iframe_api` script at app launch
    /// so opening the first video starts almost instantaneously without cold-start buffering.
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

        // Release temporary warmup view once scripts/connections are cached in sharedProcessPool
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
            self?.warmupWebView = nil
        }
    }

    // MARK: - Anti-Auto-Pause Visibility Override UserScript

    /// JavaScript injected into BOTH the host document and child YouTube embed iframes
    /// (`forMainFrameOnly: false`) to prevent Page Visibility detection from pausing audio
    /// when locking the iPhone screen or moving the app to the background.
    static let visibilityOverrideScript: String = """
    (function() {
        if (window.__ytVisibilityOverrideInstalled) { return; }
        window.__ytVisibilityOverrideInstalled = true;

        window.__ytBgGuardActive = false;
        window.__ytAllowNativePause = true;

        try {
            Object.defineProperty(document, 'hidden', {
                configurable: true,
                get: function() { return false; }
            });
            Object.defineProperty(document, 'visibilityState', {
                configurable: true,
                get: function() { return 'visible'; }
            });
            Object.defineProperty(document, 'webkitHidden', {
                configurable: true,
                get: function() { return false; }
            });
            Object.defineProperty(document, 'webkitVisibilityState', {
                configurable: true,
                get: function() { return 'visible'; }
            });
        } catch (e) {}

        var stopVisibilityPropagation = function(event) {
            if (event && typeof event.stopImmediatePropagation === 'function') {
                event.stopImmediatePropagation();
            }
            if (event && typeof event.stopPropagation === 'function') {
                event.stopPropagation();
            }
        };

        ['visibilitychange', 'webkitvisibilitychange'].forEach(function(evtName) {
            window.addEventListener(evtName, stopVisibilityPropagation, true);
            document.addEventListener(evtName, stopVisibilityPropagation, true);
        });

        var origDocAdd = Document.prototype.addEventListener;
        Document.prototype.addEventListener = function(type, listener, options) {
            if (type === 'visibilitychange' || type === 'webkitvisibilitychange') {
                return;
            }
            return origDocAdd.call(this, type, listener, options);
        };

        // Synchronize background guard state between host frame and YouTube embed iframe
        window.addEventListener('message', function(ev) {
            if (!ev || !ev.data || typeof ev.data !== 'object') { return; }
            if (ev.data.__ytSyncGuard === true) {
                window.__ytBgGuardActive = Boolean(ev.data.bgGuard);
                window.__ytAllowNativePause = Boolean(ev.data.allowPause);
                if (ev.data.forcePlay === true && window.__ytBgGuardActive && !window.__ytAllowNativePause) {
                    var vids = document.getElementsByTagName('video');
                    for (var i = 0; i < vids.length; i++) {
                        if (vids[i].paused && !vids[i].ended && vids[i].readyState >= 2) {
                            var p = vids[i].play();
                            if (p && typeof p.catch === 'function') { p.catch(function(){}); }
                        }
                    }
                }
            }
        }, true);

        // Resume underlying HTML5 <video> inside YouTube iframe ONLY if WebKit auto-paused on screen lock
        document.addEventListener('pause', function(ev) {
            var target = ev && ev.target;
            if (target && target.tagName === 'VIDEO' &&
                window.__ytBgGuardActive &&
                !window.__ytAllowNativePause &&
                !target.ended) {
                setTimeout(function() {
                    if (window.__ytBgGuardActive && !window.__ytAllowNativePause && target.paused && !target.ended) {
                        var p = target.play();
                        if (p && typeof p.catch === 'function') { p.catch(function(){}); }
                    }
                }, 120);
            }
        }, true);
    })();
    """

    // MARK: - Public API (HTML & URL Builders)

    /// Build a fully self-contained HTML page that loads the YouTube IFrame Player API
    /// with preconnect hints, native WebKit `navigator.mediaSession` Lock Screen integration
    /// (avoiding UIProcess/WebKit.GPU NowPlaying conflicts!), and smooth adaptive streaming.
    func buildEmbedHTML(videoId: String, autoplay: Bool = false, initialVideo: VideoItem? = nil) -> String {
        let autoplayValue = autoplay ? 1 : 0
        let bgEnabledLiteral = isBackgroundPlaybackEnabled ? "true" : "false"
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
            <script>
            \(Self.visibilityOverrideScript)
            </script>
        </head>
        <body>
            <div id="player"></div>
            <script>
                var player;
                var shouldAutoplayInitial = (\(autoplayValue) === 1);
                window.__ytAppInBackground = false;
                window.__ytBgEnabled = \(bgEnabledLiteral);
                window.__ytUserPaused = false;
                window.__ytBgTransitionAt = 0;
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

                // Native WebKit MediaSession integration: runs directly inside WebKit's media
                // process so Lock Screen & Control Center never conflict with WKWebView audio!
                window.__ytUpdateMediaSession = function(title, artist, thumb) {
                    if (title) { window.__ytMeta.title = title; }
                    if (artist) { window.__ytMeta.artist = artist; }
                    if (thumb) { window.__ytMeta.thumb = thumb; }
                    if (!('mediaSession' in navigator) || typeof MediaMetadata === 'undefined') { return; }
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
                            window.__ytSetUserPaused(false);
                            if (player && typeof player.playVideo === 'function') { player.playVideo(); }
                            postToNative({ event: 'onRemoteCommand', command: 'play' });
                        },
                        pause: function() {
                            window.__ytSetUserPaused(true);
                            if (player && typeof player.pauseVideo === 'function') { player.pauseVideo(); }
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

                function broadcastGuardToChildIframe(forcePlay) {
                    var guardActive = Boolean(window.__ytBgEnabled && window.__ytAppInBackground);
                    var allowPause = Boolean(window.__ytUserPaused || !window.__ytBgEnabled || !window.__ytAppInBackground);
                    window.__ytBgGuardActive = guardActive;
                    window.__ytAllowNativePause = allowPause;
                    var msg = {
                        __ytSyncGuard: true,
                        bgGuard: guardActive,
                        allowPause: allowPause,
                        forcePlay: Boolean(forcePlay && guardActive && !allowPause)
                    };
                    var iframes = document.getElementsByTagName('iframe');
                    for (var i = 0; i < iframes.length; i++) {
                        try {
                            if (iframes[i].contentWindow) {
                                iframes[i].contentWindow.postMessage(msg, '*');
                            }
                        } catch (e) {}
                    }
                }

                window.__ytSetBackgroundState = function(inBackground, bgEnabled) {
                    window.__ytAppInBackground = Boolean(inBackground);
                    if (typeof bgEnabled === 'boolean') {
                        window.__ytBgEnabled = bgEnabled;
                    }
                    if (inBackground) {
                        window.__ytBgTransitionAt = Date.now();
                    }
                    broadcastGuardToChildIframe(false);
                };

                window.__ytSetUserPaused = function(paused) {
                    window.__ytUserPaused = Boolean(paused);
                    broadcastGuardToChildIframe(false);
                };

                // Non-disruptive autoplay: waits 180ms to let YouTube's own autoplay start first,
                // and ONLY calls playVideo() if the player is still sitting idle in CUED (5) or UNSTARTED (-1).
                window.__ytTriggerAutoplay = function() {
                    setTimeout(function() {
                        if (!player || typeof player.playVideo !== 'function' || window.__ytUserPaused) { return; }
                        var st = (typeof player.getPlayerState === 'function') ? player.getPlayerState() : -1;
                        if (st === 5 || st === -1) {
                            try { player.playVideo(); } catch (e) {}
                        }
                    }, 180);
                };

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
                    try {
                        if (player && typeof player.setPlaybackQualityRange === 'function') {
                            player.setPlaybackQualityRange('default', 'hd1080');
                        }
                    } catch (e) {}
                    var dur = (player && typeof player.getDuration === 'function') ? (player.getDuration() || 0) : 0;
                    postToNative({
                        event: 'onReady',
                        videoId: '\(videoId)',
                        currentTime: 0,
                        duration: dur
                    });
                    if (shouldAutoplayInitial && !window.__ytUserPaused) {
                        window.__ytTriggerAutoplay();
                    }
                }

                function onPlayerStateChange(event) {
                    var state = event.data;
                    var recentlyBackgrounded = (Date.now() - (window.__ytBgTransitionAt || 0)) < 3500;

                    if (state === YT.PlayerState.PAUSED &&
                        window.__ytBgEnabled &&
                        !window.__ytUserPaused &&
                        (window.__ytAppInBackground || recentlyBackgrounded)) {
                        broadcastGuardToChildIframe(true);
                        if (player && typeof player.playVideo === 'function') {
                            player.playVideo();
                        }
                        postToNative({
                            event: 'onBackgroundAutoResume',
                            data: state
                        });
                        return;
                    }

                    if (state === YT.PlayerState.PLAYING) {
                        window.__ytUserPaused = false;
                        window.__ytUpdateMediaSession();
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

        // Push metadata into WebKit's native navigator.mediaSession so Lock Screen shows
        // song title, channel, and artwork WITHOUT fighting WebKit.GPU's audio session!
        let safeTitle = Self.escapeJSString(video.title)
        let safeArtist = Self.escapeJSString(video.channelName)
        let safeThumb = Self.escapeJSString(video.thumbnailURL)
        jsCommandExecutor?("if (window.__ytUpdateMediaSession) { window.__ytUpdateMediaSession('\(safeTitle)', '\(safeArtist)', '\(safeThumb)'); }")

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

    var shouldAutoResumeInBackground: Bool {
        guard isBackgroundPlaybackEnabled, !isUserPaused else { return false }
        if isAppInBackground { return true }
        if let transitionDate = backgroundTransitionDate,
           Date().timeIntervalSince(transitionDate) < 3.5 {
            return true
        }
        return false
    }

    func attemptBackgroundAutoResume() {
        guard shouldAutoResumeInBackground else { return }
        ensureAudioSessionConfiguredOnce()
        jsCommandExecutor?("window.__ytSetUserPaused && window.__ytSetUserPaused(false); window.__ytSetBackgroundState && window.__ytSetBackgroundState(true, true); if (window.player && typeof player.getPlayerState === 'function' && player.getPlayerState() === 2) { player.playVideo(); }")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self = self, self.shouldAutoResumeInBackground else { return }
            self.jsCommandExecutor?("if (window.player && typeof player.getPlayerState === 'function' && player.getPlayerState() === 2) { player.playVideo(); }")
        }
    }

    // MARK: - Remote Command & Sleep Timer Bridges

    func remotePlay() {
        isUserPaused = false
        ensureAudioSessionConfiguredOnce()
        jsCommandExecutor?("window.__ytSetUserPaused && window.__ytSetUserPaused(false);")
        if let onRemotePlay = onRemotePlay {
            onRemotePlay()
        } else {
            if let video = currentVideo {
                play(video: video)
            }
            jsCommandExecutor?("if (window.player && typeof player.playVideo === 'function') { player.playVideo(); }")
        }
    }

    func remotePause() {
        isUserPaused = true
        jsCommandExecutor?("window.__ytSetUserPaused && window.__ytSetUserPaused(true);")
        if let onRemotePause = onRemotePause {
            onRemotePause()
        } else {
            pause(userInitiated: true)
            jsCommandExecutor?("if (window.player && typeof player.pauseVideo === 'function') { player.pauseVideo(); }")
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
                self?.remotePause()
            }
            .store(in: &cancellables)

        #if canImport(UIKit)
        NotificationCenter.default
            .publisher(for: UIApplication.willResignActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleWillEnterBackgroundTransition()
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
    /// and `WebKit.GPU` share the audio session harmoniously without ever pausing `<video>`.
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
        } catch {
            print("[PlaybackService] AVAudioSession activation error: \(error.localizedDescription)")
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

    private func syncBackgroundFlagToWebView() {
        let inBgLiteral = isAppInBackground ? "true" : "false"
        let bgEnabledLiteral = isBackgroundPlaybackEnabled ? "true" : "false"
        jsCommandExecutor?("if (window.__ytSetBackgroundState) { window.__ytSetBackgroundState(\(inBgLiteral), \(bgEnabledLiteral)); }")
    }

    #if canImport(UIKit)
    private func handleWillEnterBackgroundTransition() {
        backgroundTransitionDate = Date()
        if isBackgroundPlaybackEnabled && currentVideo != nil && !isUserPaused {
            jsCommandExecutor?("if (window.__ytSetBackgroundState) { window.__ytSetBackgroundState(true, true); }")
        }
    }

    private func handleDidEnterBackground() {
        isAppInBackground = true
        backgroundTransitionDate = Date()
        syncBackgroundFlagToWebView()

        guard currentVideo != nil else { return }

        if !isBackgroundPlaybackEnabled {
            if isPlaying {
                remotePause()
            }
            return
        }

        guard !isUserPaused else { return }

        beginShortBackgroundTransitionTask()
        attemptBackgroundAutoResume()
    }

    private func handleWillEnterForeground() {
        isAppInBackground = false
        syncBackgroundFlagToWebView()
        endBackgroundTransitionTask()
    }

    private func handleDidBecomeActive() {
        isAppInBackground = false
        syncBackgroundFlagToWebView()
    }

    private func beginShortBackgroundTransitionTask() {
        endBackgroundTransitionTask()
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "YTPlayerBackgroundAudioHandoff") { [weak self] in
            self?.endBackgroundTransitionTask()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
            self?.endBackgroundTransitionTask()
        }
    }

    private func endBackgroundTransitionTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
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
            if isPlaying {
                isPlaying = false
            }

        case .ended:
            forceReactivateAudioSession()
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if (options.contains(.shouldResume) || wasPlayingBeforeInterruption) && !isUserPaused {
                wasPlayingBeforeInterruption = false
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

        if reason == .oldDeviceUnavailable && isPlaying {
            remotePause()
        }
    }
    #endif
}
