// MARK: - SettingsView.swift
// YTPlayer — Features/Settings/SettingsView.swift
// Swift 5.7, iOS 16.0

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var vm: SettingsViewModel
    @EnvironmentObject var libraryRepo: LibraryRepository
    @State private var showClearConfirm = false

    var body: some View {
        navigationContainer {
            Form {
                // MARK: - Phát trong nền
                Section(
                    header: Text("Phát nhạc & Video"),
                    footer: Text("Duy trì phát âm thanh qua AVAudioSession và điều khiển từ Màn hình khóa (Lock Screen) hoặc Control Center khi tắt màn hình iPhone.")
                ) {
                    Toggle("Phát nhạc trong nền (Background Audio)", isOn: $vm.backgroundPlaybackEnabled)
                }

                // MARK: - Giao diện
                Section(header: Text("Giao diện")) {
                    Toggle("Chế độ tối (Dark Mode)", isOn: $vm.isDarkMode)
                }

                // MARK: - Nội dung & Bảo vệ
                Section(
                    header: Text("Bộ lọc nội dung web"),
                    footer: Text("Lọc các mã theo dõi và quảng cáo web của bên thứ ba trong phạm vi ứng dụng kiểm soát. Không can thiệp hoặc né quảng cáo trong trình phát nhúng của YouTube.")
                ) {
                    Toggle("Lọc theo dõi & nội dung web", isOn: $vm.contentFilterEnabled)
                }

                // MARK: - Hẹn giờ ngủ
                Section(header: Text("Hẹn giờ tắt (Sleep Timer)")) {
                    SleepTimerView()
                }

                // MARK: - Dữ liệu
                Section(header: Text("Dữ liệu & Quyền riêng tư")) {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Xóa lịch sử xem")
                        }
                    }
                }

                // MARK: - Thông tin ứng dụng
                Section(
                    header: Text("Thông tin"),
                    footer: Text("Ứng dụng tuân thủ điều khoản dịch vụ của YouTube Data API v3. Mọi nội dung và bản quyền video thuộc về YouTube và các chủ sở hữu tương ứng.")
                ) {
                    HStack {
                        Text("Phiên bản")
                        Spacer()
                        Text(vm.appVersion)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Nền tảng phát")
                        Spacer()
                        Text("YouTube IFrame API")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Dữ liệu & Tìm kiếm")
                        Spacer()
                        Text("YouTube Data API v3")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Cài đặt")
            .confirmationDialog(
                "Xác nhận xóa lịch sử xem?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Xóa tất cả", role: .destructive) {
                    vm.clearHistory(repo: libraryRepo)
                }
                Button("Hủy", role: .cancel) {}
            } message: {
                Text("Lịch sử xem lưu trên thiết bị này sẽ bị xóa hoàn toàn.")
            }
        }
    }

    @ViewBuilder
    private func navigationContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        #if os(iOS)
        NavigationStack {
            content()
        }
        #else
        NavigationView {
            content()
        }
        #endif
    }
}
