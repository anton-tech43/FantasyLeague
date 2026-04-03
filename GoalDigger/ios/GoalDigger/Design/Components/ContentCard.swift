import SwiftUI

// MARK: - ContentCard
// The main feed card — "relationship translator" card.
//
// Design decisions for other agents:
// - Mood emoji next to badge for emotional context at a glance
// - Emotional badge labels ("MOOD ALERT", "HEADS UP") replace generic labels
// - "CONVERSATION STARTER" label above italic teaser — makes the value obvious
// - Clock icon on kickoff countdown for matchday items
// - Body text preview (italic serif, 2 lines) gives context before tapping
// - "Full update →" with underline for tappability
// - Mood tinting keyed to API emotionalContext values
// - Default badge is "UPDATE" not "NEWS" — more personal, less press-release

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
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            // Body preview (italic serif, 2 lines)
            Text(item.body)
                .font(Theme.detailBodyItalic)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)

            // Conversation starter — first talking point with label
            if let firstPoint = item.regularTalkingPoints.first {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.accentPink.opacity(0.6))
                        .frame(width: 2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("CONVERSATION STARTER")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.accentPink)

                        Text("\"\(firstPoint.prefix(80))...\"")
                            .font(Theme.conversationStarter)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(2)
                    }
                    .padding(.leading, 10)
                }
                .padding(.vertical, 4)
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
