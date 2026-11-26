// MARK: - YTPlayerApp.swift
// YTPlayer — App/YTPlayerApp.swift
// Swift 5.7, iOS 16.0

import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

@main
struct YTPlayerApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var libraryRepo = LibraryRepository(context: CoreDataStack.shared.context)
    @StateObject private var settingsVM = SettingsViewModel()

    init() {
        Self.configureAudioSession()
        NowPlayingService.shared.configureRemoteCommands()
        PlaybackService.shared.registerSystemObserversIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(router)
                .environmentObject(libraryRepo)
                .environmentObject(settingsVM)
        }
    }

    // MARK: - Audio Session Setup & Recovery

    /// Configures `AVAudioSession` for continuous background audio playback (`.playback`)
    /// and activates it immediately on app launch.
    static func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("[YTPlayerApp] Failed to configure AVAudioSession: \(error.localizedDescription)")
        }
        #endif
    }
}
