# HƯỚNG DẪN BUILD & SETUP — YT PLAYER

**Môi trường khuyến nghị:**
- macOS: Monterey 12.7.6 (hoặc mới hơn)
- Xcode: 14.2 (Swift 5.7, iOS SDK 16.2)
- Deployment Target: iOS 16.0
- Thiết bị mục tiêu: iPhone chạy iOS 16.0+

---

## Bước 1: Cài đặt Xcode 14.2 trên macOS Monterey

1. Đăng nhập tài khoản Apple Developer tại: [https://developer.apple.com/download/all/](https://developer.apple.com/download/all/)
2. Tìm kiếm `Xcode 14.2` và tải file `Xcode_14.2.xip` (~10-12 GB).
3. Sau khi tải về, mở file `.xip` để giải nén.
4. Kéo `Xcode.app` vào thư mục `/Applications/`.
5. Mở Terminal và cấu hình đường dẫn công cụ dòng lệnh:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app
   sudo xcodebuild -license accept
   ```
6. Mở Xcode một lần để hệ thống cài đặt các component phụ trợ.

---

## Bước 2: Mở Project đã được cấu hình sẵn

> ✅ **Agent đã tự động tạo hoàn chỉnh project `YTPlayer.xcodeproj` và mô hình dữ liệu `YTPlayer.xcdatamodeld`!**
> Bạn KHÔNG CẦN phải tự tạo thủ công hay kéo thả file.

1. Vào thư mục: `/Users/macos/.gemini/antigravity/scratch/YTPlayer/`
2. Nhấp đúp chuột vào file **`YTPlayer.xcodeproj`** (hoặc chạy lệnh terminal: `open /Users/macos/.gemini/antigravity/scratch/YTPlayer/YTPlayer.xcodeproj`).
3. Toàn bộ 41 tệp tin mã nguồn (App, Core, Features, Services, Resources), cài đặt iOS 16.0 và Core Data model đã được liên kết sẵn sàng trong Project Navigator.

---

## Bước 3: Cấu hình YouTube API Key (Tùy chọn)

1. Đăng ký dự án trên [Google Cloud Console](https://console.cloud.google.com/) và tạo API key cho **YouTube Data API v3**.
2. Điền khóa vào file `Config/APIKeys.plist` (Agent đã tạo sẵn file này từ template).
*(Nếu chưa có API Key, app sẽ tự động sử dụng danh sách video mock data phong phú để bạn trải nghiệm ngay lập tức).*

---

## Bước 4: Nhấn Chạy (Build & Run)

### Trên iOS Simulator:
1. Trên thanh chọn thiết bị của Xcode, chọn simulator ví dụ: **iPhone 14 (iOS 16.2)**.
2. Nhấn tổ hợp phím **⌘ + B** để biên dịch.
3. Nhấn **⌘ + R** để chạy ứng dụng trên Simulator.

### Trên iPhone thật:
1. Kết nối iPhone với máy Mac qua cáp Lightning.
2. Vào Settings trên iPhone -> Privacy & Security -> bật **Developer Mode** và khởi động lại máy.
3. Trong Xcode, chọn thiết bị iPhone của bạn.
4. Đảm bảo cấu hình Signing & Capabilities đã chọn Team hợp lệ.
5. Nhấn **⌘ + R** để cài đặt và chạy ứng dụng trên iPhone.
