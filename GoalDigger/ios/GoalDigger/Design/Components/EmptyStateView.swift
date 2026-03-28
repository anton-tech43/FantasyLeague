import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    init(icon: String = "bubble.left.and.bubble.right", title: String, message: String) {
        self.icon = icon
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundStyle(Theme.textTertiary)

            Text(title)
                .font(Theme.feedHeadline)
                .foregroundStyle(Theme.textSecondary)

            Text(message)
                .font(Theme.onboardingBody)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .padding(Theme.screenPadding)
    }
}
