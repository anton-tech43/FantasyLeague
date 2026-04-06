import SwiftUI

struct ContentDetailView: View {
    let contentId: UUID
    @Environment(AppState.self) var appState
    @State private var item: ContentItem?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if let item {
                ScrollView {
                    VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                        headerSection(item)
                        headlineSection(item)
                        talkingPointsSection(item)

                        if item.type == .matchday, let postMatch = item.postMatchCheatSheet {
                            postMatchSection(postMatch)
                        }

                        bodySection(item)
                        shareSection(item)
                    }
                    .padding(.horizontal, Layout.screenPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            } else if isLoading {
                ProgressView()
                    .tint(.hotRose)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task { await loadItem() }
    }

    // MARK: - Sections

    @ViewBuilder
    private func headerSection(_ item: ContentItem) -> some View {
        HStack {
            BadgeView(type: item.type)
            Spacer()
            Text(relativeTimestamp(item.publishedAt))
                .font(.feedTimestamp)
                .foregroundColor(.textTertiary)
        }
    }

    @ViewBuilder
    private func headlineSection(_ item: ContentItem) -> some View {
        Text(appState.personalise(item.headline))
            .font(.detailTitle)
            .foregroundColor(.textOnDark)

        Divider().background(Color.feedDivider)
    }

    @ViewBuilder
    private func talkingPointsSection(_ item: ContentItem) -> some View {
        VStack(alignment: .leading, spacing: Layout.elementSpacing) {
            SectionHeaderView(title: "Things to say", icon: "bubble.left")

            ForEach(Array(item.regularTalkingPoints.enumerated()), id: \.offset) { _, point in
                TalkingPointCard(text: appState.personalise(point))
            }
        }
    }

    @ViewBuilder
    private func postMatchSection(_ postMatch: PostMatchCheatSheet) -> some View {
        Divider().background(Color.feedDivider)

        VStack(alignment: .leading, spacing: Layout.elementSpacing) {
            SectionHeaderView(title: "After the match", icon: "flag.checkered")

            // If they WIN
            PostMatchCard(
                label: "If they WIN:",
                text: appState.personalise(postMatch.ifTheyWin),
                tintColor: Color.winTint,
                barColor: Color.winBar
            )

            // If they LOSE
            PostMatchCard(
                label: "If they LOSE:",
                text: appState.personalise(postMatch.ifTheyLose),
                tintColor: Color.loseTint,
                barColor: Color.loseBar
            )

            // Bold prediction
            PostMatchCard(
                label: "Bold prediction:",
                text: appState.personalise(postMatch.boldPrediction),
                tintColor: Color.accentSoft.opacity(0.3),
                barColor: Color.accentWarm
            )
        }
    }

    @ViewBuilder
    private func bodySection(_ item: ContentItem) -> some View {
        Divider().background(Color.feedDivider)

        VStack(alignment: .leading, spacing: Layout.elementSpacing) {
            SectionHeaderView(title: "The backstory", icon: "book")

            Text(appState.personalise(item.body))
                .font(.detailBody)
                .foregroundColor(.textOnDark.opacity(0.9))
                .lineSpacing(6)
        }
    }

    @ViewBuilder
    private func shareSection(_ item: ContentItem) -> some View {
        Divider().background(Color.feedDivider)

        ShareLink(
            item: "\(appState.personalise(item.headline))\n\n\u{2014} via Goal Digger"
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
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                    .stroke(Color.accentWarm, lineWidth: 2)
            )
        }
    }

    // MARK: - Loading

    private func loadItem() async {
        // Try mock data first
        if let mock = MockData.feed.first(where: { $0.id == contentId }) {
            item = mock
            isLoading = false
            return
        }
        do {
            item = try await APIClient.shared.fetchItem(id: contentId)
        } catch {
            // Stay on loading state or show error
        }
        isLoading = false
    }

    private func relativeTimestamp(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 {
            return "\(max(1, Int(interval / 60)))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else if interval < 172800 {
            return "Yesterday"
        } else {
            return "\(Int(interval / 86400)) days ago"
        }
    }
}

// MARK: - Sub-components

struct SectionHeaderView: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(title.uppercased())
                .font(.sectionHeader)
                .tracking(1)
        }
        .foregroundColor(.textTertiary)
    }
}

struct TalkingPointCard: View {
    let text: String

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentWarm)
                .frame(width: 3)

            Text(text)
                .font(.talkingPointText)
                .foregroundColor(.textPrimaryOnCard)
                .padding(14)
        }
        .background(Color.accentSoft.opacity(0.3))
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

struct PostMatchCard: View {
    let label: String
    let text: String
    let tintColor: Color
    let barColor: Color

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(barColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.feedBadge)
                    .textCase(.uppercase)
                    .foregroundColor(.textSecondaryOnCard)

                Text(text)
                    .font(.talkingPointText)
                    .foregroundColor(.textPrimaryOnCard)
            }
            .padding(14)
        }
        .background(tintColor)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}
