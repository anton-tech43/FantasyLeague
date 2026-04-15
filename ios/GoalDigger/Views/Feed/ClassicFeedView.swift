import SwiftUI

/// The classic card-list feed layout (original design).
/// Preserved as a setting option alongside the new immersive feed.
struct ClassicFeedView: View {
    let items: [ContentItem]
    let feedContext: FeedContext
    let appState: AppState
    let matchdayPlayers: [PlayerCard]
    let freshnessCardDismissed: Binding<Bool>
    let isOffSeason: Bool
    let onLoadMore: () async -> Void

    // MARK: - Derived Feed Data

    private var yourMoveItem: ContentItem? {
        guard case .team = feedContext else { return nil }
        return YourMoveCard.pickRelevantItem(from: items)
    }

    private var matchDayItem: ContentItem? {
        guard case .team = feedContext else { return nil }
        let calendar = Calendar.current
        return items.first { item in
            item.type == .matchday &&
            item.kickoffTime.map { calendar.isDateInToday($0) || $0 > Date() } == true
        }
    }

    private var worthKnowingItem: ContentItem? {
        guard feedContext == .everyoneTalking else { return nil }
        return items.first { $0.worthKnowing }
    }

    private var newsItems: [ContentItem] {
        let excludeIds = Set([yourMoveItem?.id, matchDayItem?.id, worthKnowingItem?.id].compactMap { $0 })
        return items.filter { !excludeIds.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Layout.cardSpacing) {
                // Freshness card
                if !freshnessCardDismissed.wrappedValue {
                    freshnessCard
                        .onTapGesture {
                            withAnimation { freshnessCardDismissed.wrappedValue = true }
                        }
                        .transition(.opacity)
                }

                // YOUR MOVE card (team context only)
                if let moveItem = yourMoveItem {
                    NavigationLink(value: ContentDetailDestination(contentId: moveItem.id, scrollToTalkingPoints: true, isEveryoneContext: false)) {
                        YourMoveCard(item: moveItem, appState: appState)
                    }
                    .buttonStyle(.plain)
                }

                // MATCH DAY card (team context only)
                if let matchItem = matchDayItem {
                    NavigationLink(value: ContentDetailDestination(contentId: matchItem.id, scrollToTalkingPoints: false, isEveryoneContext: false)) {
                        MatchDayCard(item: matchItem, appState: appState, players: matchdayPlayers)
                    }
                    .buttonStyle(.plain)
                }

                // WORTH KNOWING card (everyone context only) — gold hero
                if let worthItem = worthKnowingItem {
                    NavigationLink(value: ContentDetailDestination(contentId: worthItem.id, scrollToTalkingPoints: false, isEveryoneContext: true)) {
                        WorthKnowingCard(item: worthItem)
                    }
                    .buttonStyle(.plain)
                }

                // NEWS cards
                ForEach(newsItems) { item in
                    let isEveryoneCtx = feedContext == .everyoneTalking
                    NavigationLink(value: ContentDetailDestination(contentId: item.id, scrollToTalkingPoints: false, isEveryoneContext: isEveryoneCtx)) {
                        ContentCard(item: item, appState: appState, feedContext: feedContext)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if item.id == newsItems.suffix(3).first?.id {
                            Task { await onLoadMore() }
                        }
                    }
                }
            }
            .padding(.horizontal, Layout.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(Color.appBackground)
    }

    // MARK: - Freshness Card

    @ViewBuilder
    private var freshnessCard: some View {
        if let latest = items.first {
            let age = Date().timeIntervalSince(latest.publishedAt)
            let hours = age / 3600
            let teamName = appState.selectedTeam?.shortName ?? "your team"

            if hours < 12 {
                EmptyView()
            } else if hours < 72 {
                FreshnessCard(
                    icon: "checkmark.circle",
                    iconColor: .hotRose,
                    title: "You're all caught up",
                    message: "Nothing new for \(teamName) right now. We'll ping you when something happens."
                )
            } else if hours < 336 {
                FreshnessCard(
                    icon: "moon.zzz",
                    iconColor: .textTertiary,
                    title: "Quiet week for \(teamName)",
                    message: "Not much happening right now. We'll let you know when there's something worth talking about."
                )
            } else if isOffSeason {
                FreshnessCard(
                    icon: "sun.max",
                    iconColor: .tierGold,
                    title: "Season's over!",
                    message: "The Premier League is on summer break. Enjoy the peace and quiet. We'll be back in August.\n\n(Transfer rumours might still pop up though)"
                )
            } else {
                FreshnessCard(
                    icon: "pause.circle",
                    iconColor: .textTertiary,
                    title: "The Premier League is on a break",
                    message: "No matches or major news right now. We'll wake up when things kick off again."
                )
            }
        } else {
            EmptyView()
        }
    }
}

// MARK: - Worth Knowing Card (Gold hero for Everyone feed in classic mode)

struct WorthKnowingCard: View {
    let item: ContentItem

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.elementSpacing) {
            // Badge
            Text("WORTH KNOWING")
                .font(.feedBadge)
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundColor(.warmWhite)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.charcoal)
                .cornerRadius(Layout.badgeCornerRadius)

            // Headline
            Text(item.everyoneTalkingHeadline ?? item.headline)
                .font(.feedHeadline)
                .foregroundColor(.warmWhite)
                .lineLimit(3)

            // Teaser talking point
            if let firstPoint = item.everyoneTalkingTalkingPoints?.first {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 11))
                        .foregroundColor(.warmWhite.opacity(0.7))
                    Text(firstPoint)
                        .font(.feedTimestamp)
                        .foregroundColor(.warmWhite.opacity(0.7))
                        .lineLimit(1)
                }
            }

            // Read more
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Text("Read more")
                        .font(.feedTimestamp)
                        .foregroundColor(.warmWhite.opacity(0.8))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(.warmWhite.opacity(0.8))
                }
            }
        }
        .padding(Layout.cardPadding)
        .background(Color.gold)
        .cornerRadius(Layout.cardCornerRadius)
        .shadow(color: Color.cardShadowColor, radius: Layout.cardShadowRadius, y: Layout.cardShadowY)
    }
}
