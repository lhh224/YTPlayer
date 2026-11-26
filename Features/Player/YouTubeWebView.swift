// MARK: - YouTubeWebView.swift
// YTPlayer — Features/Player/YouTubeWebView.swift
// Swift 5.7, iOS 16.0

import SwiftUI
import WebKit

#if canImport(UIKit)
struct YouTubeWebView: UIViewRepresentable {
    let html: String
    var onPlayerEvent: ((String) -> Void)? = nil
    var commandHandler: ((_ executeJS: @escaping (String) -> Void) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true

        let userContentController = WKUserContentController()

        // Inject Page Visibility override into BOTH main frame and nested YouTube embed iframe
        let visibilityUserScript = WKUserScript(
            source: PlaybackService.visibilityOverrideScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(visibilityUserScript)
        userContentController.add(context.coordinator, name: "ytPlayer")
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        #if os(iOS)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1"
        #endif

        context.coordinator.webView = webView
        context.coordinator.loadedHTML = html

        commandHandler? { [weak webView] js in
            if Thread.isMainThread {
                webView?.evaluateJavaScript(js, completionHandler: nil)
            } else {
                DispatchQueue.main.async {
                    webView?.evaluateJavaScript(js, completionHandler: nil)
                }
            }
        }

        if !ContentFilterService.shared.applySynchronouslyIfReady(to: configuration) {
            Task { @MainActor in
                await ContentFilterService.shared.apply(to: webView.configuration)
            }
        }

        webView.loadHTMLString(html, baseURL: PlaybackService.embedBaseURL)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.loadedHTML != html {
            context.coordinator.loadedHTML = html
            uiView.loadHTMLString(html, baseURL: PlaybackService.embedBaseURL)
        }
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: YouTubeWebView
        weak var webView: WKWebView?
        var loadedHTML: String = ""

        init(_ parent: YouTubeWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "ytPlayer" else { return }
            if let body = message.body as? String {
                parent.onPlayerEvent?(body)
            } else if let dict = message.body as? [String: Any],
                      let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                      let jsonString = String(data: jsonData, encoding: .utf8) {
                parent.onPlayerEvent?(jsonString)
            }
        }
    }
}
#elseif canImport(AppKit)
struct YouTubeWebView: NSViewRepresentable {
    let html: String
    var onPlayerEvent: ((String) -> Void)? = nil
    var commandHandler: ((_ executeJS: @escaping (String) -> Void) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true

        let userContentController = WKUserContentController()
        let visibilityUserScript = WKUserScript(
            source: PlaybackService.visibilityOverrideScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(visibilityUserScript)
        userContentController.add(context.coordinator, name: "ytPlayer")
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.webView = webView
        context.coordinator.loadedHTML = html

        commandHandler? { [weak webView] js in
            if Thread.isMainThread {
                webView?.evaluateJavaScript(js, completionHandler: nil)
            } else {
                DispatchQueue.main.async {
                    webView?.evaluateJavaScript(js, completionHandler: nil)
                }
            }
        }

        if !ContentFilterService.shared.applySynchronouslyIfReady(to: configuration) {
            Task { @MainActor in
                await ContentFilterService.shared.apply(to: webView.configuration)
            }
        }

        webView.loadHTMLString(html, baseURL: PlaybackService.embedBaseURL)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.loadedHTML != html {
            context.coordinator.loadedHTML = html
            nsView.loadHTMLString(html, baseURL: PlaybackService.embedBaseURL)
        }
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: YouTubeWebView
        weak var webView: WKWebView?
        var loadedHTML: String = ""

        init(_ parent: YouTubeWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "ytPlayer" else { return }
            if let body = message.body as? String {
                parent.onPlayerEvent?(body)
            } else if let dict = message.body as? [String: Any],
                      let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                      let jsonString = String(data: jsonData, encoding: .utf8) {
                parent.onPlayerEvent?(jsonString)
            }
        }
    }
}
#endif
