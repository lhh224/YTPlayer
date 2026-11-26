# CÁC GIỚI HẠN KỸ THUẬT & TUÂN THỦ CHÍNH SÁCH — YT PLAYER

## 1. Giới hạn Trình phát nhúng (YouTube Embedded Player)

- **Quảng cáo:** Ứng dụng sử dụng YouTube IFrame API chính thức. Mọi quảng cáo được YouTube phân phối bên trong video hoàn toàn do YouTube kiểm soát và hiển thị. Ứng dụng không can thiệp, không trích xuất video để vượt quảng cáo nhằm tuân thủ tuyệt đối Điều khoản Dịch vụ của YouTube (YouTube ToS).
- **Phát nền (Background Audio) & Điều khiển Màn hình khóa:**
  - Trên **bản iOS Native (`YTPlayer.xcodeproj` / `.ipa`)**: Đã cấu hình đầy đủ `UIBackgroundModes` (`audio`), `AVAudioSession` (`.playback`), `WKUserScript` chống tạm dừng theo `visibilitychange` trên cả trang chính lẫn iframe nhúng, tự động khôi phục khi chuyển xuống nền và đồng bộ `MPNowPlayingInfoCenter` / `MPRemoteCommandCenter` lên Lock Screen & Control Center. Ứng dụng vẫn sử dụng trình phát nhúng chính thức của YouTube (không trích xuất hay bóc tách luồng stream thô trái phép). Lưu ý: trên một số phiên bản iOS mới hoặc chính sách cập nhật phía máy chủ YouTube, WebKit vẫn có thể áp đặt giới hạn giải mã video trong nền nếu bộ nhớ hệ thống bị thu hồi mạnh.
  - Trên **bản Web / WebClip (`.mobileconfig`)**: Chạy trong sandbox Safari nên chịu giới hạn chung của iOS WebKit đối với iframe chéo miền (cần bật Picture-in-Picture hoặc cài bản `.ipa` Native để phát nền ổn định khi khóa màn hình).
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
