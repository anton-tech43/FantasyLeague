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
                Text(relativeTimestamp(item.publishedAt))
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
                        .foregroundColor(.hotRose)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(.hotRose)
                }
            }
        }
        .cardStyle()
    }

    private func relativeTimestamp(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 3600 {
            let minutes = max(1, Int(interval / 60))
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else if interval < 172800 {
            return "Yesterday"
        } else {
            let days = Int(interval / 86400)
            return "\(days) days ago"
        }
    }
}
