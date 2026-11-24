import SwiftUI

// MARK: - PrimaryButtonStyle
struct PrimaryButtonStyle: ButtonStyle {
    var isFullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(YTFont.headline())
            .foregroundColor(.white)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.xl)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(Color.ytRed)
            .cornerRadius(CornerRadius.small)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - SecondaryButtonStyle
struct SecondaryButtonStyle: ButtonStyle {
    var isFullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(YTFont.headline())
            .foregroundColor(.ytRed)
            .padding(.vertical, Spacing.sm)
            .padding(.horizontal, Spacing.xl)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .background(Color.ytSurface)
            .cornerRadius(CornerRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .stroke(Color.ytRed, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
