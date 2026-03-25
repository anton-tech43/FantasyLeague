import SwiftUI

/// First onboarding screen. Warm, inviting, communicates what
/// the app does without mentioning "football stats."
struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Illustration placeholder (200x200pt area)
            VStack(spacing: 4) {
                Text("Goal")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.accentWarm)
                Text("Digger")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
            }
            .frame(width: 200, height: 200)

            Text("Goal Digger")
                .font(.onboardingTitle)
                .foregroundColor(.textPrimary)
                .padding(.top, Layout.sectionSpacing)

            Text("Stay in the loop. Win the conversation.")
                .font(.onboardingBody)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, Layout.elementSpacing)

            Spacer()

            Button(action: onContinue) {
                Text("Get Started")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.accentWarm)
                    .cornerRadius(16)
            }
            .padding(.horizontal, Layout.screenPadding)
            .padding(.bottom, 40)
        }
        .background(Color.appBackground)
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
