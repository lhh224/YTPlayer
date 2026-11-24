# PROJECT REQUIREMENTS — YT Player

**Phiên bản:** 1.0  
**Ngày:** 2026-11-20  
**Trạng thái:** Giai đoạn 1 — Phân tích & Kiến trúc

---

## 1. Tổng quan dự án

| Mục | Thông tin |
|-----|-----------|
| Tên dự án | YT Player |
| Mục tiêu | Ứng dụng iOS xem video/nghe nhạc từ YouTube với giao diện SwiftUI riêng |
| Tham khảo | 9Tube (trải nghiệm) |
| Phạm vi MVP | Chạy được trên iPhone cá nhân, kiến trúc rõ ràng để mở rộng |

---

## 2. Môi trường phát triển (đã kiểm tra thực tế)

| Thành phần | Yêu cầu dự án | Thực tế hiện tại | Trạng thái |
|------------|--------------|-----------------|-----------|
| macOS | Monterey 12.7.6 | 12.7.6 (Build 21H1320) | ✅ Khớp |
| Xcode | 14.2 | **Chưa cài** | ⚠️ Cần cài |
| Swift | 5.7 | Chưa xác minh được (do Xcode chưa cài) | ⚠️ Phụ thuộc Xcode |
| iOS SDK | 16.2 | Chưa xác minh được | ⚠️ Phụ thuộc Xcode |
| CPU | Intel | Intel Core i5-5250U @ 1.60GHz (2 cores/4 threads) | ✅ Intel x86_64 |
| RAM | — | 8 GB | ℹ️ Đủ cho Xcode 14 |
| Disk | — | ~107 GB còn trống (tổng 234 GB) | ✅ Đủ dung lượng |
| IDE soạn mã | VS Code / Antigravity | VS Code đã cài | ✅ |

> **⚠️ ĐIỂM CHẶN:** Xcode chưa được cài trên máy này. Không thể build hoặc kiểm thử iOS project cho đến khi Xcode 14.2 được cài đặt.

### Giới hạn phần cứng (MacBook Air 2017)

- CPU Intel Core i5 Broadwell (2015 gen) — build Swift sẽ chậm hơn so với máy hiện đại
- RAM 8 GB — đủ nhưng cần đóng các ứng dụng nặng khi build
- Không có Apple Silicon — không thể dùng Simulator arm64; dùng x86_64 simulator
- macOS Monterey 12.7.6 — phiên bản cao nhất hỗ trợ được trên MacBook Air 2017
- Xcode 14.2 là phiên bản mới nhất tương thích với macOS 12.x (Monterey)

---

## 3. Yêu cầu chức năng — MVP

### 3.1 Home
- Hiển thị danh sách video/khám phá
- Video card: thumbnail, tiêu đề, tên kênh, thời lượng, lượt xem
- Loading skeleton khi tải dữ liệu
- Empty state và error state rõ ràng

### 3.2 Search
- Ô tìm kiếm với debounce input
- Hiển thị kết quả dạng danh sách video card
- Trạng thái: idle, loading, results, empty, error

### 3.3 Video Detail / Player
- Mở video bằng YouTube Embedded Player (WKWebView)
- Hiển thị metadata: tiêu đề, kênh, mô tả rút gọn
- Điều khiển fullscreen (do embedded player quản lý)

### 3.4 Library
- Lịch sử xem (lưu cục bộ)
- Danh sách yêu thích (lưu cục bộ)
- Xóa từng mục hoặc xóa toàn bộ

### 3.5 Settings
- Dark Mode toggle
- Xóa lịch sử
- Thông tin ứng dụng và attribution YouTube

### 3.6 Navigation
- Tab bar 4 mục: Home, Search, Library, Settings
- Điều hướng stack trong từng tab

---

## 4. Yêu cầu phi chức năng

| Yêu cầu | Mô tả |
|---------|-------|
| Hiệu năng | Mượt trên iPhone 13; lazy load thumbnail |
| Bộ nhớ | Không rò rỉ bộ nhớ khi phát nhiều video liên tiếp |
| Bảo mật | API key không lưu trong source code; dùng plist bị .gitignore |
| Khả năng mở rộng | MVVM rõ ràng để thêm tính năng mà không refactor lớn |
| Accessibility | VoiceOver cơ bản cho các thành phần chính |
| Offline | Hiển thị trạng thái không có mạng; lịch sử/yêu thích vẫn truy cập được |

---

## 5. Yêu cầu tuân thủ YouTube

| Điều khoản | Yêu cầu cụ thể |
|-----------|----------------|
| YouTube Data API v3 | Dùng API key hợp lệ; attribution đúng quy định |
| Playback | Chỉ dùng YouTube Embedded Player hoặc phương thức chính thức |
| Quota | Xử lý 429/quota exceeded; không gọi API không cần thiết |
| Cache | Tuân thủ chính sách cache của YouTube API |
| Branding | Hiển thị logo/attribution YouTube đúng theo yêu cầu |
| Nội dung | Không trích xuất, lưu trữ hay phân phối lại nội dung YouTube |

---

## 6. Tính năng giai đoạn nâng cao (sau MVP)

| Tính năng | Điều kiện |
|-----------|-----------|
| Playlist cá nhân | Sau MVP; lưu cục bộ |
| Autoplay tiếp theo | Nếu embedded player hỗ trợ |
| Mini Player | Cần kiểm tra khả năng với WKWebView |
| Sleep Timer | Khả thi; triển khai thuần SwiftUI |
| PiP | Chỉ khi AVKit + embedded player cho phép; kiểm thử thực tế |
| Background Audio | Phụ thuộc chính sách YouTube; kiểm thử thực tế |
| Đăng nhập YouTube | Chỉ khi có thiết kế bảo mật OAuth2 đầy đủ |

---

## 7. Ngoài phạm vi (Out of Scope)

- Chặn quảng cáo trong video YouTube
- Tải về video/audio offline
- Trích xuất stream trực tiếp
- Giả lập YouTube client
- Tính năng Shorts trong MVP
- Đăng nhập/đồng bộ trong MVP
