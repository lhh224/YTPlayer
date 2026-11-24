# COMPATIBILITY REPORT — YT Player

**Phiên bản:** 1.0  
**Ngày:** 2026-11-20  
**Máy kiểm tra:** MacBook Air 2017 (Intel Core i5-5250U)

---

## 1. Môi trường thực tế (đã kiểm tra)

| Thành phần | Giá trị thực tế | Yêu cầu dự án | Tương thích |
|-----------|----------------|--------------|------------|
| macOS | 12.7.6 Monterey (Build 21H1320) | Monterey 12.7.6 | ✅ Khớp hoàn toàn |
| CPU | Intel Core i5-5250U @ 1.60GHz | — | ✅ Intel x86_64 |
| RAM | 8 GB | — | ✅ Đủ cho Xcode 14 |
| Disk (free) | ~107 GB / 234 GB | — | ✅ Đủ (Xcode 14 cần ~12-15 GB) |
| Xcode | **Chưa cài** | 14.2 | ⚠️ CHẶN |
| Swift | Không xác minh được | 5.7 | ⚠️ Phụ thuộc Xcode |
| iOS SDK | Không xác minh được | 16.2 | ⚠️ Phụ thuộc Xcode |
| VS Code | Đã cài | Khuyến nghị | ✅ |

---

## 2. Tương thích Xcode 14.2 với macOS Monterey

| Xcode | macOS yêu cầu tối thiểu | Tương thích macOS 12.7.6 |
|-------|------------------------|--------------------------|
| 14.2 | macOS 12.5+ | ✅ Tương thích |
| 14.3+ | macOS 13.0+ | ❌ Không tương thích (cần Ventura) |
| 15.x | macOS 14.0+ | ❌ Không tương thích |

> **Kết luận:** Xcode 14.2 là phiên bản Xcode **MỚI NHẤT** tương thích với macOS Monterey 12.7.6. Đây là lựa chọn đúng. Không có lý do để nâng cấp lên Xcode cao hơn.

---

## 3. Tương thích API & Framework

### SwiftUI
| Tính năng SwiftUI | iOS yêu cầu | iOS 16.2 | Trạng thái |
|-------------------|-------------|----------|-----------|
| `NavigationStack` | iOS 16.0 | ✅ | Khuyến nghị dùng |
| `NavigationSplitView` | iOS 16.0 | ✅ | Dùng cho iPad nếu cần |
| `@StateObject` | iOS 14.0 | ✅ | Dùng được |
| `async/await` trong View | iOS 15.0 | ✅ | Dùng được |
| `searchable()` | iOS 15.0 | ✅ | Dùng cho Search |
| `.refreshable()` | iOS 15.0 | ✅ | Dùng cho pull-to-refresh |
| `Grid` layout | iOS 16.0 | ✅ | Dùng được |
| `SwiftData` | iOS 17.0 | ❌ | **Không dùng** → Core Data |
| `Observable` macro | iOS 17.0 | ❌ | **Không dùng** → ObservableObject |
| `@Bindable` | iOS 17.0 | ❌ | **Không dùng** → @Binding |

### Core Frameworks
| Framework | iOS yêu cầu | Dùng trong dự án | Trạng thái |
|-----------|-------------|-----------------|-----------|
| SwiftUI | iOS 13.0 | ✅ Giao diện toàn bộ | ✅ |
| WKWebView | iOS 8.0 | ✅ YouTube Embedded Player | ✅ |
| Core Data | iOS 3.0 | ✅ Persistence | ✅ |
| URLSession | iOS 7.0 | ✅ Networking | ✅ |
| UserDefaults | iOS 2.0 | ✅ Settings | ✅ |
| AVKit/AVFoundation | iOS 7.0 | ⚠️ Chỉ nếu có nguồn media hợp lệ | Conditional |
| WKContentRuleList | iOS 11.0 | ✅ Content filtering | ✅ |
| XCTest | — | ✅ Testing | ✅ |

---

## 4. Phân tích tính khả thi từng tính năng

### 4.1 Khả thi — Triển khai trực tiếp

| Tính năng | Phương thức | Lý do |
|-----------|------------|-------|
| Home feed (trending) | YouTube Data API v3 | API chính thức, hỗ trợ đầy đủ |
| Search video | YouTube Data API v3 | Quota 100 units/request; feasible |
| Video card UI | SwiftUI + AsyncImage | iOS 15+; đơn giản |
| Video playback | WKWebView + IFrame API | Phương thức chính thức YouTube |
| Favorites (local) | Core Data | Không phụ thuộc API |
| Watch History (local) | Core Data | Không phụ thuộc API |
| Dark Mode | SwiftUI color scheme | iOS 13+; native |
| Loading/Empty/Error states | SwiftUI | Thuần UI |
| Tab navigation | TabView + NavigationStack | iOS 16+ |
| Settings cơ bản | SwiftUI + UserDefaults | Đơn giản |
| Sleep Timer | Timer + SwiftUI | Thuần native |

### 4.2 Có điều kiện — Cần kiểm thử thực tế

| Tính năng | Điều kiện | Rủi ro |
|-----------|-----------|--------|
| Fullscreen video | WKWebView native video player | Hành vi phụ thuộc iOS version |
| Background audio | Không được đảm bảo theo YouTube ToS | ⚠️ Có thể vi phạm chính sách |
| PiP (Picture-in-Picture) | WKWebView PiP support iOS 16 | Cần kiểm thử trên device thật |
| Mini Player | Custom SwiftUI overlay + WKWebView | Phức tạp; ảnh hưởng playback state |
| Autoplay tiếp theo | IFrame API `onStateChange` event | Phụ thuộc embedded player behavior |
| Content filtering | WKContentRuleList | Cần đảm bảo không phá playback |
| Pagination | YouTube API pageToken | Cần xử lý quota tốt |

### 4.3 Không khả thi — Ngoài phạm vi hợp lệ

| Tính năng | Lý do | Hậu quả nếu vi phạm |
|-----------|-------|---------------------|
| Phát video bằng AVPlayer trực tiếp | YouTube không cung cấp stream URL công khai | Vi phạm YouTube ToS |
| Trích xuất audio stream | Reverse-engineering API nội bộ | Vi phạm ToS; pháp lý |
| Chặn quảng cáo trong video | YouTube Embedded Player quản lý ads | Vi phạm ToS |
| Tải video offline | Không được phép theo ToS | Vi phạm ToS |
| Giả lập YouTube client | Undocumented internal API | Vi phạm ToS; unstable |

---

## 5. Giới hạn phần cứng MacBook Air 2017

| Giới hạn | Ảnh hưởng | Giảm thiểu |
|---------|-----------|-----------|
| CPU chậm (1.6 GHz dual-core) | Build thời gian dài hơn | Dùng incremental build; đóng app nặng |
| RAM 8 GB | Xcode + Simulator tiêu tốn nhiều RAM | Chạy 1 simulator ở cùng thời điểm |
| Không có Apple Silicon | Không dùng được simulator arm64 | Dùng x86_64 simulator; ổn |
| macOS Monterey (tối đa) | Không thể nâng Xcode quá 14.2 | Xcode 14.2 đủ cho dự án |
| SSD speed | — | Không ảnh hưởng đáng kể |

**Thời gian build ước tính (clean build):**
- Nhỏ (SwiftUI prototype): ~2-4 phút
- MVP đầy đủ: ~5-10 phút
- Incremental build: ~30s-2 phút

---

## 6. YouTube API Quota Analysis

| API Call | Units/request | Dùng cho | Units/ngày (ước tính) |
|---------|--------------|----------|----------------------|
| Search list | 100 | Search, trending | ~500-1000 |
| Videos list | 1 | Video detail, metadata | ~50-200 |
| **Tổng** | — | — | ~550-1200/10,000 |

> **Kết luận:** Với free tier 10,000 units/ngày, đủ cho development và testing. Cần cache kết quả để tránh vượt quota.

---

## 7. Kết luận & Khuyến nghị

### ✅ Hành động cần thiết ngay

1. **Cài Xcode 14.2** — Tải từ [developer.apple.com/download/all](https://developer.apple.com/download/all/) (cần Apple ID). File .xip khoảng 10-12 GB. Giải nén vào `/Applications/Xcode.app`.
2. **Chạy `sudo xcode-select -s /Applications/Xcode.app`** sau khi cài để set developer tools path.
3. **Chấp nhận Xcode license:** `sudo xcodebuild -license accept`

### ✅ Stack đề xuất (đã xác nhận tương thích)

- **iOS 16.0** deployment target — dùng được `NavigationStack`, `Grid`, đủ tính năng SwiftUI
- **Core Data** cho persistence — không dùng SwiftData (iOS 17+)
- **WKWebView + YouTube IFrame API** cho playback — phương thức duy nhất hợp lệ
- **ObservableObject + @Published** — không dùng `@Observable` (iOS 17+)
- **async/await** — hỗ trợ từ Swift 5.5/iOS 15

### ⚠️ Rủi ro cần theo dõi

1. **Build performance:** CPU chậm → chấp nhận thời gian build dài hơn
2. **Background audio/PiP:** Chính sách YouTube không rõ → test thực tế trên device
3. **API Quota:** Quản lý chặt trong development; cache aggressive
