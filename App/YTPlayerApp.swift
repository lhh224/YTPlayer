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
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var router = AppRouter()
    @StateObject private var libraryRepo = LibraryRepository(context: CoreDataStack.shared.context)
    @StateObject private var settingsVM = SettingsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(router)
                .environmentObject(libraryRepo)
                .environmentObject(settingsVM)
                .onAppear {
                    Self.configureAudioSession()
                    NowPlayingService.shared.configureRemoteCommands()
                    PlaybackService.shared.registerSystemObserversIfNeeded()
                    PlaybackService.shared.prewarmNetworkAndPlayerCache()
                    ContentFilterService.shared.preloadIfNeeded()
                }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .active:
                PlaybackService.shared.recordScenePhase("active")
            case .inactive:
                PlaybackService.shared.recordScenePhase("inactive")
            case .background:
                PlaybackService.shared.recordScenePhase("background")
            @unknown default:
                PlaybackService.shared.recordScenePhase("unknown")
            }
        }
    }

    // MARK: - Audio Session Setup & Recovery

    /// Configures `AVAudioSession` for continuous background audio playback (`.playback`)
    /// and activates it once the main UI scene has appeared.
    static func configureAudioSession() {
        PlaybackService.shared.ensureAudioSessionConfiguredOnce()
    }
}
