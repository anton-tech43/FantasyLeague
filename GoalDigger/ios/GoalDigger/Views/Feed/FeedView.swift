import SwiftUI

// TODO: Implement in I7
struct FeedView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: Theme.cardSpacing) {
                    // Content cards will go here
                }
                .padding(.horizontal, Theme.screenPadding)
            }
            .background(Theme.appBackground)
            .navigationTitle(appState.selectedTeam?.shortName ?? "Goal Digger")
        }
    }
}
