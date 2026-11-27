import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    // MARK: - Brand & OLED Tokens
    static let ytRed = Color(red: 1.0, green: 0x3B / 255.0, blue: 0x30 / 255.0) // #FF3B30
    static let ytOLEDBackground = Color.black
    static let ytSurfaceOLED = Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0)
    static let ytSurfaceSecondary = Color(red: 0x2C / 255.0, green: 0x2C / 255.0, blue: 0x2E / 255.0)
    static let ytSubheadlineMuted = Color(red: 0x98 / 255.0, green: 0x98 / 255.0, blue: 0x9D / 255.0)

    // MARK: - Backgrounds
    #if canImport(UIKit)
    static let ytBackground = Color.black
    static let ytSurface = Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0)
    static let ytSurface2 = Color(red: 0x2C / 255.0, green: 0x2C / 255.0, blue: 0x2E / 255.0)
    static let ytTextPrimary = Color.white
    static let ytTextSecondary = Color(red: 0x98 / 255.0, green: 0x98 / 255.0, blue: 0x9D / 255.0)
    static let ytSeparator = Color.white.opacity(0.10)
    #else
    static let ytBackground = Color(NSColor.windowBackgroundColor)
    static let ytSurface = Color(NSColor.controlBackgroundColor)
    static let ytSurface2 = Color(NSColor.underPageBackgroundColor)
    static let ytTextPrimary = Color(NSColor.labelColor)
    static let ytTextSecondary = Color(NSColor.secondaryLabelColor)
    static let ytSeparator = Color(NSColor.separatorColor)
    #endif

    // Aliases used across Views
    static let ytPrimaryText = ytTextPrimary
    static let ytSecondaryText = ytTextSecondary

    // MARK: - Floating Bottom Tab Bar Tokens
    static let ytFloatingBarBackground = Color(red: 0x1C / 255.0, green: 0x1C / 255.0, blue: 0x1E / 255.0)
    static let ytFloatingBarSelection = Color(red: 0x48 / 255.0, green: 0x48 / 255.0, blue: 0x4A / 255.0)
    static let ytFloatingBarBorder = Color.white.opacity(0.10)

    // MARK: - Vibrant Mode Gradients
    static let ytModeGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0x3B / 255.0, blue: 0x30 / 255.0), Color(red: 1.0, green: 0x6A / 255.0, blue: 0x00 / 255.0)],
        startPoint: .leading,
        endPoint: .trailing
    )
}
