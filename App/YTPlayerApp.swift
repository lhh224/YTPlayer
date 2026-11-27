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

// MARK: - Orientation Manager (Portrait <-> Landscape Fullscreen)

enum OrientationManager {
    static func rotateToLandscape() {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscapeRight)
                windowScene.requestGeometryUpdate(prefs) { _ in }
                windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
        #endif
    }

    static func rotateToPortrait() {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
                windowScene.requestGeometryUpdate(prefs) { _ in }
                windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
        #endif
    }
}
