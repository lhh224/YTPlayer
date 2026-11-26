// MARK: - ContentFilterService.swift
// YTPlayer — Services/ContentFilterService.swift
// Swift 5.7, iOS 16.0

import Foundation
import WebKit

final class ContentFilterService: ObservableObject {
    static let shared = ContentFilterService()

    private let ruleListIdentifier = "YTPlayerWebTrackingProtectionListV2"
    private var cachedRuleList: WKContentRuleList?

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "contentFilterEnabled")
            if isEnabled && cachedRuleList == nil {
                preload()
            }
        }
    }

    init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "contentFilterEnabled") as? Bool ?? true
        if self.isEnabled {
            preload()
        }
    }

    // JSON content blocking rules (WKContentRuleList format)
    // Chặn các mạng theo dõi & quảng cáo web bên thứ ba phổ biến, đồng thời giữ nguyên
    // hạ tầng phát của YouTube (youtube.com, googlevideo.com, ytimg.com, doubleclick.net)
    // để tuân thủ YouTube ToS và không gây mã lỗi 152-4 trên các MV bản quyền.
    private var rulesJSON: String {
        """
        [
            {
                "trigger": {
                    "url-filter": ".*(scorecardresearch|quantserve|outbrain|taboola|criteo|adnxs|rubiconproject|pubmatic|openx)\\\\.(com|net)/.*"
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": ".*",
                    "if-domain": ["*youtube.com", "*youtube-nocookie.com", "*googlevideo.com", "*ytimg.com", "*doubleclick.net", "*google.com"]
                },
                "action": {
                    "type": "ignore-previous-rules"
                }
            }
        ]
        """
    }

    /// Biên dịch sẵn rule list vào bộ nhớ đệm ngay khi khởi động app để gắn đồng bộ vào WKWebView.
    func preload() {
        guard isEnabled else { return }
        Task { @MainActor in
            if let list = try? await compileRuleList() {
                self.cachedRuleList = list
            }
        }
    }

    /// Gắn ngay lập tức rule list đã biên dịch sẵn trước khi `WKWebView` bắt đầu tải trang.
    @MainActor
    func applySynchronouslyIfReady(to configuration: WKWebViewConfiguration) -> Bool {
        guard isEnabled, let cachedRuleList = cachedRuleList else { return false }
        configuration.userContentController.add(cachedRuleList)
        return true
    }

    /// Biên dịch và áp dụng WKContentRuleList vào configuration của WKWebView.
    @MainActor
    func apply(to configuration: WKWebViewConfiguration) async {
        guard isEnabled else { return }
        if let cachedRuleList = cachedRuleList {
            configuration.userContentController.add(cachedRuleList)
            return
        }
        do {
            if let ruleList = try await compileRuleList() {
                self.cachedRuleList = ruleList
                configuration.userContentController.add(ruleList)
            }
        } catch {
            print("[ContentFilterService] Failed to compile or add rule list: \(error.localizedDescription)")
        }
    }

    /// Gỡ bỏ rule list nếu có.
    func remove(from configuration: WKWebViewConfiguration) {
        configuration.userContentController.removeAllContentRuleLists()
    }

    private func compileRuleList() async throws -> WKContentRuleList? {
        return try await withCheckedThrowingContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: ruleListIdentifier,
                encodedContentRuleList: rulesJSON
            ) { ruleList, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ruleList)
                }
            }
        }
    }
}
