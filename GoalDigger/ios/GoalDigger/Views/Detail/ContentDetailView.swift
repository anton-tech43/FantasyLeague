import SwiftUI

/// Full content detail screen with talking points, post-match cheat sheet,
/// body text, and share button. See BUILD_PLAN Step 3.6 and Contract 8.
struct ContentDetailView: View {
    let item: ContentItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Badge + Timestamp
                HStack {
                    BadgeView(type: item.type)
                    Spacer()
                    Text(formattedDate(item.publishedAt))
                        .font(.feedTimestamp)
                        .foregroundColor(.textTertiary)
                }
                .padding(.bottom, Layout.elementSpacing)

                // Headline (full, no truncation)
                Text(item.headline)
                    .font(.detailTitle)
                    .foregroundColor(.textPrimary)
                    .padding(.bottom, Layout.sectionSpacing)

                divider

                // Talking Points
                sectionHeader("Things to say")

                VStack(spacing: Layout.elementSpacing) {
                    ForEach(item.regularTalkingPoints, id: \.self) { point in
                        TalkingPointCard(text: point)
                    }
                }
                .padding(.bottom, Layout.sectionSpacing)

                // Post-Match Cheat Sheet (matchday only — Contract 8)
                if item.type == .matchday, let cheatSheet = item.postMatchCheatSheet {
                    divider
                    postMatchSection(cheatSheet)
                }

                divider

                // Body
                sectionHeader("The backstory")

                Text(item.body)
                    .font(.detailBody)
                    .foregroundColor(.textPrimary)
                    .lineSpacing(6)
                    .padding(.bottom, Layout.sectionSpacing)

                divider

                // Share Button
                ShareLink(
                    item: "\(item.headline)\n\n\u{2014} via Goal Digger"
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share this with a friend")
                    }
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundColor(.accentWarm)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentWarm, lineWidth: 2)
                    )
                }
                .padding(.bottom, Layout.sectionSpacing)
            }
            .padding(.horizontal, Layout.screenPadding)
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Post-Match Cheat Sheet (Contract 8)

    @ViewBuilder
    private func postMatchSection(_ cheatSheet: PostMatchCheatSheet) -> some View {
        sectionHeader("After the match")

        VStack(spacing: Layout.elementSpacing) {
            PostMatchCard(
                label: "If they WIN:",
                text: cheatSheet.ifTheyWin,
                backgroundTint: Color.green.opacity(0.08),
                barColor: Color.green.opacity(0.5)
            )
            PostMatchCard(
                label: "If they LOSE:",
                text: cheatSheet.ifTheyLose,
                backgroundTint: Color.red.opacity(0.06),
                barColor: Color.red.opacity(0.4)
            )
            PostMatchCard(
                label: "Bold prediction:",
                text: cheatSheet.boldPrediction,
                backgroundTint: Color.accentSoft.opacity(0.3),
                barColor: Color.accentWarm
            )
        }
        .padding(.bottom, Layout.sectionSpacing)
    }

    // MARK: - Helpers

    private var divider: some View {
        Rectangle()
            .fill(Color.feedDivider)
            .frame(height: 1)
            .padding(.vertical, Layout.sectionSpacing / 2)
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.feedBadge)
            .foregroundColor(.textTertiary)
            .tracking(1)
            .padding(.bottom, Layout.elementSpacing)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Talking Point Card

struct TalkingPointCard: View {
    let text: String

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentWarm)
                .frame(width: 3)
            Text(text)
                .font(.talkingPointText)
                .foregroundColor(.textPrimary)
                .padding(14)
        }
        .background(Color.accentSoft.opacity(0.3))
        .cornerRadius(12)
    }
}

// MARK: - Post-Match Card (Contract 8)

struct PostMatchCard: View {
    let label: String
    let text: String
    let backgroundTint: Color
    let barColor: Color

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(barColor)
                .frame(width: 3)
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.feedBadge)
                    .foregroundColor(.textSecondary)
                Text(text)
                    .font(.talkingPointText)
                    .foregroundColor(.textPrimary)
            }
            .padding(14)
        }
        .background(backgroundTint)
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        ContentDetailView(item: MockData.matchdayItem)
    }
}
