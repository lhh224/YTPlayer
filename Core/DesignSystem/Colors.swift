import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    // MARK: - Brand
    static let ytRed = Color(red: 1.0, green: 0.0, blue: 0.0)

    // MARK: - Backgrounds
    #if canImport(UIKit)
    static let ytBackground = Color(UIColor.systemBackground)
    static let ytSurface = Color(UIColor.secondarySystemBackground)
    static let ytSurface2 = Color(UIColor.tertiarySystemBackground)
    static let ytTextPrimary = Color(UIColor.label)
    static let ytTextSecondary = Color(UIColor.secondaryLabel)
    static let ytSeparator = Color(UIColor.separator)
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
}
