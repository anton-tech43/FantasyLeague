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
                sectionHeader("Your cheat sheet 💬")

                VStack(spacing: Theme.elementSpacing) {
                    ForEach(item.regularTalkingPoints, id: \.self) { point in
                        TalkingPointCard(text: point, headline: item.headline)
                    }
                }

                // Post-Match Cheat Sheet (matchday only, Contract 8)
                if let cheatSheet = item.postMatchCheatSheet {
                    divider

                    sectionHeader("After the final whistle 🎯")

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
                sectionHeader("The tea ☕")

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
                        Text("Send to a friend")
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
        .background(Theme.backgroundGradient.ignoresSafeArea())
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
    var headline: String = ""
    @State private var copied = false

    /// Plain text only — no URLs, no sensitive data
    private var shareText: String {
        "\(text)\n\n— via Goal Digger"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(Theme.talkingPointText)
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.leading)

            // Action row: copy + share
            HStack(spacing: 16) {
                Spacer()

                Button {
                    UIPasteboard.general.string = text
                    copied = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copied = false }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                        Text(copied ? "Copied!" : "Copy")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(copied ? Theme.accentGreen : Theme.textTertiary)
                    .animation(.easeInOut(duration: 0.2), value: copied)
                }
                .buttonStyle(.plain)

                ShareLink(item: shareText) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11))
                        Text("Share")
                            .font(.system(.caption2, design: .rounded, weight: .medium))
                    }
                    .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.accentWarm.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Post-Match Card (Contract 8)

private struct PostMatchCard: View {
    let label: String
    let text: String
    let backgroundColor: Color
    let barColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(Theme.feedBadge)
                .foregroundStyle(barColor)

            Text(text)
                .font(Theme.talkingPointText)
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(barColor.opacity(0.4), lineWidth: 1)
        )
    }
}
