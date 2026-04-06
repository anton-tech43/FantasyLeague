import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Illustration placeholder
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 70))
                .foregroundStyle(Color.hotRose)
                .padding(.bottom, 32)

            Text("Goal Digger")
                .font(.onboardingTitle)
                .foregroundColor(.textOnDark)
                .padding(.bottom, 12)

            Text("You're here. He has no idea.\nLet's get you ready.")
                .font(.onboardingBody)
                .foregroundColor(.textOnDark.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.screenPadding)

            Spacer()

            Button("Let's go") { onContinue() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, Layout.screenPadding)
                .padding(.bottom, 40)
        }
    }
}
