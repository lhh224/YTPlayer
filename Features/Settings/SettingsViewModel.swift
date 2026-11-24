// MARK: - SettingsViewModel.swift
// YTPlayer — Features/Settings/SettingsViewModel.swift
// Swift 5.7, iOS 16.0

import Foundation
import SwiftUI
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    enum Keys {
        static let isDarkMode = "isDarkMode"
        static let contentFilterEnabled = "contentFilterEnabled"
        static let sleepTimerMinutes = "sleepTimerMinutes"
    }

    enum APITestState: Equatable {
        case idle
        case testing
        case success(String)
        case failure(String)
    }

    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: Keys.isDarkMode)
        }
    }

    @Published var contentFilterEnabled: Bool {
        didSet {
            UserDefaults.standard.set(contentFilterEnabled, forKey: Keys.contentFilterEnabled)
            ContentFilterService.shared.isEnabled = contentFilterEnabled
        }
    }

    @Published var sleepTimerMinutes: Int {
        didSet {
            UserDefaults.standard.set(sleepTimerMinutes, forKey: Keys.sleepTimerMinutes)
        }
    }

    @Published var apiKeyInput: String = ""
    @Published var apiTestState: APITestState = .idle

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Phiên bản \(version) (\(build))"
    }

    init() {
        if UserDefaults.standard.object(forKey: Keys.isDarkMode) == nil {
            self.isDarkMode = true
        } else {
            self.isDarkMode = UserDefaults.standard.bool(forKey: Keys.isDarkMode)
        }
        self.contentFilterEnabled = UserDefaults.standard.object(forKey: Keys.contentFilterEnabled) as? Bool ?? true
        self.sleepTimerMinutes = UserDefaults.standard.object(forKey: Keys.sleepTimerMinutes) as? Int ?? 30
        self.apiKeyInput = YouTubeAPIService.shared.currentAPIKey
    }

    func saveAndTestAPIKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        YouTubeAPIService.shared.updateAPIKey(trimmed)
        apiTestState = .testing

        Task {
            do {
                let sampleTitle = try await YouTubeAPIService.shared.validateAPIKey(trimmed)
                apiTestState = .success("Kết nối YouTube Data API v3 thành công! (Mẫu kiểm tra: \(sampleTitle))")
            } catch {
                apiTestState = .failure(error.localizedDescription)
            }
        }
    }

    func clearCustomAPIKey() {
        apiKeyInput = ""
        YouTubeAPIService.shared.updateAPIKey("")
        apiTestState = .idle
    }

    func clearHistory(repo: LibraryRepository) {
        try? repo.clearHistory()
    }

    func resetSettings() {
        isDarkMode = true
        contentFilterEnabled = true
        sleepTimerMinutes = 30
    }
}
