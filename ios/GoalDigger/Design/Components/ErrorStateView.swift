import SwiftUI

/// Reusable error card. One source of truth for the look of any load-failure
/// surface across the app (Feed, ContentDetail, future surfaces).
///
/// Pair with `APIError.presentation` to get on-brand copy per failure type.
struct ErrorStateView: View {
    let title: String
    let body: String
    let buttonLabel: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.feedHeadline)
                .foregroundColor(.textPrimaryOnCard)
                .multilineTextAlignment(.center)
            Text(body)
                .font(.onboardingBody)
                .foregroundColor(.textSecondaryOnCard)
                .multilineTextAlignment(.center)
            Button(action: onRetry) {
                Text(buttonLabel)
                    .font(.feedHeadline)
                    .foregroundColor(.warmWhite)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.hotRose)
                    .cornerRadius(Layout.buttonCornerRadius)
            }
        }
        .padding(Layout.cardPadding)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
        .padding(.horizontal, Layout.screenPadding)
    }
}

extension ErrorStateView {
    /// Build an ErrorStateView from an APIError using its `presentation` copy.
    init(error: APIError, onRetry: @escaping () -> Void) {
        let p = error.presentation
        self.init(title: p.title, body: p.body, buttonLabel: p.button, onRetry: onRetry)
    }
}
