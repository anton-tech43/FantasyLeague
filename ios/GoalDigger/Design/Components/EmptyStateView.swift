import SwiftUI

struct EmptyStateView: View {
    let teamName: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundColor(.textTertiary)

            Text("No updates yet")
                .font(.feedHeadline)
                .foregroundColor(.textOnDark.opacity(0.7))

            Text("We'll let you know when something happens with \(teamName).")
                .font(.onboardingBody)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)
        }
    }
}
