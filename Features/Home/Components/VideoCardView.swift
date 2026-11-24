import SwiftUI

struct VideoCardView: View {
    let video: VideoItem

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Thumbnail 16:9 with duration badge
            ZStack(alignment: .bottomTrailing) {
                AsyncImageView(urlString: video.thumbnailURL)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipped()

                if !video.duration.isEmpty {
                    Text(video.duration)
                        .font(.ytCaption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(4)
                        .padding(Spacing.sm)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.sm)

            // Info
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(video.title)
                    .font(.ytBodyMedium)
                    .foregroundColor(.ytPrimaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Spacing.xs) {
                    Text(video.channelName)
                        .font(.ytCaption)
                        .foregroundColor(.ytSecondaryText)

                    if !video.formattedViewCount.isEmpty {
                        Text("•")
                            .foregroundColor(.ytSecondaryText)
                        Text(video.formattedViewCount)
                            .font(.ytCaption)
                            .foregroundColor(.ytSecondaryText)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.md)
        }
    }
}

struct VideoCardView_Previews: PreviewProvider {
    static var previews: some View {
        VideoCardView(video: VideoItem.mockItems[0])
            .previewLayout(.sizeThatFits)
    }
}
