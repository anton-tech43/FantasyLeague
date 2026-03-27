import SwiftUI

/// Main content feed showing published content items for the user's team.
/// Full implementation in task I7.
struct FeedView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if appState.feedItems.isEmpty {
                    EmptyStateView()
                } else {
                    ForEach(appState.feedItems) { item in
                        ContentCard(item: item)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle("Goal Digger")
    }
}
