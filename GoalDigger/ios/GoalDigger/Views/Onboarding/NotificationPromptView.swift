import SwiftUI

// TODO: Implement in I6
struct NotificationPromptView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Spacer()
            Text("Stay in the loop")
                .font(Theme.onboardingTitle)
                .foregroundStyle(Theme.textPrimary)
            Text("Get notified when there's something worth talking about.")
                .font(Theme.onboardingBody)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(Theme.screenPadding)
        .background(Theme.appBackground)
    }
}
