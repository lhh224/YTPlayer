# CÁC GIỚI HẠN KỸ THUẬT & TUÂN THỦ CHÍNH SÁCH — YT PLAYER

## 1. Giới hạn Trình phát nhúng (YouTube Embedded Player)

- **Quảng cáo:** Ứng dụng sử dụng YouTube IFrame API chính thức. Mọi quảng cáo được YouTube phân phối bên trong video hoàn toàn do YouTube kiểm soát và hiển thị. Ứng dụng không can thiệp, không trích xuất video để vượt quảng cáo nhằm tuân thủ tuyệt đối Điều khoản Dịch vụ của YouTube (YouTube ToS).
- **Phát nền (Background Audio), Chuyển trạng thái Foreground/Background & Điều khiển Màn hình khóa:**
  - Trên **bản iOS Native (`YTPlayer.xcodeproj` / `.ipa`)**: Đã cấu hình chuẩn `UIBackgroundModes` (`audio`), `AVAudioSession` (`.playback`, `.moviePlayback`, `.mixWithOthers`), duy trì duy nhất một instance `WKWebView` + `YT.Player` và đồng bộ Lock Screen / Control Center qua `navigator.mediaSession` gốc của `WebKit.GPU` (không trích xuất luồng âm thanh thô, không dùng thủ thuật giả mạo trạng thái vượt giới hạn YouTube).
  - **Giới hạn tầng hệ điều hành iOS / WebKit (`WebKit.GPU`) & YouTube IFrame:**
    1. Khi đưa ứng dụng xuống nền trong lúc đang phát luồng có hình (Video track), tiến trình `com.apple.WebKit.GPU` của iOS tự động ngắt kết xuất khung hình video khỏi màn hình (video decoder detach) để tiết kiệm GPU và khi mở lại ứng dụng sẽ gắn lại bề mặt hiển thị chờ khung hình chính tiếp theo (keyframe re-sync). Quá trình phần cứng của iOS/WebKit này có thể tạo cảm giác khựng hình nhẹ ~50–150ms lúc vừa mở lại màn hình dù luồng ứng dụng không hề phát lệnh can thiệp.
    2. Do ứng dụng tuân thủ Điều khoản Dịch vụ của YouTube (sử dụng trình phát nhúng chính thức, không bóc tách stream âm thanh riêng và không giả mạo chính sách phát nền của YouTube), chính sách phía máy chủ YouTube hoặc WebKit trên một số phiên bản iOS có thể tự động tạm dừng trình phát nhúng khi ứng dụng đi vào nền. Mọi sự kiện này đều được ghi nhận minh bạch qua `PlaybackDiagnostics` (`os.Logger` category `PlaybackLifecycle`).
  - Trên **bản Web / WebClip (`.mobileconfig`)**: Chạy trong sandbox Safari iOS nên chịu chính sách tạm ngưng thẻ `<video>` trong iframe chéo miền của Safari/YouTube khi thoát ra màn hình chính hoặc khóa máy (trừ khi người dùng bật chế độ Picture-in-Picture gốc của iOS).
- **Tải ngoại tuyến (Offline Download):** YouTube Data API v3 và IFrame API không hỗ trợ tải video về lưu trữ cục bộ. Tính năng này không nằm trong phạm vi dự án.

## 2. Giới hạn Quota YouTube Data API v3

- Google Cloud cung cấp gói miễn phí mặc định là **10.000 quota units / ngày**.
- Mỗi lượt tìm kiếm (`search.list`) tiêu tốn **100 units**.
- Mỗi lượt lấy chi tiết video (`videos.list`) tiêu tốn **1 unit**.
- **Giải pháp tối ưu đã triển khai:**
  - `YouTubeAPIService` tích hợp bộ đệm nhớ cục bộ (in-memory cache) với thời gian sống (TTL) 5 phút để tránh gọi API trùng lặp.
  - Xử lý mã lỗi `429 (Quota Exceeded)` hiển thị thông báo thân thiện và tự động fallback sang dữ liệu mẫu khi cần.

## 3. Giới hạn phần cứng MacBook Air 2017

- CPU Intel Core i5 thế hệ Broadwell (2 nhân / 4 luồng) và RAM 8GB.
- Khi biên dịch lần đầu (Clean Build), Xcode có thể mất từ 3 đến 8 phút.
- Khuyến nghị: Đóng các ứng dụng đồ họa nặng (như CapCut, trình duyệt nhiều tab) khi chạy Xcode và Simulator để tránh thiếu hụt bộ nhớ RAM.
