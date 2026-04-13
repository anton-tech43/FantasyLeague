import SwiftUI

struct ContentDetailView: View {
    let contentId: UUID
    var scrollToTalkingPoints: Bool = false
    var isEveryoneContext: Bool = false
    @Environment(AppState.self) var appState
    @State private var item: ContentItem?
    @State private var isLoading = true
    @State private var onesToWatch: [PlayerCard] = []
    @State private var isBackstoryExpanded = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if let item {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                            headerSection(item)
                            headlineSection(item)
                            talkingPointsSection(item)

                            if item.type == .matchday, let postMatch = item.postMatchCheatSheet {
                                postMatchSection(postMatch)
                            }

                            if item.type == .matchday, !onesToWatch.isEmpty {
                                Divider().background(Color.feedDivider)
                                OnesToWatchView(players: onesToWatch)
                            }

                            backstorySection(item)
                        }
                        .padding(.horizontal, Layout.screenPadding)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                    .task {
                        if scrollToTalkingPoints {
                            try? await Task.sleep(for: .milliseconds(300))
                            withAnimation {
                                proxy.scrollTo("thingsToSay", anchor: .top)
                            }
                        }
                    }
                }
            } else if isLoading {
                ProgressView()
                    .tint(.hotRose)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if item != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: "\(displayHeadline)\n\nvia GoalDigger"
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.hotRose)
                    }
                }
            }
        }
        .task { await loadItem() }
    }

    // MARK: - Sections

    @ViewBuilder
    private func headerSection(_ item: ContentItem) -> some View {
        HStack {
            BadgeView(type: item.type)
            Spacer()
            Text(item.publishedAt.relativeTimestamp)
                .font(.feedTimestamp)
                .foregroundColor(.textTertiary)
        }
    }

    // Context-aware content helpers
    private var displayHeadline: String {
        guard let item else { return "" }
        if isEveryoneContext {
            return item.everyoneTalkingHeadline ?? item.headline
        }
        return appState.personalise(item.headline)
    }

    private var displayBody: String {
        guard let item else { return "" }
        if isEveryoneContext {
            return item.everyoneTalkingBody ?? item.body
        }
        return appState.personalise(item.body)
    }

    private var displayTalkingPoints: [String] {
        guard let item else { return [] }
        if isEveryoneContext {
            return item.everyoneTalkingTalkingPoints ?? item.regularTalkingPoints
        }
        return item.regularTalkingPoints.map { appState.personalise($0) }
    }

    @ViewBuilder
    private func headlineSection(_ item: ContentItem) -> some View {
        Text(displayHeadline)
            .font(.jakarta(22, weight: .bold))
            .foregroundColor(.textOnDark)
            .padding(.top, 4)

        Divider().background(Color.feedDivider)
    }

    @ViewBuilder
    private func talkingPointsSection(_ item: ContentItem) -> some View {
        VStack(alignment: .leading, spacing: Layout.elementSpacing) {
            SectionHeaderView(title: "Things to say", icon: "bubble.left")
                .id("thingsToSay")

            ForEach(Array(displayTalkingPoints.enumerated()), id: \.offset) { _, point in
                TalkingPointCard(text: point)
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

            // Bold prediction removed — not part of the feed experience
        }
    }

    @ViewBuilder
    private func backstorySection(_ item: ContentItem) -> some View {
        Divider().background(Color.feedDivider)

        VStack(alignment: .leading, spacing: Layout.elementSpacing) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isBackstoryExpanded.toggle()
                }
            } label: {
                HStack {
                    SectionHeaderView(title: "The backstory", icon: "book")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.hotRose)
                        .rotationEffect(.degrees(isBackstoryExpanded ? 90 : 0))
                }
            }

            if isBackstoryExpanded {
                Text(displayBody)
                    .font(.detailBody)
                    .foregroundColor(.textOnDark.opacity(0.9))
                    .lineSpacing(6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Loading

    private func loadItem() async {
        do {
            item = try await APIClient.shared.fetchItem(id: contentId)
        } catch {
            #if DEBUG
            // Fall back to mock data during development
            if let mock = MockData.feed.first(where: { $0.id == contentId }) {
                item = mock
            }
            #endif
        }
        isLoading = false

        // Fetch "ones to watch" player cards for matchday items
        if let item, item.type == .matchday {
            onesToWatch = (try? await APIClient.shared.fetchPlayerCards(teamId: item.teamId)) ?? []
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
                .fill(Color.hotRose)
                .frame(width: 3)

            Text(text)
                .font(.talkingPointText)
                .foregroundColor(.textPrimaryOnCard)
                .padding(14)
        }
        .background(Color.hotRose.opacity(0.06))
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
