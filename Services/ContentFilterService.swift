// MARK: - ContentFilterService.swift
// YTPlayer — Services/ContentFilterService.swift
// Swift 5.7, iOS 16.0

import Foundation
import WebKit

final class ContentFilterService: ObservableObject {
    static let shared = ContentFilterService()
    
    private let ruleListIdentifier = "YTPlayerWebTrackingProtectionList"
    
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "contentFilterEnabled")
        }
    }
    
    init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "contentFilterEnabled") as? Bool ?? true
    }
    
    // JSON content blocking rules (WKContentRuleList format)
    // Lưu ý: Không chặn doubleclick hay googleads vì YouTube IFrame Player bắt buộc phải tải
    // script kiểm tra instream/ad_status.js (nếu chặn sẽ gây ra mã lỗi YouTube 152-4).
    private var rulesJSON: String {
        """
        [
            {
                "trigger": {
                    "url-filter": ".*(scorecardresearch|quantserve|outbrain|taboola)\\\\.com/.*"
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": ".*",
                    "if-domain": ["*youtube.com", "*googlevideo.com", "*ytimg.com", "*doubleclick.net", "*google.com"]
                },
                "action": {
                    "type": "ignore-previous-rules"
                }
            }
        ]
        """
    }
    
    /// Biên dịch và áp dụng WKContentRuleList vào configuration của WKWebView
    func apply(to configuration: WKWebViewConfiguration) async {
        guard isEnabled else { return }
        do {
            let ruleList = try await compileRuleList()
            if let ruleList = ruleList {
                configuration.userContentController.add(ruleList)
            }
        } catch {
            print("[ContentFilterService] Failed to compile or add rule list: \(error.localizedDescription)")
        }
    }
    
    /// Gỡ bỏ rule list nếu có
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
