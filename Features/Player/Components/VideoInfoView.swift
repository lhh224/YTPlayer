// VideoInfoView.swift
// YTPlayer — Features/Player/Components

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct VideoInfoView: View {
    let video: VideoItem
    let isFavorite: Bool
    let onFavoriteTap: () -> Void
    var onAddToPlaylistTap: (() -> Void)? = nil

    @State private var isDescriptionExpanded = false
    @State private var copiedLink = false

    init(
        video: VideoItem,
        isFavorite: Bool,
        onFavoriteTap: @escaping () -> Void,
        onAddToPlaylistTap: (() -> Void)? = nil
    ) {
        self.video = video
        self.isFavorite = isFavorite
        self.onFavoriteTap = onFavoriteTap
        self.onAddToPlaylistTap = onAddToPlaylistTap
    }

    private var watchURLString: String {
        "https://www.youtube.com/watch?v=\(video.id)"
    }

    private var channelURLString: String {
        if !video.channelId.isEmpty {
            return "https://www.youtube.com/channel/\(video.channelId)"
        }
        return watchURLString
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(video.title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(3)
                .foregroundColor(.primary)

            // Channel Row + Dark-Red Subscribe Pill
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.ytRed)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(video.channelName.prefix(2)).uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(video.channelName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if !video.formattedViewCount.isEmpty {
                        Text(video.formattedViewCount)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if let chURL = URL(string: channelURLString) {
                    Link(destination: chURL) {
                        Text("Subscribe")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.ytRed.opacity(0.85)))
                    }
                }
            }

            // Unified Row of 4 Modern Pill Buttons: [ ♡ Yêu thích ] [ + Danh sách phát ] [ 🔗 Sao chép ] [ ↗ YouTube ]
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button(action: onFavoriteTap) {
                        HStack(spacing: 5) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(isFavorite ? .ytRed : .primary)
                            Text(isFavorite ? "Đã thích" : "Yêu thích")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.ytSurface))
                        .overlay(Capsule().stroke(Color.ytSeparator, lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)

                    if let onAddToPlaylistTap = onAddToPlaylistTap {
                        Button(action: onAddToPlaylistTap) {
                            HStack(spacing: 5) {
                                Image(systemName: "plus")
                                    .foregroundColor(.ytRed)
                                Text("Danh sách phát")
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.ytSurface))
                            .overlay(Capsule().stroke(Color.ytSeparator, lineWidth: 0.6))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        copyVideoLink()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: copiedLink ? "checkmark" : "link")
                            Text(copiedLink ? "Đã chép" : "Sao chép")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color.ytSurface))
                        .overlay(Capsule().stroke(Color.ytSeparator, lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)

                    if let url = URL(string: watchURLString) {
                        Link(destination: url) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.up.right")
                                Text("YouTube")
                            }
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color.ytSurface))
                            .overlay(Capsule().stroke(Color.ytSeparator, lineWidth: 0.6))
                        }
                    }
                }
            }

            // Expandable "Mô tả video" Card
            if !video.description.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Mô tả video")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(isDescriptionExpanded ? "Thu gọn" : "Xem thêm")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Text(video.description)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(isDescriptionExpanded ? nil : 3)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.ytSurface))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.ytSeparator, lineWidth: 0.5))
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDescriptionExpanded.toggle()
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func copyVideoLink() {
        #if canImport(UIKit)
        UIPasteboard.general.string = watchURLString
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(watchURLString, forType: .string)
        #endif
        copiedLink = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedLink = false
        }
    }
}
