// PlaybackService.swift
// YTPlayer
//
// Manages playback state and builds YouTube IFrame embed content.

import Foundation
import Combine
import WebKit

final class PlaybackService: ObservableObject {

    // MARK: - Published State

    @Published var currentVideo: VideoItem?
    @Published var isPlaying: Bool = false

    // MARK: - Singleton

    static let shared = PlaybackService()
    private init() {}

    // MARK: - Public API

    /// Build a fully self-contained HTML page that loads the YouTube IFrame Player API.
    func buildEmbedHTML(videoId: String, autoplay: Bool = false) -> String {
        let autoplayValue = autoplay ? 1 : 0
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
        </head>
        <body>
            <div id="player"></div>
            <script>
                var tag = document.createElement('script');
                tag.src = "https://www.youtube.com/iframe_api";
                var firstScriptTag = document.getElementsByTagName('script')[0];
                firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);

                var player;

                function postToNative(payload) {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ytPlayer) {
                        window.webkit.messageHandlers.ytPlayer.postMessage(JSON.stringify(payload));
                    }
                }

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
                            'origin': 'https://www.youtube.com'
                        },
                        events: {
                            'onReady': onPlayerReady,
                            'onStateChange': onPlayerStateChange,
                            'onError': onPlayerError
                        }
                    });
                }

                function onPlayerReady(event) {
                    postToNative({
                        event: 'onReady',
                        videoId: '\(videoId)'
                    });
                }

                function onPlayerStateChange(event) {
                    postToNative({
                        event: 'onStateChange',
                        data: event.data
                    });
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

    // MARK: - Playback State Helpers

    func play(video: VideoItem) {
        currentVideo = video
        isPlaying = true
    }

    func pause() {
        isPlaying = false
    }

    func stop() {
        isPlaying = false
        currentVideo = nil
    }
}
