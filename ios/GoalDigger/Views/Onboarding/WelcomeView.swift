import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.hotRose)

                GoalDiggerWordmark(size: .jakarta(34, weight: .bold))

                Text("You're here. He has no idea.\nLet's get you ready.")
                    .font(.onboardingBody)
                    .foregroundColor(.textOnDark.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Layout.screenPadding)
            }

            Spacer()

            Button("Let's go") { onContinue() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Layout.screenPadding)
                .padding(.bottom, 40)
        }
    }
}
