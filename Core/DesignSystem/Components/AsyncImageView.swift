import SwiftUI

struct AsyncImageView: View {
    let urlString: String
    let aspectRatio: CGFloat
    let cornerRadius: CGFloat

    init(urlString: String, aspectRatio: CGFloat = 16.0 / 9.0, cornerRadius: CGFloat = CornerRadius.small) {
        self.urlString = urlString
        self.aspectRatio = aspectRatio
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Color.clear
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay(
                Group {
                    if let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                thumbnailSkeleton
                            case .success(let image):
                                // Use scaledToFill() without overriding the image's natural aspect ratio
                                // so 4:3 YouTube thumbnails (hqdefault.jpg) automatically crop out
                                // their baked-in top/bottom black letterbox bars!
                                image
                                    .resizable()
                                    .scaledToFill()
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
            )
            .clipped()
            .cornerRadius(cornerRadius)
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
