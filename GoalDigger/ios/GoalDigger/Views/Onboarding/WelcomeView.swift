import SwiftUI

/// Onboarding step 1: Welcome screen with app introduction.
/// Full implementation in task I6.
struct WelcomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack {
            Spacer()
            Text("Goal Digger")
                .font(.largeTitle.weight(.bold))
            Text("Placeholder — full design in I6")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Next") {
                withAnimation {
                    appState.onboardingStep = 1
                }
            }
            .padding()
        }
    }
}
