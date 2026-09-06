import SwiftUI

struct EmptyStateView: View {
    let teamName: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(.textTertiary)

            Text("Quiet on his end.")
                .font(.feedHeadline)
                .foregroundColor(.textOnDark.opacity(0.7))

            Text("Nothing from \(teamName) worth reporting. Enjoy it while it lasts.")
                .font(.onboardingBody)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)
        }
    }
}
