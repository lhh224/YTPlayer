# PROGRESS — YT Player

**Dự án:** YT Player  
**Bắt đầu:** 2026-11-20  
**Cập nhật hoàn thiện:** 2026-11-27  
**Trạng thái toàn diện:** ✅ Đã hoàn thiện bản `2.2.1 (Build 8)`: Khắc phục triệt để hiện tượng khựng âm thanh/video khi chuyển foreground/background trên cả Native SwiftUI/`WKWebView` và `web_preview`, duy trì duy nhất một instance `YT.Player` xuyên suốt vòng đời ứng dụng, tích hợp `PlaybackDiagnostics` (`os.Logger`), Floating Capsule Tab Bar chuẩn YouTube iOS, đồng bộ biên dịch 100% (41/41 file Swift).

---

## Bảng tổng hợp các giai đoạn

| Giai đoạn | Nội dung | Trạng thái | Ghi chú |
|---|---|:---:|---|
| **Giai đoạn 0** | Kiểm tra môi trường (macOS, Xcode, Swift, Disk, CPU) | ✅ Hoàn thành | macOS 12.7.6, Swift 5.7.2. Hỗ trợ chạy trực tiếp Web App hoặc mở Xcode 14.2. |
| **Giai đoạn 1** | Phân tích & Tài liệu kiến trúc | ✅ Hoàn thành | Đầy đủ tài liệu kiến trúc, AGENT_RULES, BUG_LOG. |
| **Giai đoạn 2** | UI/UX & Design System | ✅ Hoàn thành | Đồng bộ Color tokens, Font tokens, Spacing, CornerRadius cho cả Dark/Light Mode. |
| **Giai đoạn 3** | Nền tảng ứng dụng (MVVM, Navigation, Core Data) | ✅ Hoàn thành | Models, AppRouter, CoreDataStack, LibraryRepository (CRUD đầy đủ cho Favorites & History). |
| **Giai đoạn 4** | YouTube Data API v3 integration | ✅ Hoàn thành | Tìm kiếm + lấy thời lượng ISO-8601 & lượt xem, phân trang, cấu hình & test API Key trực tiếp trong Cài đặt, hỗ trợ dán link YouTube trực tiếp. |
| **Giai đoạn 5** | Trình phát nội dung (YouTube Playback) | ✅ Hoàn thành | PlaybackService, YouTubeWebView + IFrame API, JS Bridge chuẩn JSON, Mini Player (trên Web App). |
| **Giai đoạn 6** | Thư viện & Tính năng nâng cao | ✅ Hoàn thành | LibraryView (Favorites & Watch History lưu bền vững), SleepTimer đếm ngược thực tế tự dừng phát. |
| **Giai đoạn 7** | Lọc nội dung & Bảo vệ (Content Filtering) | ✅ Hoàn thành | ContentFilterService gắn trực tiếp vào WKWebView & tùy chọn nhúng bảo mật `youtube-nocookie`. |
| **Giai đoạn 8** | Kiểm thử biên dịch toàn diện & Đóng gói | ✅ Hoàn thành | `swiftc -typecheck` 39/39 file Swift đạt 0 lỗi, 39/39 bài kiểm thử tự động đạt 100%, sửa sạch đường dẫn `YTPlayer.xcodeproj`. |
| **Giai đoạn 9** | Cài đặt v2.1.0, Giữ phiên MediaSession & iOS Profile | ✅ Hoàn thành | Giao diện Cài đặt v2.1.0 đầy đủ chức năng thật (Background Play keep-alive, Chế độ mở mặc định, Tự phát tiếp, Chất lượng phát, Hẹn giờ 15p-60p, Đo & xóa bộ nhớ đệm thật) + triển khai lên Profile App iPhone (`YTPlayer.mobileconfig` / GitHub Pages). |
| **Giai đoạn 10** | Phát nhạc trong nền Native iOS (Background Audio & Lock Screen) | ✅ Hoàn thành | Cấu hình `UIBackgroundModes: audio` (`Info.plist` & `YTPlayer.xcodeproj`), kích hoạt `AVAudioSession (.playback)` + keep-alive PCM, Autoplay mobile, Mini Player cố định, `NowPlayingService` (`MPNowPlayingInfoCenter` + `MPRemoteCommandCenter`), ẩn khóa API khỏi Cài đặt (nạp tự động từ `Config/APIKeys.plist` / thiết lập 1 lần) và đồng bộ thanh âm lượng trực tiếp với phần cứng iPhone (`MPVolumeView`). |
| **Giai đoạn 11** | Đề xuất cá nhân hóa, Lịch sử tìm kiếm & Floating Capsule Tab Bar | ✅ Hoàn thành | Sửa triệt để xung đột `MRMediaRemote`, tối ưu đường truyền `WKProcessPool`/preconnect, tự động tải API đề xuất theo thói quen xem, lịch sử tìm kiếm kiểu YouTube và thiết kế mới `FloatingTabBar` (`#1C1C1E` 95%, capsule chọn `#48484A` trượt `matchedGeometryEffect` + Spring, icon vector custom Thư viện, giữ nguyên trạng thái tab & `WKWebView`). |
| **Giai đoạn 12** | Khắc phục khựng nhịp Foreground/Background & Single-Instance Player (`2.2.1`) | ✅ Hoàn thành | Duy trì duy nhất 1 instance `WKWebView` + `YT.Player` trên cả Native lẫn `web_preview`, loại bỏ toàn bộ lệnh `playVideo()`/`pauseVideo()`/`seekTo()`/`loadVideoById()` dư thừa khi chuyển trạng thái ứng dụng, khử trùng lặp `MediaMetadata`, tắt polling nền và bổ sung `PlaybackDiagnostics` (`os.Logger` + `window.__ytDiagLogs`). |
