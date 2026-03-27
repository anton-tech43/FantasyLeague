import SwiftUI

/// Onboarding step 3: Notification permission request.
/// Full implementation in task I6.
struct NotificationPromptView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack {
            Text("Stay in the Loop")
                .font(.title2.weight(.bold))
            Text("Placeholder — full design in I6")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}
