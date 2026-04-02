import SwiftUI

struct WelcomeView: View {
    var onGetStarted: () -> Void
    @State private var animate = false

    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Spacer()

            // Warm illustration
            ZStack {
                Circle()
                    .fill(Theme.accentSoft.opacity(0.3))
                    .frame(width: 150, height: 150)
                    .scaleEffect(animate ? 1.0 : 0.92)

                Text("💬")
                    .font(.system(size: 56))
                    .scaleEffect(animate ? 1.0 : 0.88)
            }
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animate)

            // App name — serif, editorial
            Text("Goal Digger")
                .font(Theme.onboardingTitle)
                .foregroundStyle(Theme.textPrimary)

            // Tagline — relationship-coded, not sporty
            VStack(spacing: 10) {
                Text("Your secret weapon for\nfootball conversations")
                    .font(Theme.detailBodyItalic)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                Text("We translate football into things\nyou'll actually want to say.")
                    .font(Theme.feedTimestamp)
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // CTA
            Button(action: onGetStarted) {
                Text("Get started")
                    .font(.system(.body, design: .rounded, weight: .semibold))
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
                    .shadow(color: Theme.accentWarm.opacity(0.2), radius: 10, y: 4)
            }

            Spacer().frame(height: 40)
        }
        .padding(.horizontal, Theme.screenPadding)
        .background(Theme.backgroundGradient.ignoresSafeArea())
        .onAppear { animate = true }
    }
}
