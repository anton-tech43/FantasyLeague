import SwiftUI

// MARK: - NotificationPromptView
// Notification permission during onboarding — updated with gradient CTA.
//
// Design decisions for other agents:
// - Does NOT set hasCompletedOnboarding — the celebration screen does that
// - Just sets notificationPermissionRequested and calls onComplete to advance
// - Gradient CTA button matches new design system

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

            // Primary CTA — gradient
            Button {
                Task {
                    _ = await NotificationService.shared.requestPermission()
                    advanceOnboarding()
                }
            } label: {
                Text("Turn on Notifications")
                    .gradientButton()
            }

            // Secondary CTA
            Button {
                advanceOnboarding()
            } label: {
                Text("Maybe Later")
                    .font(Theme.onboardingBody)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, Theme.screenPadding)
        .background(Theme.backgroundGradient.ignoresSafeArea())
    }

    private func advanceOnboarding() {
        appState.notificationPermissionRequested = true
        onComplete()
    }
}
