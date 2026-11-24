import SwiftUI

struct AsyncImageView: View {
    let urlString: String
    let aspectRatio: CGFloat

    init(urlString: String, aspectRatio: CGFloat = 16.0 / 9.0) {
        self.urlString = urlString
        self.aspectRatio = aspectRatio
    }

    var body: some View {
        Group {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        thumbnailSkeleton
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(aspectRatio, contentMode: .fill)
                    case .failure:
                        thumbnailFailure
                    @unknown default:
                        thumbnailSkeleton
                    }
                }
            } else {
                thumbnailFailure
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .cornerRadius(CornerRadius.small)
        .clipped()
    }

    // MARK: - Private Views
    private var thumbnailSkeleton: some View {
        Color.ytSurface
            .shimmer()
    }

    private var thumbnailFailure: some View {
        ZStack {
            Color.ytSurface2
            Image(systemName: "photo")
                .font(.system(size: 32))
                .foregroundColor(.ytTextSecondary)
        }
    }
}
