import SwiftUI

// MARK: - Font Factory
enum YTFont {
    static func largeTitle() -> Font {
        .system(size: 34, weight: .bold, design: .default)
    }

    static func title(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static func headline() -> Font {
        .system(size: 17, weight: .semibold, design: .default)
    }

    static func body() -> Font {
        .system(size: 15, weight: .regular, design: .default)
    }

    static func bodyMedium() -> Font {
        .system(size: 15, weight: .medium, design: .default)
    }

    static func subheadline() -> Font {
        .system(size: 13, weight: .regular, design: .default)
    }

    static func caption() -> Font {
        .system(size: 12, weight: .regular, design: .default)
    }

    static func caption2() -> Font {
        .system(size: 11, weight: .regular, design: .default)
    }
}

extension Font {
    static let ytLargeTitle = YTFont.largeTitle()
    static let ytHeadline = YTFont.headline()
    static let ytBody = YTFont.body()
    static let ytBodyMedium = YTFont.bodyMedium()
    static let ytSubheadline = YTFont.subheadline()
    static let ytCaption = YTFont.caption()
    static let ytCaption2 = YTFont.caption2()
}

// MARK: - ViewModifiers
struct YTTitleModifier: ViewModifier {
    let size: CGFloat
    func body(content: Content) -> some View {
        content
            .font(YTFont.title(size))
            .foregroundColor(.ytTextPrimary)
    }
}

struct YTHeadlineModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(YTFont.headline())
            .foregroundColor(.ytTextPrimary)
    }
}

struct YTBodyModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(YTFont.body())
            .foregroundColor(.ytTextPrimary)
    }
}

struct YTSubheadlineModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(YTFont.subheadline())
            .foregroundColor(.ytTextSecondary)
    }
}

struct YTCaptionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(YTFont.caption())
            .foregroundColor(.ytTextSecondary)
    }
}

// MARK: - View Extensions
extension View {
    func ytTitle(size: CGFloat = 28) -> some View {
        modifier(YTTitleModifier(size: size))
    }

    func ytHeadline() -> some View {
        modifier(YTHeadlineModifier())
    }

    func ytBody() -> some View {
        modifier(YTBodyModifier())
    }

    func ytSubheadline() -> some View {
        modifier(YTSubheadlineModifier())
    }

    func ytCaption() -> some View {
        modifier(YTCaptionModifier())
    }
}
