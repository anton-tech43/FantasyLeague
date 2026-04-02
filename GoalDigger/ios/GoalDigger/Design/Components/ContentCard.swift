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

            // Headline — serif, editorial
            Text(item.headline)
                .font(Theme.feedHeadline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            // Conversation starter preview — first talking point as italic teaser
            if let firstPoint = item.regularTalkingPoints.first {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.accentWarm.opacity(0.5))
                        .frame(width: 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("CONVERSATION STARTER")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.accentWarm)

                        Text("\"\(firstPoint.prefix(80))...\"")
                            .font(Theme.conversationStarter)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                    }
                    .padding(.leading, 10)
                }
                .padding(.vertical, 4)
            }

            // "Full update" link
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Text("Full update")
                        .font(Theme.feedTimestamp)
                        .foregroundStyle(Theme.accentWarm)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.accentWarm)
                }
            }
        }
        .cardStyle(moodTint: moodTint)
    }

    /// Subtle background tint based on emotional context
    private var moodTint: Color? {
        switch item.emotionalContext {
        case "exciting": return Theme.moodExciting
        case "bad_news": return Theme.moodBadNews
        case "drama":    return Theme.moodDrama
        case "funny":    return Theme.moodFunny
        default:         return nil
        }
    }

    @ViewBuilder
    private var badgeView: some View {
        switch item.type {
        case .matchday:
            BadgeView(
                text: "MATCH DAY",
                backgroundColor: Theme.accentGreen.opacity(0.15),
                textColor: Theme.accentGreen
            )
        case .news:
            // Emotional framing: badge reflects how this affects him
            BadgeView(
                text: emotionalBadgeLabel,
                backgroundColor: Theme.accentSoft.opacity(0.5),
                textColor: Theme.accentWarm
            )
        }
    }

    private var emotionalBadgeLabel: String {
        switch item.emotionalContext {
        case "exciting": return "MOOD ALERT"
        case "bad_news": return "HEADS UP"
        case "drama":    return "MOOD ALERT"
        case "funny":    return "CONVERSATION STARTER"
        default:         return "UPDATE"
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
