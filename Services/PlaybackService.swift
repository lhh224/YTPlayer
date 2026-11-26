// PlaybackService.swift
// YTPlayer
//
// Manages playback state, background audio persistence, AVAudioSession interruption
// recovery, Lock Screen command bridging, and YouTube IFrame embed HTML/JS generation.

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

    /// Active playback queue used when advancing tracks from Lock Screen or UI.
    var playbackQueue: [VideoItem] = VideoItem.mockItems

    // MARK: - Singleton

    static let shared = PlaybackService()

    /// Verified HTTPS origin used as `baseURL` and IFrame `origin` parameter so WKWebView
    /// sends a valid third-party `Referer` header and avoids YouTube Error 152-4 / 153.
    static let embedOrigin = "https://lhh224.github.io"
    static let embedBaseURL = URL(string: "https://lhh224.github.io")!

    private init() {
        if UserDefaults.standard.object(forKey: Keys.backgroundPlaybackEnabled) == nil {
            self.isBackgroundPlaybackEnabled = true
        } else {
            self.isBackgroundPlaybackEnabled = UserDefaults.standard.bool(forKey: Keys.backgroundPlaybackEnabled)
        }
        registerSystemObserversIfNeeded()
    }

    // MARK: - Anti-Auto-Pause Visibility Override UserScript

    /// JavaScript injected into both the host document and child YouTube embed iframes
    /// (`forMainFrameOnly: false`) to prevent Page Visibility detection from pausing audio
    /// when locking the iPhone screen or moving the app to the background.
    static let visibilityOverrideScript: String = """
    (function() {
        if (window.__ytVisibilityOverrideInstalled) { return; }
        window.__ytVisibilityOverrideInstalled = true;

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
    })();
    """

    // MARK: - Public API (HTML & URL Builders)

    /// Build a fully self-contained HTML page that loads the YouTube IFrame Player API
    /// with Page Visibility spoofing and automatic background pause recovery.
    func buildEmbedHTML(videoId: String, autoplay: Bool = false) -> String {
        let autoplayValue = autoplay ? 1 : 0
        let bgEnabledLiteral = isBackgroundPlaybackEnabled ? "true" : "false"
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <meta name="referrer" content="strict-origin-when-cross-origin">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { width: 100%; height: 100%; background: #000; overflow: hidden; }
                #player { width: 100%; height: 100%; }
            </style>
            <script>
            \(Self.visibilityOverrideScript)
            </script>
        </head>
        <body>
            <div id="player"></div>
            <script>
                var player;
                var progressInterval = null;
                window.__ytAppInBackground = false;
                window.__ytBgEnabled = \(bgEnabledLiteral);
                window.__ytUserPaused = false;
                window.__ytBgTransitionAt = 0;

                function postToNative(payload) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ytPlayer) {
                        window.webkit.messageHandlers.ytPlayer.postMessage(JSON.stringify(payload));
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
                };

                window.__ytSetUserPaused = function(paused) {
                    window.__ytUserPaused = Boolean(paused);
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

                function startProgressTimer() {
                    if (progressInterval) { clearInterval(progressInterval); }
                    progressInterval = setInterval(function() {
                        if (player && typeof player.getPlayerState === 'function' && player.getPlayerState() === YT.PlayerState.PLAYING) {
                            emitProgressSnapshot('onTimeUpdate');
                        }
                    }, 2000);
                }

                function stopProgressTimer() {
                    if (progressInterval) {
                        clearInterval(progressInterval);
                        progressInterval = null;
                    }
                }

                function onPlayerReady(event) {
                    var dur = (player && typeof player.getDuration === 'function') ? (player.getDuration() || 0) : 0;
                    postToNative({
                        event: 'onReady',
                        videoId: '\(videoId)',
                        currentTime: 0,
                        duration: dur
                    });
                }

                function onPlayerStateChange(event) {
                    var state = event.data;
                    var recentlyBackgrounded = (Date.now() - (window.__ytBgTransitionAt || 0)) < 4000;

                    if (state === YT.PlayerState.PAUSED &&
                        window.__ytBgEnabled &&
                        !window.__ytUserPaused &&
                        (window.__ytAppInBackground || recentlyBackgrounded)) {
                        if (player && typeof player.playVideo === 'function') {
                            player.playVideo();
                            setTimeout(function() {
                                if (!window.__ytUserPaused && player && typeof player.getPlayerState === 'function' && player.getPlayerState() !== YT.PlayerState.PLAYING) {
                                    player.playVideo();
                                }
                            }, 200);
                        }
                        postToNative({
                            event: 'onBackgroundAutoResume',
                            data: state
                        });
                        return;
                    }

                    if (state === YT.PlayerState.PLAYING) {
                        window.__ytUserPaused = false;
                        startProgressTimer();
                    } else if (state === YT.PlayerState.PAUSED || state === YT.PlayerState.ENDED) {
                        stopProgressTimer();
                    }

                    emitProgressSnapshot('onStateChange', state);
                }

                function onPlayerError(event) {
                    stopProgressTimer();
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
        activateAudioSessionIfNeeded()
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

    /// Whether a `YT.PlayerState.PAUSED` event from WebKit was triggered involuntarily
    /// by entering the background / locking the screen rather than user action.
    var shouldAutoResumeInBackground: Bool {
        guard isBackgroundPlaybackEnabled, !isUserPaused else { return false }
        if isAppInBackground { return true }
        if let transitionDate = backgroundTransitionDate,
           Date().timeIntervalSince(transitionDate) < 4.0 {
            return true
        }
        return false
    }

    /// Forces the YouTube IFrame player to continue playing if WebKit paused it during screen lock.
    func attemptBackgroundAutoResume() {
        guard shouldAutoResumeInBackground else { return }
        activateAudioSessionIfNeeded()
        jsCommandExecutor?("window.__ytSetUserPaused && window.__ytSetUserPaused(false); if (window.player && typeof player.playVideo === 'function') { player.playVideo(); }")

        for delay in [0.18, 0.55] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.shouldAutoResumeInBackground else { return }
                self.jsCommandExecutor?("if (window.player && typeof player.getPlayerState === 'function' && player.getPlayerState() !== 1) { player.playVideo(); }")
            }
        }
    }

    // MARK: - Remote Command & Sleep Timer Bridges

    func remotePlay() {
        isUserPaused = false
        activateAudioSessionIfNeeded()
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

        // Sleep Timer integration (works both in foreground and while locked)
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
                self?.activateAudioSessionIfNeeded()
                if self?.isPlaying == true && self?.isUserPaused == false {
                    self?.remotePlay()
                }
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - Private Lifecycle & Audio Session Handlers

    private func activateAudioSessionIfNeeded() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("[PlaybackService] AVAudioSession activation error: \(error.localizedDescription)")
        }
        #endif
    }

    private func syncBackgroundFlagToWebView() {
        let inBgLiteral = isAppInBackground ? "true" : "false"
        let bgEnabledLiteral = isBackgroundPlaybackEnabled ? "true" : "false"
        jsCommandExecutor?("if (window.__ytSetBackgroundState) { window.__ytSetBackgroundState(\(inBgLiteral), \(bgEnabledLiteral)); }")
    }

    #if canImport(UIKit)
    private func handleWillEnterBackgroundTransition() {
        backgroundTransitionDate = Date()
        if isBackgroundPlaybackEnabled && isPlaying && !isUserPaused {
            activateAudioSessionIfNeeded()
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

        guard isPlaying && !isUserPaused else { return }

        beginShortBackgroundTransitionTask()
        activateAudioSessionIfNeeded()
        attemptBackgroundAutoResume()
    }

    private func handleWillEnterForeground() {
        isAppInBackground = false
        syncBackgroundFlagToWebView()
        endBackgroundTransitionTask()

        if isBackgroundPlaybackEnabled && !isUserPaused && currentVideo != nil && isPlaying {
            jsCommandExecutor?("if (window.player && typeof player.getPlayerState === 'function' && player.getPlayerState() !== 1) { player.playVideo(); }")
        }
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
            wasPlayingBeforeInterruption = isPlaying && !isUserPaused
            if isPlaying {
                isPlaying = false
                NowPlayingService.shared.updatePlaybackState(
                    isPlaying: false,
                    elapsedTime: currentTime,
                    duration: duration
                )
            }

        case .ended:
            activateAudioSessionIfNeeded()
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

        // Standard iOS audio behavior: pause when headphones/AirPods are unplugged
        if reason == .oldDeviceUnavailable && isPlaying {
            remotePause()
        }
    }
    #endif
}
