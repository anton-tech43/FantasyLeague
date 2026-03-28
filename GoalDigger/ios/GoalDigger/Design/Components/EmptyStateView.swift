import SwiftUI

// TODO: Implement in I12
struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Text(title)
                .font(Theme.detailTitle)
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(Theme.onboardingBody)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.screenPadding)
    }
}
