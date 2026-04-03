import SwiftUI

// MARK: - ContentDetailView
// Full content detail — redesigned with playful editorial tone.
//
// Design decisions for other agents:
// - Section headers are playful ("Your cheat sheet", "The tea", "After the final whistle")
// - Talking points have tap-to-copy with haptic feedback (plain text only, no HTML)
// - Each talking point has a share button for quick sharing
// - Bookmark/save button lets users save favorite talking points
// - Post-match cards use border style instead of left bar for softer look
// - SavedPointsService dependency added for bookmark functionality

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
                sectionHeader("Your cheat sheet", emoji: "💬")

                VStack(spacing: Theme.elementSpacing) {
                    ForEach(item.regularTalkingPoints, id: \.self) { point in
                        TalkingPointCard(text: point)
                    }
                }

                // Post-Match Cheat Sheet (matchday only)
                if let cheatSheet = item.postMatchCheatSheet {
                    divider

                    sectionHeader("After the final whistle", emoji: "🎯")

                    VStack(spacing: Theme.elementSpacing) {
                        PostMatchCard(
                            label: "If they WIN:",
                            text: cheatSheet.ifTheyWin,
                            borderColor: Theme.accentGreen
                        )

                        PostMatchCard(
                            label: "If they LOSE:",
                            text: cheatSheet.ifTheyLose,
                            borderColor: Color(hex: "E07A5F")
                        )

                        PostMatchCard(
                            label: "Bold prediction:",
                            text: cheatSheet.boldPrediction,
                            borderColor: Theme.accentWarm
                        )
                    }
                }

                divider

                // Body Section
                sectionHeader("The tea", emoji: "☕")

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
                    .foregroundStyle(Theme.accentPink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Theme.accentPink, lineWidth: 2)
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
                text: "UPDATE",
                backgroundColor: Theme.accentPink.opacity(0.15),
                textColor: Theme.accentPink
            )
        case .matchday:
            BadgeView(
                text: "MATCH DAY",
                backgroundColor: Theme.accentGreen.opacity(0.15),
                textColor: Theme.accentGreen
            )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.feedDivider)
            .frame(height: 1)
    }

    private func sectionHeader(_ title: String, emoji: String) -> some View {
        Text("\(title) \(emoji)")
            .font(.system(.callout, design: .serif, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
    }
}

// MARK: - Talking Point Card
// Tap-to-copy with haptic feedback. Plain text only for security.
// Bookmark button saves to SavedPointsService.

private struct TalkingPointCard: View {
    let text: String
    @State private var copied = false
    @State private var isSaved = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(text)
                    .font(Theme.talkingPointText)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Action buttons
                HStack(spacing: 8) {
                    // Bookmark
                    Button {
                        isSaved.toggle()
                        SavedPointsService.shared.toggle(text)
                    } label: {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 14))
                            .foregroundStyle(isSaved ? Theme.accentPink : Theme.textTertiary)
                    }

                    // Share
                    ShareLink(item: text) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .padding(14)

            // "Copied" feedback
            if copied {
                Text("Copied!")
                    .font(Theme.feedTimestamp)
                    .foregroundStyle(Theme.accentGreen)
                    .transition(.opacity)
                    .padding(.bottom, 8)
            }
        }
        .background(Theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.accentPink.opacity(0.25), lineWidth: 1)
        )
        .onTapGesture {
            // Security: plain text only, no rich text or HTML
            UIPasteboard.general.string = text
            withAnimation { copied = true }
            // Haptic feedback
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            // Reset after 1.5s
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation { copied = false }
            }
        }
        .onAppear {
            isSaved = SavedPointsService.shared.isSaved(text)
        }
    }
}

// MARK: - Post-Match Card
// Uses border instead of left accent bar for softer editorial feel.

private struct PostMatchCard: View {
    let label: String
    let text: String
    let borderColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(Theme.feedBadge)
                .foregroundStyle(Theme.textTertiary)

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
                .stroke(borderColor.opacity(0.4), lineWidth: 1.5)
        )
    }
}
