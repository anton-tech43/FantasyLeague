import SwiftUI

struct WelcomeView: View {
    var onGetStarted: () -> Void
    @State private var animate = false

    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Spacer()

            // Playful emoji composition
            ZStack {
                Circle()
                    .fill(Theme.accentSoft.opacity(0.4))
                    .frame(width: 160, height: 160)
                    .scaleEffect(animate ? 1.0 : 0.9)

                VStack(spacing: 4) {
                    Text("⚽💕")
                        .font(.system(size: 50))
                    Text("💬")
                        .font(.system(size: 36))
                }
                .scaleEffect(animate ? 1.0 : 0.85)
            }
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animate)

            // App name
            Text("Goal Digger")
                .font(Theme.onboardingTitle)
                .foregroundStyle(Theme.textPrimary)

            // Tagline — conversational, not corporate
            VStack(spacing: 8) {
                Text("Football chat made easy.")
                    .font(Theme.onboardingBody)
                    .foregroundStyle(Theme.textSecondary)

                Text("Like your best friend who actually\nwatches the games.")
                    .font(Theme.feedTimestamp)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // CTA Button
            Button(action: onGetStarted) {
                Text("Let's go ✨")
                    .font(Theme.feedHeadline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [Theme.accentWarm, Theme.accentPeach],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Theme.accentWarm.opacity(0.3), radius: 8, y: 4)
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, Theme.screenPadding)
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .onAppear { animate = true }
    }
}
