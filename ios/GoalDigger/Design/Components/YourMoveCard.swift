import SwiftUI

struct YourMoveCard: View {
    let item: ContentItem
    let appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Tag
            Text("YOUR MOVE")
                .font(.feedBadge)
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundColor(.warmWhite)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(Color.charcoal)
                .cornerRadius(Layout.badgeCornerRadius)

            // Headline
            Text(appState.personalise(item.headline))
                .font(.feedHeadline)
                .foregroundColor(.warmWhite)
                .lineLimit(3)

            // First talking point teaser
            if let firstPoint = item.regularTalkingPoints.first {
                Text(appState.personalise(firstPoint))
                    .font(.feedTimestamp)
                    .foregroundColor(.warmWhite.opacity(0.8))
                    .lineLimit(2)
            }

            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.warmWhite.opacity(0.6))
            }
        }
        .padding(Layout.cardPadding)
        .background(Color.hotRose)
        .cornerRadius(Layout.cardCornerRadius)
    }

    /// Picks the most relevant item from the feed for YOUR MOVE.
    /// Priority: match day today > big news last 24h > most recent with talking points.
    static func pickRelevantItem(from items: [ContentItem]) -> ContentItem? {
        let now = Date()
        let calendar = Calendar.current

        // Priority 1: Match day item if today has a match
        if let matchday = items.first(where: { item in
            item.type == .matchday &&
            item.kickoffTime.map { calendar.isDateInToday($0) } == true
        }) {
            return matchday
        }

        // Priority 2: Big news from last 24 hours (exciting/bad_news/drama emotional context)
        let bigNewsContexts = ["exciting", "bad_news", "drama"]
        if let bigNews = items.first(where: { item in
            now.timeIntervalSince(item.publishedAt) < 86400 &&
            item.emotionalContext.map { bigNewsContexts.contains($0) } == true
        }) {
            return bigNews
        }

        // Priority 3: Most recent item that has talking points
        return items.first(where: { !$0.regularTalkingPoints.isEmpty })
    }
}
