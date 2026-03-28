import SwiftUI

struct WelcomeView: View {
    var onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Spacer()

            // Illustration placeholder
            VStack(spacing: 12) {
                Image(systemName: "message.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Theme.accentWarm)
                Image(systemName: "heart.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.accentSoft)
            }
            .frame(width: 200, height: 200)

            // App name
            Text("Goal Digger")
                .font(Theme.onboardingTitle)
                .foregroundStyle(Theme.textPrimary)

            // Tagline
            Text("Stay in the loop. Win the conversation.")
                .font(Theme.onboardingBody)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()

            // CTA Button
            Button(action: onGetStarted) {
                Text("Get Started")
                    .font(Theme.feedHeadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.accentWarm)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, Theme.screenPadding)
        .background(Theme.appBackground.ignoresSafeArea())
    }
}
