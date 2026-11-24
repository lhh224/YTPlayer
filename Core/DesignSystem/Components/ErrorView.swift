import SwiftUI

struct ErrorView: View {
    let error: Error
    let retryAction: (() -> Void)?

    init(error: Error, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.ytRed)

            Text("Đã xảy ra lỗi")
                .ytHeadline()

            Text(error.localizedDescription)
                .ytBody()
                .foregroundColor(.ytTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xxl)

            if let retryAction = retryAction {
                Button(action: retryAction) {
                    Text("Thử lại")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, Spacing.sm)
            }
        }
        .padding(Spacing.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ytBackground)
    }
}
