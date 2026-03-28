import SwiftUI

// TODO: Implement in I6
struct WelcomeView: View {
    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Spacer()
            Text("Goal Digger")
                .font(Theme.onboardingTitle)
                .foregroundStyle(Theme.textPrimary)
            Text("Football news your way — warm, fun, and easy to talk about.")
                .font(Theme.onboardingBody)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(Theme.screenPadding)
        .background(Theme.appBackground)
    }
}
