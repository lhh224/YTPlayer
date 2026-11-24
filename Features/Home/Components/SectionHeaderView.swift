// SectionHeaderView.swift
// YTPlayer — Features/Home/Components

import SwiftUI

struct SectionHeaderView: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Spacer()

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#if DEBUG
struct SectionHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            SectionHeaderView(title: "Thịnh hành")
            SectionHeaderView(
                title: "Video gợi ý",
                actionTitle: "Xem tất cả",
                action: { print("Xem tất cả tapped") }
            )
        }
        .previewLayout(.sizeThatFits)
    }
}
#endif
