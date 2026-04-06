import SwiftUI

struct ContentCard: View {
    let item: ContentItem
    let appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.elementSpacing) {
            // Row 1: Badge + Timestamp
            HStack {
                BadgeView(type: item.type)
                Spacer()
                Text(item.publishedAt.relativeTimestamp)
                    .font(.feedTimestamp)
                    .foregroundColor(.textTertiary)
            }

            // Row 2: Headline (max 3 lines)
            Text(appState.personalise(item.headline))
                .font(.feedHeadline)
                .foregroundColor(.textPrimaryOnCard)
                .lineLimit(3)

            // Row 3: Read more
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Text("Read more")
                        .font(.feedTimestamp)
                        .foregroundColor(.accentWarm)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(.accentWarm)
                }
            }
        }
        .cardStyle()
    }
}
