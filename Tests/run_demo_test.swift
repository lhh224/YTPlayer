import Foundation
import Combine
import MediaPlayer

@main
struct DemoTestSuite {
    static var passedTests = 0
    static var failedTests = 0

    static func assertTest(_ condition: Bool, _ name: String, _ details: String = "") {
        if condition {
            passedTests += 1
            print("  ✅ [PASS] \(name) \(details.isEmpty ? "" : "(\(details))")")
        } else {
            failedTests += 1
            print("  ❌ [FAIL] \(name) \(details)")
        }
    }

    static func main() {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("======================================================================")
        print("          🚀 YT PLAYER (iOS & Web) — TOÀN BỘ BÀI KIỂM THỬ             ")
        print("======================================================================")
        print("Môi trường: Swift 5.7.2 | macOS 12.7.6 | Kiến trúc: MVVM + Core Data\n")

        // ---------------------------------------------------------
        // NHÓM 1: KIỂM THỬ DỮ LIỆU & MODELS
        // ---------------------------------------------------------
        print("📦 [SUITE 1/6] Kiểm thử Models, Codable & Formatters")
        let mocks = VideoItem.mockItems
        assertTest(!mocks.isEmpty, "Mock Data không rỗng", "Tổng cộng: \(mocks.count) videos")

        let uniqueIds = Set(mocks.map { $0.id })
        assertTest(uniqueIds.count == mocks.count, "Video ID là duy nhất", "\(uniqueIds.count) IDs")

        let first = mocks[0]
        assertTest(first.formattedViewCount.contains("B") || first.formattedViewCount.contains("views"),
                   "Format lượt xem chuẩn xác", "\(first.viewCount) -> \(first.formattedViewCount)")

        do {
            let data = try JSONEncoder().encode(first)
            let decoded = try JSONDecoder().decode(VideoItem.self, from: data)
            assertTest(decoded.id == first.id && decoded.title == first.title, "JSON Codable Roundtrip", "\(data.count) bytes")
        } catch {
            assertTest(false, "JSON Codable Roundtrip", error.localizedDescription)
        }

        let channel = Channel(id: "UC123", name: "Apple", thumbnailURL: "https://example.com/ch.jpg", subscriberCount: "18.5M")
        assertTest(channel.name == "Apple" && channel.subscriberCount == "18.5M", "Channel Model khởi tạo đúng")

        let searchRes = SearchResult(items: mocks, nextPageToken: "CAUQAA", totalResults: 100)
        assertTest(searchRes.items.count == mocks.count && searchRes.nextPageToken == "CAUQAA", "SearchResult Model phân trang đúng")

        // ---------------------------------------------------------
        // NHÓM 2: KIỂM THỬ XỬ LÝ LỖI (APPERROR)
        // ---------------------------------------------------------
        print("\n🛡️ [SUITE 2/6] Kiểm thử Phân loại & Mô tả Lỗi (AppError)")
        let errors: [(AppError, String)] = [
            (.networkError("Timeout"), "Network error"),
            (.apiError(404, "Not Found"), "404"),
            (.quotaExceeded, "quota"),
            (.noInternet, "internet"),
            (.notFound, "not found"),
            (.invalidResponse, "invalid response"),
            (.unknown, "unknown")
        ]
        for (err, keyword) in errors {
            let desc = err.errorDescription ?? ""
            assertTest(desc.lowercased().contains(keyword.lowercased()), "Mô tả lỗi \(err)", desc)
        }

        // ---------------------------------------------------------
        // NHÓM 3: KIỂM THỬ PLAYBACK & IFRAME GENERATION
        // ---------------------------------------------------------
        print("\n🎬 [SUITE 3/6] Kiểm thử Trình phát nhúng YouTube (PlaybackService)")
        let playback = PlaybackService.shared
        let htmlNormal = playback.buildEmbedHTML(videoId: "dQw4w9WgXcQ", autoplay: false)
        assertTest(htmlNormal.contains("https://www.youtube.com/iframe_api"), "Nhúng YouTube IFrame API script chuẩn")
        assertTest(htmlNormal.contains("'playsinline': 1"), "Cấu hình playsinline=1 (tránh full-screen bắt buộc trên iOS)")
        assertTest(htmlNormal.contains("'enablejsapi': 1"), "Kích hoạt enablejsapi=1 cho cầu nối JavaScript")
        assertTest(htmlNormal.contains("window.webkit.messageHandlers.ytPlayer"), "Cầu nối WKScriptMessageHandler ('ytPlayer')")
        assertTest(htmlNormal.contains("JSON.stringify(payload)"), "Chuẩn hóa JSON.stringify trên JS Bridge")
        assertTest(htmlNormal.contains("'autoplay': 0"), "Cấu hình Autoplay tắt khi autoplay=false")

        let htmlAutoplay = playback.buildEmbedHTML(videoId: "dQw4w9WgXcQ", autoplay: true)
        assertTest(htmlAutoplay.contains("'autoplay': 1"), "Cấu hình Autoplay bật khi autoplay=true")
        assertTest(htmlAutoplay.contains("window.__ytTriggerAutoplay()"), "Tự động kích hoạt playVideo() trong onPlayerReady cho Mobile WebKit")
        assertTest(htmlAutoplay.contains("https://lhh224.github.io"), "Cấu hình embedOrigin hợp lệ tránh lỗi 152-4 trên ESign")
        assertTest(htmlAutoplay.contains("Object.defineProperty(document, 'hidden'") && htmlAutoplay.contains("return false"), "Ghi đè document.hidden luôn trả về false")
        assertTest(htmlAutoplay.contains("Object.defineProperty(document, 'visibilityState'") && htmlAutoplay.contains("return 'visible'"), "Ghi đè document.visibilityState luôn trả về 'visible'")
        assertTest(htmlAutoplay.contains("stopImmediatePropagation"), "Chặn lan truyền sự kiện visibilitychange bằng stopImmediatePropagation()")
        assertTest(htmlAutoplay.contains("state === YT.PlayerState.PAUSED") && htmlAutoplay.contains("player.playVideo()"), "Tự động gọi lại player.playVideo() khi bị auto-pause trong nền")
        assertTest(htmlAutoplay.contains("__ytSyncGuard") && htmlAutoplay.contains("target.tagName === 'VIDEO'"), "Bảo vệ trực tiếp thẻ <video> trong iframe con khi khóa màn hình")

        // Kiểm thử NowPlayingService & đồng bộ Lock Screen / SleepTimer
        assertTest(NowPlayingService.parseDurationSeconds(from: "4:15") == 255, "Chuyển đổi thời lượng 4:15 -> 255s cho Lock Screen")
        assertTest(NowPlayingService.parseDurationSeconds(from: "1:02:05") == 3725, "Chuyển đổi thời lượng 1:02:05 -> 3725s cho Lock Screen")
        assertTest(NowPlayingService.parseDurationSeconds(from: "LIVE") == 0, "Xử lý livestream LIVE -> 0s")

        playback.play(video: first)
        assertTest(playback.isPlaying && playback.currentVideo?.id == first.id, "PlaybackService kích hoạt trạng thái đang phát")
        let npTitle = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String
        let npArtist = MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyArtist] as? String
        assertTest(npTitle == first.title && npArtist == first.channelName, "MPNowPlayingInfoCenter cập nhật tên bài hát & kênh lên Lock Screen")

        NotificationCenter.default.post(name: Notification.Name("SleepTimerFired"), object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        assertTest(!playback.isPlaying && playback.isUserPaused, "SleepTimerFired tự động tạm dừng PlaybackService và đánh dấu userPaused")
        playback.stop()

        // ---------------------------------------------------------
        // NHÓM 4: KIỂM THỬ HẸN GIỜ TẮT (SLEEP TIMER SERVICE)
        // ---------------------------------------------------------
        print("\n⏰ [SUITE 4/6] Kiểm thử Hẹn giờ tắt (SleepTimerService)")
        let timer = SleepTimerService.shared
        assertTest(!timer.isActive, "Trạng thái ban đầu: Không hoạt động")

        timer.start(minutes: 30)
        assertTest(timer.isActive == true, "Kích hoạt hẹn giờ 30 phút thành công")
        assertTest(timer.remainingSeconds == 1800, "Đúng 1800 giây", "\(timer.remainingSeconds)s")
        assertTest(timer.remainingFormatted == "30:00", "Định dạng chuỗi hiển thị đúng", timer.remainingFormatted)

        timer.cancel()
        assertTest(!timer.isActive, "Hủy hẹn giờ thành công")
        assertTest(timer.remainingSeconds == 0, "Reset số giây còn lại về 0")

        // ---------------------------------------------------------
        // NHÓM 5: KIỂM THỬ YOUTUBE DATA API ENDPOINTS
        // ---------------------------------------------------------
        print("\n🌐 [SUITE 5/6] Kiểm thử YouTube API Endpoints & URL Assembly")
        let searchEp = YouTubeEndpoint.search(query: "SwiftUI iOS tutorial 2026", pageToken: "PAGE2", apiKey: "TEST_KEY_AIza")
        let searchUrl = searchEp.url!
        assertTest(searchUrl.host == "www.googleapis.com", "API Host chính xác (googleapis.com)")
        assertTest(searchUrl.path == "/youtube/v3/search", "Path chính xác (/youtube/v3/search)")
        assertTest(searchUrl.query?.contains("pageToken=PAGE2") == true, "Hỗ trợ phân trang pageToken")
        assertTest(searchUrl.query?.contains("key=TEST_KEY_AIza") == true, "Truyền API Key chuẩn xác")

        let trendEp = YouTubeEndpoint.trending(regionCode: "VN", apiKey: "TEST_KEY_AIza")
        let trendUrl = trendEp.url!
        assertTest(trendUrl.query?.contains("chart=mostPopular") == true, "Truy vấn Most Popular Videos")
        assertTest(trendUrl.query?.contains("regionCode=VN") == true, "Lọc theo khu vực Việt Nam (VN)")

        let detailEp = YouTubeEndpoint.videoDetail(videoId: "kJQP7kiw5Fk", apiKey: "TEST_KEY_AIza")
        let detailUrl = detailEp.url!
        assertTest(detailUrl.query?.contains("id=kJQP7kiw5Fk") == true, "Lấy thông tin chi tiết đúng videoId")

        // ---------------------------------------------------------
        // NHÓM 6: KIỂM THỬ YOUTUBE FORMATTERS & API SERVICE MỚI
        // ---------------------------------------------------------
        print("\n🔧 [SUITE 6/6] Kiểm thử YouTubeFormatters & YouTubeAPIService")
        assertTest(YouTubeFormatters.parseISO8601Duration("PT4M13S") == "4:13", "Giải mã ISO-8601 PT4M13S -> 4:13")
        assertTest(YouTubeFormatters.parseISO8601Duration("PT1H2M5S") == "1:02:05", "Giải mã ISO-8601 PT1H2M5S -> 1:02:05")
        assertTest(YouTubeFormatters.parseISO8601Duration("P0D") == "LIVE", "Giải mã livestream P0D -> LIVE")
        assertTest(YouTubeFormatters.decodeHTMLEntities("S&#39;ơn &amp; &quot;MV&quot;") == "S'ơn & \"MV\"", "Giải mã HTML Entities tiêu đề YouTube")
        assertTest(YouTubeFormatters.extractVideoID(from: "https://www.youtube.com/watch?v=Llw9Q6akRo4") == "Llw9Q6akRo4", "Tách Video ID từ link youtube.com/watch")
        assertTest(YouTubeFormatters.extractVideoID(from: "https://youtu.be/dQw4w9WgXcQ") == "dQw4w9WgXcQ", "Tách Video ID từ link rút gọn youtu.be")

        let duration = String(format: "%.3f", CFAbsoluteTimeGetCurrent() - startTime)
        print("\n======================================================================")
        print("📊 TỔNG KẾT BÀI KIỂM THỬ:")
        print("   - Tổng số ca kiểm thử: \(passedTests + failedTests)")
        print("   - Thành công:         \(passedTests) ✅")
        print("   - Thất bại:           \(failedTests) ❌")
        print("   - Thời gian thực thi: \(duration) giây")
        print("   - Tỷ lệ hoàn thành:   \(Int(Double(passedTests) / Double(passedTests + failedTests) * 100))%")
        print("======================================================================")

        if failedTests > 0 {
            exit(1)
        } else {
            print("🎉 TẤT CẢ CÁC BÀI TEST ĐỀU ĐẠT CHUẨN 100%! HỆ THỐNG SẴN SÀNG.")
        }
    }
}
