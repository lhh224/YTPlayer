// LibraryItemRowView.swift
// YTPlayer — Features/Library/Components

import SwiftUI

struct LibraryItemRowView: View {
    let video: VideoItem
    let subtitle: String
    var onDelete: (() -> Void)? = nil

    init(video: VideoItem, subtitle: String, onDelete: (() -> Void)? = nil) {
        self.video = video
        self.subtitle = subtitle
        self.onDelete = onDelete
    }

    var body: some View {
        HStack(spacing: 12) {
            AsyncImageView(urlString: video.thumbnailURL)
                .frame(width: 120, height: 68)
                .cornerRadius(6)
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if !video.duration.isEmpty {
                    Text(video.duration)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.ytSurface)
                        .cornerRadius(4)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if let onDelete = onDelete {
                Button("Xóa", role: .destructive, action: onDelete)
            }
        }
    }
}
