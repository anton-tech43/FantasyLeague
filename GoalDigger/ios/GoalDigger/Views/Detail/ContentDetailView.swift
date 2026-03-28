import SwiftUI

struct ContentDetailView: View {
    let item: ContentItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                // Badge + Timestamp
                HStack {
                    badgeView
                    Spacer()
                    Text(item.publishedAt.relativeFormatted)
                        .font(Theme.feedTimestamp)
                        .foregroundStyle(Theme.textTertiary)
                }

                // Headline (full, no truncation)
                Text(item.headline)
                    .font(Theme.detailTitle)
                    .foregroundStyle(Theme.textPrimary)

                divider

                // Talking Points Section
                sectionHeader("Things to say")

                VStack(spacing: Theme.elementSpacing) {
                    ForEach(item.regularTalkingPoints, id: \.self) { point in
                        TalkingPointCard(text: point)
                    }
                }

                // Post-Match Cheat Sheet (matchday only, Contract 8)
                if let cheatSheet = item.postMatchCheatSheet {
                    divider

                    sectionHeader("After the match")

                    VStack(spacing: Theme.elementSpacing) {
                        // If they WIN
                        PostMatchCard(
                            label: "If they WIN:",
                            text: cheatSheet.ifTheyWin,
                            backgroundColor: Color.green.opacity(0.08),
                            barColor: Color.green.opacity(0.5)
                        )

                        // If they LOSE
                        PostMatchCard(
                            label: "If they LOSE:",
                            text: cheatSheet.ifTheyLose,
                            backgroundColor: Color.red.opacity(0.06),
                            barColor: Color.red.opacity(0.4)
                        )

                        // Bold prediction
                        PostMatchCard(
                            label: "Bold prediction:",
                            text: cheatSheet.boldPrediction,
                            backgroundColor: Theme.accentSoft.opacity(0.3),
                            barColor: Theme.accentWarm
                        )
                    }
                }

                divider

                // Body Section
                sectionHeader("The backstory")

                Text(item.body)
                    .font(Theme.detailBody)
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(6)

                divider

                // Share Button
                ShareLink(
                    item: "\(item.headline)\n\n— via Goal Digger"
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                        Text("Share this with a friend")
                            .font(Theme.feedHeadline)
                    }
                    .foregroundStyle(Theme.accentWarm)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.accentWarm, lineWidth: 2)
                    )
                }

                Spacer().frame(height: 20)
            }
            .padding(.horizontal, Theme.screenPadding)
        }
        .background(Theme.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

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

    private var divider: some View {
        Rectangle()
            .fill(Theme.feedDivider)
            .frame(height: 1)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(Theme.textTertiary)
            .kerning(1)
    }
}

// MARK: - Talking Point Card

private struct TalkingPointCard: View {
    let text: String

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Theme.accentWarm)
                .frame(width: 3)

            Text(text)
                .font(Theme.talkingPointText)
                .foregroundStyle(Theme.textPrimary)
                .padding(14)
        }
        .background(Theme.accentSoft.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Post-Match Card (Contract 8)

private struct PostMatchCard: View {
    let label: String
    let text: String
    let backgroundColor: Color
    let barColor: Color

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(barColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(Theme.feedBadge)
                    .foregroundStyle(Theme.textTertiary)

                Text(text)
                    .font(Theme.talkingPointText)
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
