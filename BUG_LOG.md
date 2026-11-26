# BUG LOG — YT Player

**Dự án:** YT Player  
**Cập nhật lần cuối:** 2026-11-24

---

## Giai đoạn 0 — Môi trường

### [ENV-001] Xcode 14.2 chưa được cài trên máy phát triển
- **Ngày phát hiện:** 2026-11-20
- **Mức độ:** Critical (Môi trường build iOS Simulator)
- **Mô tả:** `xcodebuild -version` báo máy chỉ đang có Command Line Tools (`/Library/Developer/CommandLineTools`), chưa có `/Applications/Xcode.app`.
- **Cách khắc phục:**
  - Để chạy ngay trên máy Mac mà không cần chờ tải Xcode: sử dụng bản Web App đầy đủ tại `web_preview/index.html` (chạy `./start_web.sh`).
  - Để build lên iPhone/Simulator: cài đặt Xcode 14.2 theo `Documentation/BUILD_GUIDE.md`. Mã nguồn Swift đã được kiểm tra `swiftc -typecheck` toàn bộ 39/39 file đạt 0 lỗi.
- **Trạng thái:** 🟡 Mitigated (Có thể dùng ngay qua Web App; project Xcode đã sẵn sàng 100%)

---

## Giai đoạn 1 → 8 — Lỗi phát hiện và khắc phục (2026-11-24)

### [API-001] Tìm kiếm không liên kết được với YouTube Data API v3 (Lỗi 403 PERMISSION_DENIED bị ẩn)
- **Ngày phát hiện:** 2026-11-24
- **Mức độ:** Critical
- **Mô tả:** Người dùng tìm kiếm nhưng không trả về video từ YouTube API mà chỉ báo không tìm thấy trong bộ nhớ Offline.
- **Nguyên nhân:**
  1. Khóa API `AIzaSyBelxi...Osos` trong `Config/APIKeys.plist` và `web_preview/index.html` trả về lỗi HTTP `403 PERMISSION_DENIED` (`service: youtube.googleapis.com`) vì trên Google Cloud Project tạo khóa này chưa bật dịch vụ **YouTube Data API v3** (hoặc giới hạn quyền API).
  2. Cả `SearchViewModel.swift` và `web_preview/index.html` trước đó đều nuốt toàn bộ lỗi trả về từ Google API mà không thông báo nguyên nhân, cũng không có ô nhập/kiểm tra lại API Key trong phần Cài đặt.
  3. Endpoint `/search` của YouTube v3 không trả về `duration` và `viewCount`, cũng không giải mã ký tự HTML (`&#39;`, `&amp;`).
- **Cách sửa:**
  1. Nâng cấp `YouTubeAPIService.swift` và `web_preview/index.html`: phân tích chi tiết phản hồi lỗi JSON từ Google (`403 PERMISSION_DENIED`, `400 keyInvalid`, `quotaExceeded`), hiển thị chẩn đoán rõ ràng kèm liên kết bật nhanh YouTube Data API v3 trên Google Cloud Console.
  2. Bổ sung mục **Kết nối YouTube Data API v3** trong màn hình **Cài đặt** (cả bản Swift & bản Web) cho phép dán khóa API mới, lưu `UserDefaults`/`localStorage` và bấm **Lưu & Kiểm tra kết nối** trực tiếp.
  3. Tích hợp truy vấn gộp `/videos?part=contentDetails,statistics` sau `/search` để lấy thời lượng chuẩn (chuyển đổi ISO-8601 `PT4M15S` → `4:15`), số lượt xem thực tế và phân trang `nextPageToken`.
  4. Hỗ trợ dán trực tiếp link YouTube (`youtube.com/watch?v=...`, `youtu.be/...`) vào ô tìm kiếm để phát ngay cả khi chưa bật API Key.
- **Trạng thái:** 🟢 Fixed

### [CODE-002] Không khớp tên thuộc tính và enum giữa các View và ViewModel Swift
- **Ngày phát hiện:** 2026-11-24
- **Mức độ:** Critical (Compile Blocker)
- **Mô tả:**
  - `SearchView.swift` gọi `SearchViewModel(initialQuery:)` không tồn tại, switch trên `.results(let videos)` trong khi `SearchViewModel.ViewState` dùng `.loaded`.
  - `HomeView.swift` truy cập `$vm.navigationPath`, `vm.isLoading`, `vm.error` không tồn tại trong `HomeViewModel`.
  - Các View gọi `.ytPrimaryText`, `.ytSecondaryText`, `Font.ytBodyMedium`, `CornerRadius.sm`, `EmptyStateView(..., message:)` lệch tên với `DesignSystem`.
- **Cách sửa:** Đồng bộ hoàn toàn `Colors.swift`, `Typography.swift`, `Spacing.swift`, `SearchView`/`SearchViewModel`, `HomeView`/`HomeViewModel` và kiểm chứng bằng `swiftc -typecheck` trên toàn bộ 39 file Swift.
- **Trạng thái:** 🟢 Fixed

### [CODE-003] Hỏng cầu nối JavaScript (JS Bridge) và lỗi xóa nhầm danh sách trong Library
- **Ngày phát hiện:** 2026-11-24
- **Mức độ:** Major
- **Mô tả:**
  - `PlaybackService` gửi object JS thô lên `ytPlayer.postMessage({...})` với key `state`/`error`, trong khi `YouTubeWebView` ép kiểu `as? String` và `PlayerViewModel` đọc key `data`, khiến sự kiện trình phát không bao giờ tới được ViewModel.
  - `LibraryViewModel.deleteHistory` xóa nhầm mảng `favoriteItems` thay vì `historyItems` và chưa xóa trong Core Data.
  - `ContentView` và `SettingsView` khởi tạo 2 `SettingsViewModel` riêng biệt làm nút bật/tắt Dark Mode không đổi giao diện tức thời.
- **Cách sửa:** Chuẩn hóa `JSON.stringify` trên `PlaybackService`, hỗ trợ cả `String` và Dictionary trong `YouTubeWebView.Coordinator`, bổ sung `removeHistoryItem` trong `LibraryRepository`, và chia sẻ `SettingsViewModel` qua `@EnvironmentObject`.
- **Trạng thái:** 🟢 Fixed

### [XCODE-001] Đường dẫn file bị lệch trong `YTPlayer.xcodeproj/project.pbxproj`
- **Ngày phát hiện:** 2026-11-24
- **Mức độ:** Critical (Xcode Build)
- **Mô tả:** Các `PBXFileReference` trong nhóm `Core`, `Features`, `Resources` thiếu thư mục con (`Core/DesignSystem/...`, `Features/Home/...`, `Resources/Assets.xcassets`) dẫn tới báo đỏ file khi mở Xcode.
- **Cách sửa:** Cập nhật toàn bộ `PBXFileReference` với `sourceTree = SOURCE_ROOT` trỏ chính xác tới đường dẫn thực tế của từng file và đặt `codeGenerationType="none"` trong `YTPlayer.xcdatamodel`.
- **Trạng thái:** 🟢 Fixed

### [WEB-001] Lỗi lệch video Trang chủ, lỗi `indexOf` = -1, và hẹn giờ giả trên `web_preview/index.html`
- **Ngày phát hiện:** 2026-11-24
- **Mức độ:** Major
- **Mô tả:**
  - Thẻ video trên Trang chủ hiển thị Rick Astley / PSY / Despacito nhưng bấm vào lại phát Sơn Tùng / Đen Vâu / Ed Sheeran do hardcode `openPlayer(0/1/2)`.
  - Kết quả tìm kiếm dùng `videos.indexOf(v)` trả về `-1` khi video đã có trong mảng.
  - Nút "Thu nhỏ" đóng hẳn trình phát thay vì thu nhỏ thành Mini Player; Sleep Timer đứng yên ở `29:59`; Light Mode bị chữ trắng trên nền sáng.
- **Cách sửa:** Chuyển sang định danh `videoRegistry` (`openPlayerById`), bổ sung Mini Player giữ nhạc phát liên tục, hoàn thiện bộ đếm ngược Sleep Timer tự động dừng YouTube IFrame Player khi về `00:00`, lưu `localStorage` cho Yêu thích/Lịch sử và đồng bộ CSS variables cho Light/Dark Mode.
- **Trạng thái:** 🟢 Fixed


---

## Cập nhật v2.1.0 (2026-11-25)
- **Vấn đề 1:** Khi mở Control Center sau khi thoát WebClip trên iPhone bị báo `"Không phát"` do trang chính không giữ `AVAudioSession` trực tiếp (chỉ có iframe chéo miền).
  - **Cách xử lý:** Bổ sung bộ tạo luồng âm thanh giữ phiên (`keepAliveAudio` PCM WAV siêu nhỏ chạy ở frame chính khi bật *Phát trong nền*) kết hợp `navigator.mediaSession.setPositionState` và tự kích hoạt lại `playVideo()` khi hệ thống vừa ẩn trang. *(Lưu ý giới hạn WebKit iOS: Safari/WebClip vẫn có thể tạm ngưng giải mã thẻ `<video>` bên trong iframe YouTube chéo miền khi tắt màn hình tùy phiên bản iOS).*
- **Vấn đề 2:** Cập nhật toàn bộ màn hình Cài đặt `v2.1.0` (Phát trong nền, Chế độ mở mặc định Music/Video, Tự động phát tiếp theo, Chất lượng phát, Hẹn giờ 15p/30p/45p/60p, Giao diện tối, Đo & xóa bộ nhớ đệm thực tế) và cơ chế `no-cache` revalidate trong `sw.js` để Profile App trên iPhone nhận ngay bản mới.

---

## Giai đoạn 10 — Phát nhạc trong nền Native iOS (2026-11-25)

### [BG-001] Luồng phát YouTube IFrame trong `WKWebView` tự động tạm dừng khi khóa màn hình iPhone 13 hoặc đưa app xuống nền
- **Ngày phát hiện:** 2026-11-25
- **Mức độ:** Critical
- **Nguyên nhân:**
  1. `Resources/Info.plist` thiếu `UIBackgroundModes = [audio]` và `YTPlayer.xcodeproj` bật `GENERATE_INFOPLIST_FILE = YES` mà chưa trỏ `INFOPLIST_FILE = Resources/Info.plist` cũng như chưa bật capability `BackgroundModes`.
  2. `YTPlayerApp.swift` chưa cấu hình `AVAudioSession.sharedInstance().setCategory(.playback)` và chưa lắng nghe `AVAudioSession.interruptionNotification` / `routeChangeNotification`.
  3. Khi khóa màn hình hoặc thoát ra nền, WebKit phát sự kiện `visibilitychange` và đặt `document.hidden = true` vào cả trang chủ lẫn iframe con của YouTube khiến IFrame API tự gọi pause; ngoài ra khi đổi bài từ nền, `embedHTML` thay đổi làm `WKWebView.loadHTMLString` tải lại toàn trang gây mất phiên media đã cấp quyền.
  4. Chưa tích hợp `MPNowPlayingInfoCenter` và `MPRemoteCommandCenter` để hiển thị metadata và điều khiển từ Lock Screen / Control Center.
- **Cách sửa:**
  1. Bổ sung `UIBackgroundModes` (`audio`) vào `Resources/Info.plist` và liên kết `INFOPLIST_FILE = Resources/Info.plist` + `com.apple.BackgroundModes` trong `YTPlayer.xcodeproj/project.pbxproj`.
  2. Kích hoạt `AVAudioSession` (`.playback`, `.default`) ngay khi khởi chạy trong `YTPlayerApp.swift` và xử lý khôi phục tự động sau cuộc gọi/thông báo (`AVAudioSession.interruptionNotification`) hoặc rút tai nghe (`routeChangeNotification`) trong `PlaybackService.swift`.
  3. Bổ sung `PlaybackService.visibilityOverrideScript` (inject qua cả `WKUserScript(..., injectionTime: .atDocumentStart, forMainFrameOnly: false)` trong `YouTubeWebView.swift` lẫn inline trong `buildEmbedHTML`) để ghi đè `document.hidden = false`, `document.visibilityState = 'visible'`, chặn `visibilitychange` bằng `stopImmediatePropagation()`, và tự gọi lại `player.playVideo()` nếu bị hệ thống auto-pause khi chuyển vào background (`UIApplication.didEnterBackgroundNotification`). Giữ ổn định `embedHTML` khi chuyển bài bằng `loadVideoById`.
  4. Tạo `Services/NowPlayingService.swift` tích hợp `MPNowPlayingInfoCenter` (tiêu đề, tên kênh, thời lượng, tiến độ, ảnh thumbnail bất đồng bộ có cache) và `MPRemoteCommandCenter` (Play, Pause, Toggle, Next, Previous, Seek) đồng bộ hai chiều với `PlaybackService`, `PlayerViewModel` và `SleepTimerService`.
- **Kiểm thử:** Chạy `./test.sh` đạt 40/40 file Swift typecheck 0 lỗi và toàn bộ unit test đạt 100%; kiểm tra `plutil -lint` hợp lệ cho `Resources/Info.plist` và `YTPlayer.xcodeproj/project.pbxproj`.
- **Trạng thái:** 🟢 Fixed

### [BG-002] Video trên ESign chưa tự động phát (Autoplay) & củng cố giữ luồng phát nền qua Mini Player + Keep-Alive PCM
- **Ngày phát hiện:** 2026-11-26
- **Mức độ:** Major
- **Nguyên nhân:**
  1. **Autoplay:** Với `customUserAgent` Mobile Safari (`iPhone`), YouTube IFrame API tự động bỏ qua tham số `playerVars.autoplay = 1` và dừng ở trạng thái `CUED (5)` nếu không gọi tường minh `player.playVideo()` ngay trong `onPlayerReady`.
  2. **Background Audio & Minimize:** Khi nhấn nút thu nhỏ `∨` trước đây `NavigationLink` hủy `PlayerView` làm mất `WKWebView`. Ngoài ra khi khóa màn hình iOS, tiến trình `WebKit.GPU` tạm dừng trực tiếp thẻ `<video>` trong khoảng ~100ms chuyển trạng thái khiến `SpringBoard` có thể treo IPC của `WebContent` trước khi lệnh `playVideo()` kịp chạy; ở chế độ Music kích thước khung `height: 1` cũng dễ bị WebKit đánh dấu `visuallyIdle`.
  3. **Bộ lọc nội dung (`ContentFilterService`):** Gọi `apply` bất đồng bộ sau `loadHTMLString` gây trễ gắn rule list; đồng thời theo chính sách YouTube & `AGENT_RULES.md`, không thể chặn máy chủ kiểm tra quảng cáo trong luồng video (`doubleclick.net`) vì sẽ kích hoạt lỗi khóa phát `152 - 4`.
- **Cách sửa:**
  1. Bổ sung `window.__ytTriggerAutoplay()` ngay trong `onPlayerReady` và khi `switchTrack` (có cơ chế retry 320ms/900ms và auto-unmute nếu bị chính sách di động giữ lại).
  2. Chuyển trình phát sang Persistent Player + **Mini Player** trong `ContentView` / `AppRouter` (bấm `∨` thu nhỏ xuống thanh Mini Player, giữ nguyên `WKWebView` kích thước tối thiểu `160x90`), kết hợp bộ giữ phiên `AVAudioPlayer` PCM siêu êm (`volume = 0.01`) trong `PlaybackService` và listener `pause` trực tiếp trên thẻ `<video>` bên trong iframe con (`__ytSyncGuard`).
  3. Biên dịch trước (`preload`) và gắn đồng bộ `WKContentRuleList` trong `ContentFilterService` cho các domain theo dõi web bên thứ ba mà không chạm tới hạ tầng luồng phát YouTube.
- **Trạng thái:** 🟢 Fixed
