import SwiftUI

/// A feed card representing one ContentItem.
struct ContentCard: View {
    let item: ContentItem

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
            Text(item.headline)
                .font(.feedHeadline)
                .foregroundColor(.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            // Row 3: "Read more" right-aligned
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

    // MARK: - Relative Timestamp

    private func relativeTimestamp(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if hours < 1 {
            return "Just now"
        } else if hours < 24 {
            return "\(hours)h ago"
        } else if days == 1 {
            return "Yesterday"
        } else if days < 7 {
            return "\(days) days ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
    }
}

#Preview {
    ContentCard(item: MockData.newsItem)
        .padding()
        .background(Color.appBackground)
}
