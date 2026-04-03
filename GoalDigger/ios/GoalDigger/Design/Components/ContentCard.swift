import SwiftUI

// MARK: - ContentCard
// The main feed card — redesigned as a "relationship translator" card.
//
// Design decisions for other agents:
// - Mood emoji appears next to the badge for emotional context at a glance
// - Emotional badge labels ("MOOD ALERT", "HEADS UP") replace generic "NEWS"
// - Body text preview (italic serif, 2 lines) gives context before tapping
// - First talking point shown as "conversation starter" teaser
// - "Full update →" replaces "Read more →" to match editorial tone
// - Mood tinting: cards have a faint background color based on emotionalContext
// - Kickoff countdown shown for matchday items

struct ContentCard: View {
    let item: ContentItem

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.elementSpacing) {
            // Row 1: Badge + Mood Emoji + Timestamp
            HStack {
                badgeView

                if let emoji = item.moodEmoji {
                    Text(emoji)
                        .font(.system(size: 14))
                }

                Spacer()

                if let countdown = item.kickoffCountdown {
                    Text(countdown)
                        .font(Theme.feedTimestamp)
                        .foregroundStyle(Theme.accentGreen)
                } else {
                    Text(item.publishedAt.relativeFormatted)
                        .font(Theme.feedTimestamp)
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            // Row 2: Headline (max 3 lines)
            Text(item.headline)
                .font(Theme.feedHeadline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(3)

            // Row 3: Body preview (italic serif, 2 lines)
            Text(item.body)
                .font(Theme.detailBodyItalic)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)

            // Row 4: Conversation starter teaser (first talking point)
            if let firstPoint = item.regularTalkingPoints.first {
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Theme.accentWarm)
                        .frame(width: 2, height: 16)

                    Text(firstPoint)
                        .font(Theme.conversationStarter)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                .padding(.top, 2)
            }

            // Row 5: "Full update" right-aligned
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
        .cardStyle(moodTint: moodTintColor)
    }

    // MARK: - Mood Tint

    private var moodTintColor: Color? {
        guard let mood = item.emotionalContext?.lowercased() else { return nil }
        switch mood {
        case "excited", "celebratory": return Theme.moodExcited
        case "nervous": return Theme.moodNervous
        case "confident", "hopeful": return Theme.moodConfident
        default: return nil
        }
    }

    // MARK: - Emotional Badge Labels
    // Instead of generic "NEWS" / "MATCH DAY", use emotional labels.

    @ViewBuilder
    private var badgeView: some View {
        switch item.type {
        case .news:
            BadgeView(
                text: emotionalBadgeLabel,
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

    /// Map emotional context to badge labels that feel personal
    private var emotionalBadgeLabel: String {
        guard let mood = item.emotionalContext?.lowercased() else { return "NEWS" }
        switch mood {
        case "excited", "celebratory": return "MOOD ALERT"
        case "nervous", "frustrated": return "HEADS UP"
        case "confident", "hopeful": return "GOOD VIBES"
        case "devastated": return "BRACE YOURSELF"
        default: return "NEWS"
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
