# 🎬 YT Player — iOS Video & Music App

Ứng dụng iOS xem video và nghe nhạc phong cách YouTube, xây dựng hoàn toàn bằng **SwiftUI**, **MVVM**, **Core Data** và **YouTube IFrame Player API**.

---

## 📌 Điểm nổi bật (Features)

- **Giao diện SwiftUI Native:** Không phải webview bọc cả app, toàn bộ màn hình (Trang chủ, Tìm kiếm, Thư viện, Cài đặt, Chi tiết video) được xây dựng bằng SwiftUI thuần với Design System đồng bộ.
- **Phát video chuẩn YouTube ToS:** Tích hợp `WKWebView` liên kết hai chiều với YouTube IFrame API. Không bẻ khóa stream, không trích xuất trái phép, tuân thủ chính sách bản quyền.
- **Tìm kiếm trực tiếp (YouTube Data API v3):** Tìm kiếm thông minh với cơ chế debounce 400ms, tự động lưu đệm in-memory cache 5 phút và tự động fallback sang danh mục video mẫu khi mất mạng hoặc chưa cấu hình API Key.
- **Thư viện & Lịch sử lưu cục bộ (Core Data):** Lưu trữ danh sách Video Yêu thích và Lịch sử xem trực tiếp vào cơ sở dữ liệu SQLite/Core Data trên thiết bị.
- **Hẹn giờ tắt thông minh (Sleep Timer):** Cho phép đặt thời gian tự động ngắt phát video/nhạc (15, 30, 45, 60, 90 phút).
- **Lọc mã theo dõi web (Tracking Protection):** Tích hợp `WKContentRuleList` chặn mã theo dõi web bên thứ ba trong phạm vi ứng dụng kiểm soát.
- **Dark Mode & Dynamic Typography:** Hỗ trợ giao diện Sáng / Tối thích ứng và kích thước chữ linh hoạt theo hệ điều hành iOS.

---

## 🗂️ Cấu trúc dự án (Architecture)

```text
YTPlayer/
├── YTPlayer.xcodeproj           # Project Xcode đã liên kết đầy đủ 41 source files & targets
├── Package.swift                # Cấu hình Swift Package Manager chuẩn
├── test.sh                      # Script 1 dòng lệnh chạy toàn bộ 32 ca Unit Test & kiểm tra API Key
│
├── App/                         # Entry point (@main) & Root TabView
│   ├── YTPlayerApp.swift
│   └── ContentView.swift
│
├── Features/                    # Các màn hình tính năng (MVVM)
│   ├── Home/                    # Khám phá & Trending feed
│   ├── Search/                  # Tìm kiếm video
│   ├── Player/                  # Trình phát video & JavaScript Bridge
│   ├── Library/                 # Quản lý Yêu thích & Lịch sử xem
│   └── Settings/                # Cài đặt giao diện, bộ lọc & Sleep Timer
│
├── Core/                        # Tầng lõi dùng chung
│   ├── Models/                  # VideoItem, Channel, SearchResult, AppError
│   ├── Networking/              # Endpoint, NetworkClient, NetworkError
│   ├── Persistence/             # CoreDataStack, LibraryRepository, YTPlayer.xcdatamodeld
│   ├── Navigation/              # AppRouter (NavigationStack iOS 16+)
│   └── DesignSystem/            # Colors, Typography, Spacing, LoadingSkeleton, AsyncImageView
│
├── Services/                    # Tầng nghiệp vụ
│   ├── YouTubeAPIService.swift  # Tích hợp YouTube Data API v3 & In-memory Cache
│   ├── PlaybackService.swift    # Sinh mã HTML IFrame Player chuẩn
│   ├── SleepTimerService.swift  # Bộ đếm hẹn giờ tắt phát nhạc
│   └── ContentFilterService.swift # Bộ lọc mã theo dõi web
│
├── Config/                      # Cấu hình API Key (được .gitignore bảo vệ an toàn)
│   ├── APIKeys.plist
│   └── APIKeys.plist.example
│
├── Resources/                   # Tài nguyên ứng dụng
│   ├── Assets.xcassets          # AppIcon & AccentColor
│   └── Info.plist               # Cấu hình hệ thống iOS
│
├── Tests/                       # Bộ bài kiểm thử
│   ├── YTPlayerTests/           # XCTest unit tests
│   └── run_demo_test.swift      # Test runner độc lập
│
├── web_preview/                 # Bản xem trước giao diện trực tiếp trên trình duyệt
│   └── index.html
│
└── Documentation/               # Hồ sơ tài liệu kỹ thuật
    ├── BUILD_GUIDE.md           # Hướng dẫn build & cài đặt chi tiết
    ├── KNOWN_LIMITATIONS.md     # Giới hạn kỹ thuật & chính sách YouTube ToS
    ├── PROJECT_REQUIREMENTS.md  # Yêu cầu dự án & phạm vi
    ├── TECHNICAL_ARCHITECTURE.md# Kiến trúc kỹ thuật chi tiết
    ├── DEVELOPMENT_ROADMAP.md   # Lộ trình triển khai
    └── COMPATIBILITY_REPORT.md  # Báo cáo tương thích macOS / Xcode
```

---

## 🚀 Hướng dẫn mở và chạy dự án (Getting Started)

### 1. Chạy trên Xcode (iOS Simulator hoặc iPhone thật):
1. **Nhấp đúp chuột vào file `YTPlayer.xcodeproj`** để mở trực tiếp trong Xcode.
2. Chọn thiết bị chạy (ví dụ: *iPhone 14 Simulator* hoặc cắm trực tiếp iPhone của bạn).
3. Nhấn tổ hợp phím **`⌘ + R`** (Product → Run). Ứng dụng sẽ tự động biên dịch và khởi chạy!

### 2. Chạy kiểm thử tự động (Unit Tests):
Mở ứng dụng Terminal trên Mac và chạy lệnh:
```bash
/Users/macos/.gemini/antigravity/scratch/YTPlayer/test.sh
```
Script sẽ biên dịch mã nguồn với Swift 5.7, chạy toàn bộ 32 ca kiểm thử và kiểm tra kết nối API Key trực tiếp.

### 3. Xem trước giao diện ngay trên Chrome hoặc Safari:
Nhấp đúp vào file [`web_preview/index.html`](file:///Users/macos/.gemini/antigravity/scratch/YTPlayer/web_preview/index.html) để mở giao diện mô phỏng iPhone và trải nghiệm tương tác mọi tính năng.

---

## 🔑 Cấu hình YouTube API Key

1. Đăng ký API Key miễn phí tại [Google Cloud Console](https://console.cloud.google.com/apis/credentials) cho dịch vụ **YouTube Data API v3**.
2. Dán API key vào file `Config/APIKeys.plist`:
   ```xml
   <key>YouTubeAPIKey</key>
   <string>AIzaSyYourKeyHere...</string>
   ```
*(File này đã được khai báo trong `.gitignore` để đảm bảo an toàn tuyệt đối cho khóa bảo mật của bạn).*

---

## ⚖️ Tuân thủ chính sách YouTube (Terms of Service)
Dự án được xây dựng tuân thủ đầy đủ các quy định của Google YouTube API:
- Không lưu trữ (caching) luồng âm thanh/video trái phép.
- Không trích xuất stream để phát ngoài quyền kiểm soát của YouTube.
- Giữ nguyên các thông báo và nhận diện thương hiệu của YouTube.
