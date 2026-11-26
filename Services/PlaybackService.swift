// PlaybackService.swift
// YTPlayer
//
// Manages playback state, background audio persistence (AVAudioSession + silent PCM
// keep-alive + cross-frame WebKit anti-pause), Lock Screen command bridging, and
// YouTube IFrame embed HTML/JS generation with automatic mobile autoplay.

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
            if !isBackgroundPlaybackEnabled {
                stopKeepAliveAudio()
            } else if isPlaying && !isUserPaused {
                startKeepAliveAudioIfNeeded()
            }
        }
    }

    // MARK: - Background & Interruption State

    private(set) var isUserPaused: Bool = false
    private(set) var isAppInBackground: Bool = false
    private var backgroundTransitionDate: Date?
    private var wasPlayingBeforeInterruption: Bool = false
    private var hasRegisteredObservers: Bool = false
    private var cancellables: Set<AnyCancellable> = []

    #if os(iOS)
    /// Ultra-quiet local PCM keep-alive audio player that holds `AVAudioSession(.playback)`
    /// across the ~150ms WebKit screen-lock transition gap and track changes so iOS never
    /// suspends the WebContent process while background playback is active.
    private var keepAliveAudioPlayer: AVAudioPlayer?
    #endif

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

    // MARK: - Anti-Auto-Pause Visibility & Native Video Guard UserScript

    /// JavaScript injected into BOTH the host document and child YouTube embed iframes
    /// (`forMainFrameOnly: false`) to:
    /// 1. Override `document.hidden` (`false`) and `document.visibilityState` (`'visible'`).
    /// 2. Block `visibilitychange`, `webkitvisibilitychange`, `pagehide`, and `freeze` events.
    /// 3. Resume the underlying HTML5 `<video>` element inside the YouTube iframe if WebKit
    ///    involuntarily pauses it during iPhone screen lock / background transition.
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

        ['visibilitychange', 'webkitvisibilitychange', 'pagehide', 'freeze'].forEach(function(evtName) {
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
                if (ev.data.forcePlay === true && !window.__ytAllowNativePause) {
                    var vids = document.getElementsByTagName('video');
                    for (var i = 0; i < vids.length; i++) {
                        if (vids[i].paused && !vids[i].ended) {
                            var p = vids[i].play();
                            if (p && typeof p.catch === 'function') { p.catch(function(){}); }
                        }
                    }
                }
            }
        }, true);

        // Catch involuntary WebKit C++ <video> pause inside YouTube iframe on screen lock
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
                }, 30);
            }
        }, true);
    })();
    """

    // MARK: - Public API (HTML & URL Builders)

    /// Build a fully self-contained HTML page that loads the YouTube IFrame Player API
    /// with mobile autoplay trigger, Page Visibility spoofing, and background pause recovery.
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
                var shouldAutoplayInitial = (\(autoplayValue) === 1);
                window.__ytAppInBackground = false;
                window.__ytBgEnabled = \(bgEnabledLiteral);
                window.__ytUserPaused = false;
                window.__ytBgTransitionAt = 0;
                window.__ytAutoUnmutePending = false;

                function postToNative(payload) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ytPlayer) {
                        window.webkit.messageHandlers.ytPlayer.postMessage(JSON.stringify(payload));
                    }
                }

                function broadcastGuardToChildIframe(forcePlay) {
                    var guardActive = Boolean(window.__ytBgEnabled && (window.__ytAppInBackground || (Date.now() - (window.__ytBgTransitionAt || 0) < 4500)));
                    var allowPause = Boolean(window.__ytUserPaused || !window.__ytBgEnabled);
                    window.__ytBgGuardActive = guardActive;
                    window.__ytAllowNativePause = allowPause;
                    var msg = {
                        __ytSyncGuard: true,
                        bgGuard: guardActive,
                        allowPause: allowPause,
                        forcePlay: Boolean(forcePlay)
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
                    broadcastGuardToChildIframe(inBackground && !window.__ytUserPaused);
                };

                window.__ytSetUserPaused = function(paused) {
                    window.__ytUserPaused = Boolean(paused);
                    broadcastGuardToChildIframe(false);
                };

                window.__ytTriggerAutoplay = function() {
                    if (!player || typeof player.playVideo !== 'function' || window.__ytUserPaused) { return; }
                    try { player.playVideo(); } catch (e) {}
                    setTimeout(function() {
                        if (!window.__ytUserPaused && player && typeof player.getPlayerState === 'function') {
                            var st = player.getPlayerState();
                            if (st !== YT.PlayerState.PLAYING && st !== YT.PlayerState.BUFFERING) {
                                player.playVideo();
                            }
                        }
                    }, 320);
                    setTimeout(function() {
                        if (!window.__ytUserPaused && player && typeof player.getPlayerState === 'function') {
                            var st2 = player.getPlayerState();
                            if (st2 !== YT.PlayerState.PLAYING && st2 !== YT.PlayerState.BUFFERING) {
                                window.__ytAutoUnmutePending = true;
                                if (typeof player.mute === 'function') { player.mute(); }
                                player.playVideo();
                            }
                        }
                    }, 900);
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
                    broadcastGuardToChildIframe(false);
                    postToNative({
                        event: 'onReady',
                        videoId: '\(videoId)',
                        currentTime: 0,
                        duration: dur
                    });
                    // Explicitly invoke playVideo() because YouTube mobile IFrame ignores playerVars.autoplay=1
                    if (shouldAutoplayInitial && !window.__ytUserPaused) {
                        window.__ytTriggerAutoplay();
                    }
                }

                function onPlayerStateChange(event) {
                    var state = event.data;
                    var recentlyBackgrounded = (Date.now() - (window.__ytBgTransitionAt || 0)) < 4500;

                    if (state === YT.PlayerState.PAUSED &&
                        window.__ytBgEnabled &&
                        !window.__ytUserPaused &&
                        (window.__ytAppInBackground || recentlyBackgrounded)) {
                        broadcastGuardToChildIframe(true);
                        if (player && typeof player.playVideo === 'function') {
                            player.playVideo();
                            setTimeout(function() {
                                if (!window.__ytUserPaused && player && typeof player.getPlayerState === 'function' && player.getPlayerState() !== YT.PlayerState.PLAYING) {
                                    broadcastGuardToChildIframe(true);
                                    player.playVideo();
                                }
                            }, 180);
                        }
                        postToNative({
                            event: 'onBackgroundAutoResume',
                            data: state
                        });
                        return;
                    }

                    if (state === YT.PlayerState.PLAYING) {
                        window.__ytUserPaused = false;
                        if (window.__ytAutoUnmutePending) {
                            window.__ytAutoUnmutePending = false;
                            if (player && typeof player.unMute === 'function') {
                                player.unMute();
                                player.setVolume(100);
                            }
                        }
                        broadcastGuardToChildIframe(false);
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
        startKeepAliveAudioIfNeeded()
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
            stopKeepAliveAudio()
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
        stopKeepAliveAudio()
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
           Date().timeIntervalSince(transitionDate) < 4.5 {
            return true
        }
        return false
    }

    /// Forces the YouTube IFrame player & child `<video>` to continue playing if WebKit paused it during screen lock.
    func attemptBackgroundAutoResume() {
        guard shouldAutoResumeInBackground else { return }
        activateAudioSessionIfNeeded()
        startKeepAliveAudioIfNeeded()
        jsCommandExecutor?("window.__ytSetUserPaused && window.__ytSetUserPaused(false); window.__ytSetBackgroundState && window.__ytSetBackgroundState(true, true); if (window.player && typeof player.playVideo === 'function') { player.playVideo(); }")

        for delay in [0.15, 0.45, 1.1, 2.2] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.shouldAutoResumeInBackground else { return }
                self.jsCommandExecutor?("window.__ytSetBackgroundState && window.__ytSetBackgroundState(true, true); if (window.player && typeof player.getPlayerState === 'function' && player.getPlayerState() !== 1) { player.playVideo(); }")
            }
        }
    }

    // MARK: - Remote Command & Sleep Timer Bridges

    func remotePlay() {
        isUserPaused = false
        activateAudioSessionIfNeeded()
        startKeepAliveAudioIfNeeded()
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
        stopKeepAliveAudio()
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
                self?.keepAliveAudioPlayer = nil
                self?.activateAudioSessionIfNeeded()
                if self?.isPlaying == true && self?.isUserPaused == false {
                    self?.remotePlay()
                }
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - Private Audio Session & Keep-Alive Engine

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

    private func startKeepAliveAudioIfNeeded() {
        #if os(iOS)
        guard isBackgroundPlaybackEnabled, !isUserPaused, currentVideo != nil else { return }
        if keepAliveAudioPlayer == nil {
            keepAliveAudioPlayer = Self.buildSilentKeepAlivePlayer()
        }
        if let player = keepAliveAudioPlayer, !player.isPlaying {
            player.play()
        }
        #endif
    }

    private func stopKeepAliveAudio() {
        #if os(iOS)
        if let player = keepAliveAudioPlayer, player.isPlaying {
            player.pause()
        }
        #endif
    }

    #if os(iOS)
    /// Generates a 1-second 8kHz 16-bit mono WAV buffer in memory with +/-2 LSB samples
    /// so iOS `mediaserverd` maintains continuous background execution for our process
    /// during WebKit iframe transitions without producing audible noise.
    private static func buildSilentKeepAlivePlayer() -> AVAudioPlayer? {
        let sampleRate: UInt32 = 8000
        let numSamples: UInt32 = sampleRate
        let dataByteCount: UInt32 = numSamples * 2
        let riffChunkSize: UInt32 = 36 + dataByteCount

        var data = Data(capacity: Int(44 + dataByteCount))
        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        withUnsafeBytes(of: riffChunkSize.littleEndian) { data.append(contentsOf: $0) }
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        withUnsafeBytes(of: UInt32(16).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt16(1).littleEndian) { data.append(contentsOf: $0) }  // PCM
        withUnsafeBytes(of: UInt16(1).littleEndian) { data.append(contentsOf: $0) }  // Mono
        withUnsafeBytes(of: sampleRate.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: (sampleRate * 2).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt16(2).littleEndian) { data.append(contentsOf: $0) }  // Block align
        withUnsafeBytes(of: UInt16(16).littleEndian) { data.append(contentsOf: $0) } // 16-bit
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        withUnsafeBytes(of: dataByteCount.littleEndian) { data.append(contentsOf: $0) }

        for i in 0..<Int(numSamples) {
            let sample: Int16 = (i % 2 == 0) ? 2 : -2
            withUnsafeBytes(of: sample.littleEndian) { data.append(contentsOf: $0) }
        }

        do {
            let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
            player.numberOfLoops = -1
            player.volume = 0.01
            player.prepareToPlay()
            return player
        } catch {
            return nil
        }
    }
    #endif

    private func syncBackgroundFlagToWebView() {
        let inBgLiteral = isAppInBackground ? "true" : "false"
        let bgEnabledLiteral = isBackgroundPlaybackEnabled ? "true" : "false"
        jsCommandExecutor?("if (window.__ytSetBackgroundState) { window.__ytSetBackgroundState(\(inBgLiteral), \(bgEnabledLiteral)); }")
    }

    #if canImport(UIKit)
    private func handleWillEnterBackgroundTransition() {
        backgroundTransitionDate = Date()
        if isBackgroundPlaybackEnabled && currentVideo != nil && !isUserPaused {
            activateAudioSessionIfNeeded()
            startKeepAliveAudioIfNeeded()
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
        activateAudioSessionIfNeeded()
        startKeepAliveAudioIfNeeded()
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

    private func handleDidBecomeActive() {
        isAppInBackground = false
        syncBackgroundFlagToWebView()
    }

    private func beginShortBackgroundTransitionTask() {
        endBackgroundTransitionTask()
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "YTPlayerBackgroundAudioHandoff") { [weak self] in
            self?.endBackgroundTransitionTask()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
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
            stopKeepAliveAudio()
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

        if reason == .oldDeviceUnavailable && isPlaying {
            remotePause()
        }
    }
    #endif
}
