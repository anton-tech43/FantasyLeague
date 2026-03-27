import SwiftUI

/// Card component for displaying a content item in the feed.
/// Full implementation in task I12.
struct ContentCard: View {
    let item: ContentItem

    var body: some View {
        NavigationLink(value: item) {
            VStack(alignment: .leading, spacing: Theme.elementSpacing) {
                BadgeView(type: item.type)
                Text(item.headline)
                    .font(Theme.feedHeadline)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.leading)
                Text(item.publishedAt, style: .relative)
                    .font(Theme.feedTimestamp)
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}
