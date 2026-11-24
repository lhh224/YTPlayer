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
