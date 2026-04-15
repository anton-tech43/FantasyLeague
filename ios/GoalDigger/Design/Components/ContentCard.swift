import SwiftUI

struct ContentCard: View {
    let item: ContentItem
    let appState: AppState
    let feedContext: FeedContext

    private var isEveryoneContext: Bool {
        feedContext == .everyoneTalking
    }

    private var displayHeadline: String {
        if isEveryoneContext {
            return item.everyoneTalkingHeadline ?? item.headline
        }
        return appState.personalise(item.headline)
    }

    private var displayTalkingPoint: String? {
        if isEveryoneContext {
            return item.everyoneTalkingTalkingPoints?.first
        }
        return item.regularTalkingPoints.first.map { appState.personalise($0) }
    }

    private var badgeLabel: String? {
        isEveryoneContext ? "FOOTBALL" : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.elementSpacing) {
            // Row 1: Badge + Timestamp
            HStack {
                BadgeView(type: item.type, customLabel: badgeLabel)
                Spacer()
                Text(item.publishedAt.relativeTimestamp)
                    .font(.feedTimestamp)
                    .foregroundColor(.textTertiary)
            }

            // Row 2: Headline (max 3 lines)
            Text(displayHeadline)
                .font(.feedHeadline)
                .foregroundColor(.textPrimaryOnCard)
                .lineLimit(3)

            // Row 3: Talking point teaser (if available)
            if let firstPoint = displayTalkingPoint {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 11))
                        .foregroundColor(.hotRose)
                    Text(firstPoint)
                        .font(.feedTimestamp)
                        .foregroundColor(.hotRose.opacity(0.6))
                        .lineLimit(1)
                }
            }

            // Row 4: Read more
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
}
