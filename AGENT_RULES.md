# AGENT RULES — YT Player

> Đây là quy tắc bắt buộc. Agent phải đọc file này trước khi thực hiện bất kỳ thao tác nào.

## Quy tắc chung

1. Đọc `YTPlayer_Agent_Project_Brief.md` và file này trước khi làm.
2. Chỉ làm đúng giai đoạn được giao. Không tự chuyển sang giai đoạn tiếp theo khi chưa có xác nhận.
3. Không triển khai toàn bộ dự án trong một prompt.
4. Trước khi sửa file, đọc nội dung hiện tại và hiểu ảnh hưởng.
5. Không xóa/ghi đè code đang hoạt động nếu chưa có lý do rõ ràng.
6. Không tạo nút hoặc chức năng giả chỉ để giao diện trông hoàn chỉnh.
7. Không báo hoàn thành nếu chưa kiểm thử.
8. Sau mỗi module lớn phải build và ghi kết quả vào `BUG_LOG.md`.
9. Ghi tiến độ vào `PROGRESS.md`.
10. Ghi lỗi, nguyên nhân và cách sửa vào `BUG_LOG.md`.
11. Không tự ý thay đổi kiến trúc, dependency, deployment target hoặc phiên bản toolchain.
12. Không commit API key, token, mật khẩu hoặc thông tin nhạy cảm.
13. Không sử dụng API nội bộ không chính thức hoặc kỹ thuật trích xuất stream.
14. Khi thiếu thông tin hoặc gặp giới hạn, nêu rõ giả định và hỏi người dùng; không tự bịa.
15. Mọi tính năng phải có tiêu chí nghiệm thu cụ thể.

## Quy tắc về YouTube & Playback

- Chỉ dùng YouTube Data API v3 cho tìm kiếm và metadata.
- Phát video qua YouTube Embedded Player hoặc phương thức chính thức được YouTube hỗ trợ.
- Không trích xuất luồng audio/video thô.
- Không reverse-engineer API nội bộ YouTube.
- Không giả lập client YouTube hay vượt qua cơ chế quảng cáo.
- Không hứa hẹn chặn quảng cáo trong video YouTube.
- Không dùng AVPlayer để phát trực tiếp mọi video YouTube.
- Chỉ dùng AVPlayer cho nguồn media mà ứng dụng có quyền và được phép phát.

## Quy tắc về môi trường

- Môi trường mục tiêu: Xcode 14.2, Swift 5.7, iOS SDK 16.2, macOS Monterey 12.7.6.
- Không tự ý nâng cấp macOS/Xcode/toolchain.
- Chỉ dùng API có sẵn trong phiên bản SDK mục tiêu.
- Hạn chế dependency bên ngoài; chỉ thêm khi có lý do và xác nhận tương thích.

## Tiêu chí nghiệm thu mỗi giai đoạn

Một giai đoạn chỉ được coi là hoàn thành khi:
- Có danh sách file đã tạo/sửa.
- Có mô tả chức năng thực tế.
- Build thành công hoặc ghi rõ lý do không thể build.
- Có kết quả kiểm thử.
- Không còn lỗi nghiêm trọng chưa báo cáo.
- Cập nhật `PROGRESS.md` và `BUG_LOG.md`.
- Nêu rõ giới hạn và việc còn lại.
- Chờ người dùng xác nhận trước khi tiếp tục.
