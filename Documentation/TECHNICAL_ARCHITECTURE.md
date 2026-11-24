# TECHNICAL ARCHITECTURE — YT Player

**Phiên bản:** 1.0  
**Ngày:** 2026-11-20  
**Môi trường:** Xcode 14.2 · Swift 5.7 · iOS 16.2 · macOS 12.7.6

---

## 1. Stack công nghệ

| Layer | Công nghệ | Lý do |
|-------|-----------|-------|
| UI | SwiftUI | Yêu cầu dự án; hỗ trợ từ iOS 13+; iOS 16 có nhiều cải tiến |
| Architecture | MVVM | Tách biệt View/Logic; testable; phù hợp SwiftUI |
| Networking | URLSession | Có sẵn trong SDK; không cần dependency ngoài |
| Playback | WKWebView + YouTube IFrame API | Phương thức chính thức; không vi phạm ToS |
| Persistence | Core Data | SwiftData chỉ từ iOS 17; Core Data khả dụng iOS 16 |
| Local Settings | UserDefaults | Phù hợp cho cài đặt đơn giản |
| Testing | XCTest | Có sẵn trong Xcode |
| Navigation | NavigationStack (iOS 16+) | Thay thế NavigationView; type-safe |

> **Lý do chọn Core Data thay SwiftData:** SwiftData yêu cầu iOS 17+. Deployment target là iOS 16.2 nên phải dùng Core Data.

---

## 2. Kiến trúc MVVM

```
┌─────────────────────────────────────────────────────────┐
│                        Views (SwiftUI)                   │
│  HomeView │ SearchView │ LibraryView │ PlayerView │ ...  │
└──────────────────────┬──────────────────────────────────┘
                       │ observes @StateObject / @ObservedObject
┌──────────────────────▼──────────────────────────────────┐
│                     ViewModels                           │
│  HomeViewModel │ SearchViewModel │ PlayerViewModel │ ... │
│  (ObservableObject, @Published properties)              │
└──────────────────────┬──────────────────────────────────┘
                       │ calls async/await
┌──────────────────────▼──────────────────────────────────┐
│                  Services / Repositories                 │
│  YouTubeAPIService │ PlaybackService │ LibraryRepository │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│              Core: Models · Networking · Persistence     │
│  VideoItem │ Channel │ SearchResult │ CoreDataStack │ ... │
└─────────────────────────────────────────────────────────┘
```

---

## 3. Cấu trúc thư mục

```
YTPlayer/
├── App/
│   ├── YTPlayerApp.swift          # @main entry point
│   └── ContentView.swift          # Root TabView
│
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── HomeViewModel.swift
│   │   └── Components/
│   │       └── VideoCardView.swift
│   ├── Search/
│   │   ├── SearchView.swift
│   │   └── SearchViewModel.swift
│   ├── Library/
│   │   ├── LibraryView.swift
│   │   └── LibraryViewModel.swift
│   ├── Player/
│   │   ├── PlayerView.swift
│   │   ├── PlayerViewModel.swift
│   │   └── YouTubeWebView.swift    # WKWebView wrapper
│   └── Settings/
│       ├── SettingsView.swift
│       └── SettingsViewModel.swift
│
├── Core/
│   ├── Models/
│   │   ├── VideoItem.swift
│   │   ├── Channel.swift
│   │   ├── SearchResult.swift
│   │   └── AppError.swift
│   ├── Networking/
│   │   ├── NetworkClient.swift
│   │   ├── Endpoint.swift
│   │   └── NetworkError.swift
│   ├── Persistence/
│   │   ├── CoreDataStack.swift
│   │   ├── YTPlayer.xcdatamodeld
│   │   └── LibraryRepository.swift
│   ├── Navigation/
│   │   └── AppRouter.swift
│   └── DesignSystem/
│       ├── Colors.swift
│       ├── Typography.swift
│       ├── Spacing.swift
│       └── Components/
│           ├── LoadingSkeletonView.swift
│           ├── ErrorView.swift
│           └── EmptyStateView.swift
│
├── Services/
│   ├── YouTubeAPIService.swift
│   └── PlaybackService.swift
│
├── Resources/
│   ├── Assets.xcassets
│   ├── Localizable.strings
│   └── Info.plist
│
├── Tests/
│   ├── YTPlayerTests/
│   │   ├── NetworkClientTests.swift
│   │   ├── YouTubeAPIServiceTests.swift
│   │   └── LibraryRepositoryTests.swift
│   └── YTPlayerUITests/
│
├── Documentation/
│   ├── PROJECT_REQUIREMENTS.md
│   ├── TECHNICAL_ARCHITECTURE.md
│   ├── DEVELOPMENT_ROADMAP.md
│   └── COMPATIBILITY_REPORT.md
│
├── AGENT_RULES.md
├── PROGRESS.md
└── BUG_LOG.md
```

---

## 4. Playback Architecture — YouTube Embedded Player

### Lý do chọn WKWebView + YouTube IFrame API

```
┌──────────────────────────────────────────────────────────┐
│                     PlayerView (SwiftUI)                  │
│  ┌─────────────────────────────────────────────────────┐ │
│  │          YouTubeWebView (UIViewRepresentable)        │ │
│  │  ┌─────────────────────────────────────────────┐   │ │
│  │  │            WKWebView                        │   │ │
│  │  │  ┌──────────────────────────────────────┐  │   │ │
│  │  │  │   YouTube IFrame Player API (JS)     │  │   │ │
│  │  │  │   youtube.com/embed/{videoId}        │  │   │ │
│  │  │  └──────────────────────────────────────┘  │   │ │
│  │  └─────────────────────────────────────────────┘   │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                           │
│  PlayerViewModel ←→ WKScriptMessageHandler (JS bridge)   │
└──────────────────────────────────────────────────────────┘
```

**Luồng hoạt động:**
1. User chọn video → `PlayerViewModel` nhận `videoId`
2. `YouTubeWebView` load HTML với IFrame Player API
3. JS Player gọi event → `WKScriptMessageHandler` → `PlayerViewModel`
4. `PlayerViewModel` cập nhật state → View re-render

**Giới hạn của Embedded Player:**
- Không thể tắt quảng cáo do YouTube quyết định
- Fullscreen do WebView/native video player quản lý
- Background audio: không được đảm bảo theo ToS; cần kiểm thử
- PiP: phụ thuộc WKWebView support; không đảm bảo

---

## 5. Networking Layer

### YouTubeAPIService

```swift
// Endpoint pattern
enum YouTubeEndpoint {
    case search(query: String, pageToken: String?)
    case videoDetail(videoId: String)
    case trending(regionCode: String)
}

// Response handling
struct SearchResponse: Decodable { ... }
struct VideoItem: Decodable, Identifiable { ... }
```

**Xử lý Quota:**
- YouTube Data API v3 quota: 10,000 units/ngày (free tier)
- Search: 100 units/request
- Video detail: 1 unit/request
- Triển khai simple in-memory cache để giảm quota consumption

**API Key Management:**
- API key lưu trong `Config/APIKeys.plist` (không commit vào Git)
- `.gitignore` phải bao gồm `Config/APIKeys.plist`
- Template `APIKeys.plist.example` commit vào Git thay thế

---

## 6. Persistence — Core Data

### Schema

```
Entity: WatchHistoryItem
├── videoId: String (required)
├── title: String (required)
├── channelName: String (required)
├── thumbnailURL: String
├── watchedAt: Date (required)
└── duration: String

Entity: FavoriteItem
├── videoId: String (required)
├── title: String (required)
├── channelName: String (required)
├── thumbnailURL: String
└── addedAt: Date (required)
```

---

## 7. State Management

```swift
// ViewModel pattern chuẩn
@MainActor
class HomeViewModel: ObservableObject {
    @Published var state: ViewState = .idle
    @Published var videos: [VideoItem] = []
    
    enum ViewState {
        case idle
        case loading
        case loaded
        case empty
        case error(AppError)
    }
}
```

---

## 8. Design System

### Color Tokens (Dark Mode support)
```swift
extension Color {
    static let ytBackground = Color("Background")      // adaptive
    static let ytSurface = Color("Surface")           // card bg
    static let ytPrimary = Color("Primary")           // red accent
    static let ytTextPrimary = Color("TextPrimary")   // main text
    static let ytTextSecondary = Color("TextSecondary") // sub text
}
```

### Typography
- Title: SF Pro Display, 17pt Semibold
- Body: SF Pro Text, 15pt Regular
- Caption: SF Pro Text, 12pt Regular
- System font (SF Pro) — không cần custom font

### Spacing
- 4pt grid system: 4, 8, 12, 16, 20, 24, 32

---

## 9. Navigation — NavigationStack (iOS 16+)

```swift
// AppRouter sử dụng NavigationStack value-based
enum AppRoute: Hashable {
    case videoDetail(VideoItem)
    case channelDetail(String)
    case searchResults(String)
}

// Root ContentView
struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
            SearchView()
            LibraryView()
            SettingsView()
        }
    }
}
```

> **Lý do dùng `NavigationStack`:** `NavigationView` bị deprecated từ iOS 16. `NavigationStack` ổn định trên iOS 16.0+.

---

## 10. Build Configuration

| Config | Deployment Target | Bundle ID | Signing |
|--------|------------------|-----------|---------|
| Debug | iOS 16.2 | com.yourname.ytplayer.debug | Personal Team |
| Release | iOS 16.2 | com.yourname.ytplayer | Personal Team |

**Minimum iOS: 16.0** (sử dụng NavigationStack, nhiều cải tiến SwiftUI)

---

## 11. Quyết định kiến trúc cần người dùng xác nhận

| # | Quyết định | Lựa chọn đề xuất | Lý do |
|---|-----------|-----------------|-------|
| A1 | iOS Deployment Target | iOS 16.0 | NavigationStack stable; SwiftUI improvements |
| A2 | Persistence | Core Data | SwiftData requires iOS 17+ |
| A3 | Playback | WKWebView + IFrame API | Official YouTube method |
| A4 | Bundle ID | Cần người dùng cung cấp | Dùng cho signing |
| A5 | API Key storage | APIKeys.plist (gitignored) | Security best practice |
