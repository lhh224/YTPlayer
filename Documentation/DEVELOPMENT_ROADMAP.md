# DEVELOPMENT ROADMAP — YT Player

**Phiên bản:** 1.0  
**Ngày:** 2026-11-20

---

## Tổng quan giai đoạn

```
Phase 0 ──► Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4 ──► Phase 5 ──► Phase 6 ──► Phase 7 ──► Phase 8
  Env         Arch        UI/UX      Foundation   YouTube     Playback   Library    Filtering   QA/Ship
  CHECK       DOCS        Mock        MVVM          API         Player    Advanced    Content
  [DONE]     [DONE]      [Next]
```

---

## Giai đoạn 0 — Kiểm tra môi trường ✅ HOÀN THÀNH

**Mục tiêu:** Xác nhận môi trường phát triển thực tế

| Task | Kết quả |
|------|---------|
| Kiểm tra macOS | ✅ macOS 12.7.6 (Monterey) — đúng yêu cầu |
| Kiểm tra Xcode | ⚠️ Chưa cài — cần cài Xcode 14.2 |
| Kiểm tra Swift | ⚠️ Phụ thuộc Xcode (chưa xác minh) |
| Kiểm tra phần cứng | ✅ Intel i5, 8GB RAM, ~107GB free |
| Đánh giá giới hạn | ✅ Ghi nhận — xem COMPATIBILITY_REPORT.md |

**Chặn:** Xcode 14.2 chưa được cài. Cần người dùng tải và cài từ [developer.apple.com](https://developer.apple.com/download/all/).

---

## Giai đoạn 1 — Phân tích & Kiến trúc ✅ HOÀN THÀNH

**Mục tiêu:** Tạo đủ 4 tài liệu kiến trúc

| Tài liệu | Trạng thái |
|----------|-----------|
| PROJECT_REQUIREMENTS.md | ✅ |
| TECHNICAL_ARCHITECTURE.md | ✅ |
| DEVELOPMENT_ROADMAP.md | ✅ (file này) |
| COMPATIBILITY_REPORT.md | ✅ |

---

## Giai đoạn 2 — UI/UX & Prototype 🔜 CHỜ XÁC NHẬN

**Mục tiêu:** Xây dựng giao diện SwiftUI với mock data

**Điều kiện tiên quyết:** Xcode 14.2 phải được cài

| Task | Mô tả | Ước lượng |
|------|-------|-----------|
| Setup Xcode project | Tạo project SwiftUI, cấu hình targets | 1 session |
| Design System | Colors, Typography, Spacing tokens | 1 session |
| HomeView | Tab bar + danh sách video card + mock data | 1 session |
| SearchView | Search bar + result list + states | 1 session |
| PlayerView | WKWebView wrapper + player UI | 1 session |
| LibraryView | Favorites + History tabs | 1 session |
| SettingsView | Danh sách cài đặt cơ bản | 0.5 session |
| Build & test simulator | Chạy trên iOS Simulator | 0.5 session |

**Tiêu chí nghiệm thu:** Build thành công trên simulator, không crash, navigation hoạt động, mock data hiển thị đúng.

---

## Giai đoạn 3 — Nền tảng ứng dụng 🔜

**Mục tiêu:** MVVM hoàn chỉnh, navigation, state management, persistence

| Task | Mô tả |
|------|-------|
| MVVM structure | ViewModels cho tất cả features |
| NavigationStack | AppRouter, deep link support |
| Core Data | Schema, CoreDataStack, Repository |
| Error handling | AppError enum, error states |
| Loading states | ViewState enum trong mỗi ViewModel |
| Unit tests | Tests cho ViewModel và Repository |

**Tiêu chí nghiệm thu:** Build thành công; persistence hoạt động; states chuyển đổi đúng; unit tests pass.

---

## Giai đoạn 4 — YouTube Data API 🔜

**Mục tiêu:** Tích hợp API thật; thay thế mock data

**Yêu cầu trước khi bắt đầu:**
- Người dùng cung cấp YouTube Data API v3 key
- API key đã được enable trong Google Cloud Console

| Task | Mô tả |
|------|-------|
| NetworkClient | URLSession wrapper, retry logic |
| YouTubeAPIService | Search, Video detail, Trending |
| Response parsing | Decodable models cho API responses |
| Quota management | Rate limiting, simple cache |
| Error handling | 403 quota, 404, network errors |
| Attribution | YouTube logo/branding theo yêu cầu |

**Tiêu chí nghiệm thu:** Search hoạt động với API thật; thumbnail hiển thị; quota không vượt giới hạn trong test.

---

## Giai đoạn 5 — Playback 🔜

**Mục tiêu:** Player hoạt động với YouTube Embedded Player

| Task | Mô tả |
|------|-------|
| YouTubeWebView | WKWebView + IFrame API HTML |
| JS bridge | WKScriptMessageHandler cho player events |
| PlayerViewModel | State: loading, playing, paused, error |
| Fullscreen | Xử lý orientation và fullscreen |
| App lifecycle | Pause khi app background/terminate |

**Giới hạn cần ghi nhận:**
- Không kiểm soát được quảng cáo
- Background audio không đảm bảo
- PiP phụ thuộc hành vi của WKWebView

**Tiêu chí nghiệm thu:** Video load và phát được; fullscreen hoạt động; app không crash khi chuyển app.

---

## Giai đoạn 6 — Library & Tính năng nâng cao 🔜

| Task | Điều kiện |
|------|-----------|
| Favorites (thêm/xóa/hiển thị) | Core Data ready |
| Watch History | Core Data ready |
| Playlist cá nhân | Sau Favorites |
| Sleep Timer | Độc lập, thuần SwiftUI |
| Mini Player | Kiểm thử trước khi cam kết |
| PiP / Background | Chỉ nếu kiểm thử thành công |

---

## Giai đoạn 7 — Content Filtering 🔜

| Task | Mô tả |
|------|-------|
| Đánh giá phạm vi | Xác định nội dung app được phép can thiệp |
| Tracking protection | WKContentRuleList cho web content trong app |
| Toggle UI | Bật/tắt bộ lọc trong Settings |
| Kiểm tra impact | Đảm bảo không phá playback/login |

---

## Giai đoạn 8 — QA, Bảo mật & Đóng gói 🔜

| Task | Mô tả |
|------|-------|
| Debug + Release build | Cả hai config build thành công |
| Simulator testing | iOS 16, 17 simulator |
| Device testing | iPhone thật nếu có |
| Memory check | Instruments Leaks, Allocations |
| Security audit | API key, PII, storage |
| Build guide | Hướng dẫn setup, build, cài lên device |
| Final report | Danh sách tính năng, giới hạn, known issues |

---

## MVP tối thiểu có thể build & kiểm thử

Để có build chạy được sớm nhất, MVP nhỏ nhất gồm:

1. **HomeView** với mock VideoCard list
2. **SearchView** với search bar (UI only, no API)
3. **PlayerView** với WKWebView nhúng YouTube embed URL
4. **Tab navigation** 4 tab
5. **Dark Mode** support

Build này có thể hoàn thành trong **Giai đoạn 2** (không cần API key).

---

## Quyết định cần người dùng xác nhận

| # | Vấn đề | Cần biết |
|---|--------|---------|
| D1 | Xcode 14.2 | Bạn có thể tải và cài Xcode 14.2 không? |
| D2 | YouTube API Key | Bạn đã có Google Cloud project và API key chưa? |
| D3 | Bundle ID | Apple Developer account và Bundle ID muốn dùng? |
| D4 | Deployment Target | Xác nhận iOS 16.0 là deployment target |
| D5 | Test device | iPhone model và iOS version để kiểm thử? |
