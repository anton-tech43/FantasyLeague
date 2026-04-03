import SwiftUI

// MARK: - ContentCard
// The main feed card — designed to deliver value WITHOUT tapping.
//
// Design decisions for other agents:
// - No body preview — save that for the detail view
// - Full conversation opener in quotes — the thing she'd actually SAY
// - This is not a news briefing card, it's a conversation starter card
// - Card gives enough to start talking, detail gives the full story
// - Mood tinting keyed to API emotionalContext values

struct ContentCard: View {
    let item: ContentItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row 1: Badge + Mood Emoji + Timestamp
            HStack {
                badgeView

                if let emoji = item.moodEmoji {
                    Text(emoji)
                        .font(.system(size: 14))
                }

                Spacer()

                Text(item.publishedAt.relativeFormatted)
                    .font(Theme.feedTimestamp)
                    .foregroundStyle(Theme.textTertiary)
            }

            // Kickoff countdown with clock icon (matchday only)
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
                .multilineTextAlignment(.leading)

            // Conversation opener — full talking point in quotes, no line limit
            if let firstPoint = item.regularTalkingPoints.first {
                HStack(alignment: .top, spacing: 10) {
                    Text("💬")
                        .font(.system(size: 16))

                    Text("\"\(firstPoint)\"")
                        .font(Theme.conversationStarter)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Theme.accentPink.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // "Full update" link — underlined for tappability
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Text("Full update")
                        .font(Theme.feedTimestamp)
                        .underline()
                        .foregroundStyle(Theme.accentWarm)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.accentWarm)
                }
            }
        }
        .cardStyle(moodTint: moodTint)
    }

    // MARK: - Mood Tint (keyed to API emotionalContext values)

    private var moodTint: Color? {
        switch item.emotionalContext {
        case "exciting": return Theme.moodExciting
        case "bad_news": return Theme.moodBadNews
        case "drama":    return Theme.moodDrama
        case "funny":    return Theme.moodFunny
        default:         return nil
        }
    }

    // MARK: - Emotional Badge Labels

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
            BadgeView(
                text: emotionalBadgeLabel,
                backgroundColor: Theme.accentPink.opacity(0.15),
                textColor: Theme.accentPink
            )
        }
    }

    /// Map emotional context to badge labels that feel personal
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
