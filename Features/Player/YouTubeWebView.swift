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

        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "ytPlayer")
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black

        context.coordinator.webView = webView
        context.coordinator.loadedHTML = html

        commandHandler? { [weak webView] js in
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        Task { @MainActor in
            await ContentFilterService.shared.apply(to: webView.configuration)
        }

        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.loadedHTML != html {
            context.coordinator.loadedHTML = html
            uiView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
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

        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "ytPlayer")
        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        context.coordinator.webView = webView
        context.coordinator.loadedHTML = html

        commandHandler? { [weak webView] js in
            webView?.evaluateJavaScript(js, completionHandler: nil)
        }

        Task { @MainActor in
            await ContentFilterService.shared.apply(to: webView.configuration)
        }

        webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.loadedHTML != html {
            context.coordinator.loadedHTML = html
            nsView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube.com"))
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
