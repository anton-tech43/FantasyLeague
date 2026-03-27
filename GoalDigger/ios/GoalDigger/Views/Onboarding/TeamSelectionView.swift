import SwiftUI

/// Onboarding step 2: Team selection.
/// Full implementation in task I6.
struct TeamSelectionView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack {
            Text("Pick Your Team")
                .font(.title2.weight(.bold))
            Text("Placeholder — full design in I6")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}
