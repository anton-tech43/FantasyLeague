import SwiftUI

/// Empty state shown when there are no content items in the feed.
/// Full implementation in task I12.
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: Theme.sectionSpacing) {
            Image(systemName: "sportscourt")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textTertiary)
            Text("No stories yet")
                .font(Theme.detailTitle)
                .foregroundStyle(Theme.textPrimary)
            Text("We're working on your first update.\nCheck back soon!")
                .font(Theme.detailBody)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
