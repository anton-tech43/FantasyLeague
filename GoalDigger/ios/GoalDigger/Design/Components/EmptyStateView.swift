import SwiftUI

/// Reusable empty/error state view with icon, title, and message.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Layout.elementSpacing) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.textTertiary)

            Text(title)
                .font(.feedHeadline)
                .foregroundColor(.textSecondary)

            Text(message)
                .font(.onboardingBody)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        icon: "bubble.left.and.bubble.right",
        title: "No updates yet",
        message: "We'll let you know when something happens with Arsenal."
    )
    .background(Color.appBackground)
}
