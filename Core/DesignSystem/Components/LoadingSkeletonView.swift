import SwiftUI

// MARK: - Shimmer Modifier
private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white.opacity(0.0), location: 0.0),
                                .init(color: Color.white.opacity(0.18), location: 0.5),
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
                        .easeInOut(duration: 1.6)
                        .repeatForever(autoreverses: false)
                    ) {
                        phase = 1
                    }
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
    var cornerRadius: CGFloat = 8
    var height: CGFloat = 16
    var width: CGFloat? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(red: 0x24 / 255.0, green: 0x24 / 255.0, blue: 0x26 / 255.0))
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - VideoCardSkeleton (Matching Image 1)
struct VideoCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 16:9 Thumbnail placeholder with bottom-right duration badge
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0x20 / 255.0, green: 0x20 / 255.0, blue: 0x22 / 255.0))
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .shimmer()

                // Duration placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0x16 / 255.0, green: 0x16 / 255.0, blue: 0x18 / 255.0))
                    .frame(width: 44, height: 18)
                    .padding(10)
            }
            .padding(.horizontal, 16)

            // Info row: Avatar + Title lines + 3-dots menu placeholder
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color(red: 0x24 / 255.0, green: 0x24 / 255.0, blue: 0x26 / 255.0))
                    .frame(width: 36, height: 36)
                    .shimmer()

                VStack(alignment: .leading, spacing: 6) {
                    LoadingSkeletonView(cornerRadius: 4, height: 13, width: nil)
                    LoadingSkeletonView(cornerRadius: 4, height: 11, width: 180)
                }

                Spacer(minLength: 4)

                // 3 dots menu placeholder
                VStack(spacing: 3) {
                    Circle().fill(Color(red: 0x36 / 255.0, green: 0x36 / 255.0, blue: 0x38 / 255.0)).frame(width: 3.5, height: 3.5)
                    Circle().fill(Color(red: 0x36 / 255.0, green: 0x36 / 255.0, blue: 0x38 / 255.0)).frame(width: 3.5, height: 3.5)
                    Circle().fill(Color(red: 0x36 / 255.0, green: 0x36 / 255.0, blue: 0x38 / 255.0)).frame(width: 3.5, height: 3.5)
                }
                .padding(.top, 4)
                .padding(.trailing, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }
}

// MARK: - SkeletonList
struct SkeletonList: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { _ in
                    VideoCardSkeleton()
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .background(Color.black.ignoresSafeArea())
    }
}
