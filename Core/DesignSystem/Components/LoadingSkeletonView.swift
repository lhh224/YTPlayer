import SwiftUI

// MARK: - Shimmer Modifier
private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.0), location: 0.0),
                            .init(color: Color.white.opacity(0.35), location: 0.5),
                            .init(color: Color.white.opacity(0.0), location: 1.0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: phase * geo.size.width * 2)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - LoadingSkeletonView
struct LoadingSkeletonView: View {
    var cornerRadius: CGFloat = CornerRadius.small
    var height: CGFloat = 16
    var width: CGFloat? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.ytSurface)
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - VideoCardSkeleton
struct VideoCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Thumbnail placeholder
            LoadingSkeletonView(cornerRadius: CornerRadius.small, height: 200)

            HStack(alignment: .top, spacing: Spacing.sm) {
                // Avatar placeholder
                Circle()
                    .fill(Color.ytSurface)
                    .frame(width: 36, height: 36)
                    .shimmer()

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    // Title lines
                    LoadingSkeletonView(height: 14)
                    LoadingSkeletonView(height: 14, width: 220)
                    // Channel + meta
                    LoadingSkeletonView(height: 12, width: 160)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.sm)
        }
    }
}

// MARK: - SkeletonList
struct SkeletonList: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.lg) {
                ForEach(0..<5, id: \.self) { _ in
                    VideoCardSkeleton()
                }
            }
        }
        .background(Color.ytBackground)
    }
}
