import SwiftUI

// MARK: - WelcomeView
// First onboarding screen — sets the "relationship translator" tone.
//
// Design decisions for other agents:
// - Tagline: "Your secret weapon for football conversations" — frames the app as a tool, not a sports tracker
// - Breathing animation on the heart icon adds warmth and life
// - Gradient CTA button matches new design system
// - Serif title font for editorial feel

struct WelcomeView: View {
    var onGetStarted: () -> Void
    @State private var isBreathing = false

    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Spacer()

            // Illustration with breathing animation
            VStack(spacing: 12) {
                Image(systemName: "message.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Theme.accentPink)
                Image(systemName: "heart.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.accentPeach)
                    .scaleEffect(isBreathing ? 1.15 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isBreathing
                    )
            }
            .frame(width: 200, height: 200)
            .onAppear { isBreathing = true }

            // App name
            Text("Goal Digger")
                .font(Theme.onboardingTitle)
                .foregroundStyle(Theme.textPrimary)

            // Tagline — relationship translator framing
            Text("Your secret weapon for\nfootball conversations")
                .font(Theme.onboardingBody)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()

            // Gradient CTA Button
            Button(action: onGetStarted) {
                Text("Get Started")
                    .gradientButton()
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, Theme.screenPadding)
        .background(Theme.backgroundGradient.ignoresSafeArea())
    }
}
