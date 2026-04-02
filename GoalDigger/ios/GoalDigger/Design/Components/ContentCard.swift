import SwiftUI

struct ContentCard: View {
    let item: ContentItem

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.elementSpacing) {
            // Row 1: Badge + Mood + Timestamp
            HStack {
                badgeView

                if let mood = item.moodEmoji {
                    Text(mood)
                        .font(.system(size: 14))
                }

                Spacer()

                Text(item.publishedAt.relativeFormatted)
                    .font(Theme.feedTimestamp)
                    .foregroundStyle(Theme.textTertiary)
            }

            // Kickoff countdown for matchday items
            if let countdown = item.kickoffCountdown {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(countdown)
                        .font(Theme.feedBadge)
                }
                .foregroundStyle(Theme.accentGreen)
            }

            // Row 2: Headline (max 3 lines)
            Text(item.headline)
                .font(Theme.feedHeadline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(3)

            // Row 3: "Read more" right-aligned
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Text("Read more")
                        .font(Theme.feedTimestamp)
                        .foregroundStyle(Theme.accentWarm)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.accentWarm)
                }
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private var badgeView: some View {
        switch item.type {
        case .news:
            BadgeView(
                text: "NEWS",
                backgroundColor: Theme.accentSoft,
                textColor: Theme.accentWarm
            )
        case .matchday:
            BadgeView(
                text: "MATCH DAY",
                backgroundColor: Theme.accentGreen.opacity(0.2),
                textColor: Theme.accentGreen
            )
        }
    }
}

// MARK: - Relative Date Formatting

extension Date {
    var relativeFormatted: String {
        let now = Date()
        let interval = now.timeIntervalSince(self)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m ago"
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
