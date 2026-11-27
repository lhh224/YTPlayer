import SwiftUI

struct VideoCardView: View {
    let video: VideoItem
    var onMoreTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Full-Width Edge-to-Edge 16:9 Thumbnail & Duration badge (zero side/letterbox bars)
            ZStack(alignment: .bottomTrailing) {
                AsyncImageView(urlString: video.thumbnailURL, aspectRatio: 16.0 / 9.0, cornerRadius: 0)
                    .frame(maxWidth: .infinity)

                if !video.duration.isEmpty {
                    Text(video.duration)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(4)
                        .padding(10)
                }
            }

            // Info row: Title, Channel + Views, 3-dots Menu
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 4) {
                        Text(video.channelName)
                            .font(.system(size: 12))
                            .foregroundColor(Color.ytSubheadlineMuted)
                            .lineLimit(1)

                        if !video.formattedViewCount.isEmpty {
                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(Color.ytSubheadlineMuted)
                            Text(video.formattedViewCount)
                                .font(.system(size: 12))
                                .foregroundColor(Color.ytSubheadlineMuted)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 4)

                Menu {
                    Button {
                        PlaybackService.shared.playbackQueue.append(video)
                    } label: {
                        Label("Phát tiếp theo", systemImage: "text.insert")
                    }

                    Button {
                        onMoreTap?()
                    } label: {
                        Label("Lưu vào danh sách phát", systemImage: "text.badge.plus")
                    }

                    Button {
                        shareVideo()
                    } label: {
                        Label("Chia sẻ", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.ytSubheadlineMuted)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func shareVideo() {
        guard let url = URL(string: "https://www.youtube.com/watch?v=\(video.id)") else { return }
        #if canImport(UIKit)
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        #endif
    }
}

struct VideoCardView_Previews: PreviewProvider {
    static var previews: some View {
        VideoCardView(video: VideoItem.mockItems[0])
            .previewLayout(.sizeThatFits)
    }
}
