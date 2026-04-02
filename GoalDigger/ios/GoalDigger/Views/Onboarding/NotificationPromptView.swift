import SwiftUI

struct NotificationPromptView: View {
    @Environment(AppState.self) private var appState
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Spacer()

            // Icon
            Image(systemName: "bell.badge")
                .font(.system(size: 60))
                .foregroundStyle(Theme.accentWarm)

            // Title
            Text("Don't miss the\ngood stuff")
                .font(Theme.onboardingTitle)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)

            // Body
            Text("We'll ping you when something interesting happens — just the highlights, never spam. Promise.")
                .font(Theme.onboardingBody)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Spacer()

            // Primary CTA
            Button {
                Task {
                    _ = await NotificationService.shared.requestPermission()
                    completeOnboarding()
                }
            } label: {
                Text("Turn on Notifications")
                    .font(Theme.feedHeadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.accentWarm)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            // Secondary CTA
            Button {
                completeOnboarding()
            } label: {
                Text("Maybe Later")
                    .font(Theme.onboardingBody)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, Theme.screenPadding)
        .background(Theme.appBackground.ignoresSafeArea())
    }

    private func completeOnboarding() {
        appState.notificationPermissionRequested = true
        // Don't set hasCompletedOnboarding here — the celebration screen does that
        onComplete()
    }
}
