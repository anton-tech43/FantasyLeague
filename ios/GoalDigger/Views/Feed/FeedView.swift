import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(AppState.self) var appState
    @Environment(\.modelContext) var modelContext

    // Dual data sources
    @State private var teamItems: [ContentItem] = []
    @State private var everyoneItems: [ContentItem] = []

    // Per-context loading state
    @State private var isLoading = true
    @State private var hasError = false
    @State private var teamOffset = 0
    @State private var everyoneOffset = 0
    @State private var teamCanLoadMore = true
    @State private var everyoneCanLoadMore = true
    @State private var isLoadingMore = false
    @State private var freshnessCardDismissed = false
    @State private var matchdayPlayers: [PlayerCard] = []
    @AppStorage("hasAutoExpandedFirstItem") private var hasAutoExpanded = false
    @AppStorage("hasSeenImmersiveBanner") private var hasSeenImmersiveBanner = false

    private let pageSize = 20
    private let screenHeight = UIScreen.main.bounds.height

    private var isOffSeason: Bool {
        let month = Calendar.current.component(.month, from: Date())
        return month >= 6 && month <= 8
    }

    /// Items for the active context
    private var displayItems: [ContentItem] {
        switch appState.activeContext {
        case .team: return teamItems
        case .everyoneTalking: return everyoneItems
        }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if isLoading && displayItems.isEmpty {
                loadingView
            } else if displayItems.isEmpty && hasError {
                errorView
            } else if displayItems.isEmpty && appState.activeContext == .everyoneTalking {
                EveryoneEmptyStateCard(
                    cardHeight: screenHeight * Layout.immersiveCardHeightRatio,
                    teamName: appState.selectedTeam?.shortName ?? "your team",
                    onBackToTeam: {
                        if let team = appState.selectedTeam {
                            switchContext(to: .team(team))
                        }
                    }
                )
            } else if displayItems.isEmpty {
                emptyView
            } else {
                feedContent
            }

            // Context switcher overlay
            if appState.isContextSwitcherOpen {
                ContextSwitcherView(
                    appState: appState,
                    teamItems: teamItems,
                    everyoneItems: everyoneItems,
                    onSelect: { context in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.isContextSwitcherOpen = false
                        }
                        switchContext(to: context)
                    },
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.isContextSwitcherOpen = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
                .zIndex(100)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                contextPill
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .tabBar)
        .task { await loadInitial() }
    }

    // MARK: - Context Pill

    private var contextPill: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                appState.isContextSwitcherOpen.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                pillIcon
                Text(appState.activeContext.displayName)
                    .font(.detailTitle)
                    .foregroundColor(.textOnDark)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.textOnDark.opacity(0.6))
                    .rotationEffect(.degrees(appState.isContextSwitcherOpen ? 180 : 0))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.badgeCornerRadius)
                    .stroke(Color.hotRose, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                aggregateUnreadBadge
            }
        }
    }

    @ViewBuilder
    private var pillIcon: some View {
        switch appState.activeContext {
        case .team(let team):
            Image(team.badgeImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        case .everyoneTalking:
            Image(systemName: "soccerball")
                .font(.system(size: 14))
                .foregroundColor(.hotRose)
        }
    }

    @ViewBuilder
    private var aggregateUnreadBadge: some View {
        let badgeText = UnreadTracker.shared.aggregateBadgeText(
            activeContext: appState.activeContext,
            teamItems: teamItems,
            everyoneItems: everyoneItems,
            selectedTeam: appState.selectedTeam
        )
        if let text = badgeText {
            Text(text)
                .font(.jakarta(11, weight: .bold))
                .foregroundColor(.warmWhite)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.hotRose)
                .clipShape(Capsule())
                .offset(x: 8, y: -8)
        }
    }

    // MARK: - Feed Content (switches between immersive and classic)

    @ViewBuilder
    private var feedContent: some View {
        VStack(spacing: 0) {
            // Migration banner for existing users
            if !hasSeenImmersiveBanner && appState.feedStyle == .immersive {
                migrationBanner
            }

            if appState.feedStyle == .immersive {
                immersiveFeed
            } else {
                ClassicFeedView(
                    items: displayItems,
                    feedContext: appState.activeContext,
                    appState: appState,
                    matchdayPlayers: matchdayPlayers,
                    freshnessCardDismissed: $freshnessCardDismissed,
                    isOffSeason: isOffSeason,
                    onLoadMore: { await loadMore() }
                )
                .refreshable { await refresh() }
            }
        }
    }

    // MARK: - Immersive Feed

    private var immersiveFeed: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                    let isYourMove = index == 0 && appState.activeContext != .everyoneTalking
                    let isEveryoneCtx = appState.activeContext == .everyoneTalking

                    ImmersiveCard(
                        item: item,
                        feedContext: appState.activeContext,
                        appState: appState,
                        cardHeight: screenHeight * Layout.immersiveCardHeightRatio,
                        feedPosition: index,
                        isYourMove: isYourMove,
                        onZone1Tap: {
                            appState.deepLinkContentId = nil
                            // Navigate via ContentDetailDestination
                            navigateToDetail(item: item, scrollToTalkingPoints: false, isEveryoneContext: isEveryoneCtx)
                        },
                        onZone2Tap: {
                            appState.deepLinkContentId = nil
                            navigateToDetail(item: item, scrollToTalkingPoints: true, isEveryoneContext: isEveryoneCtx)
                        }
                    )
                    .onAppear {
                        if item.id == displayItems.suffix(3).first?.id {
                            Task { await loadMore() }
                        }
                    }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Color.deepMauve)
        .scrollContentBackground(.hidden)
        .refreshable { await refresh() }
    }

    // MARK: - Migration Banner

    private var migrationBanner: some View {
        HStack {
            Text("New: immersive feed is now your default. Switch back in Settings anytime.")
                .font(.jakarta(12, weight: .regular))
                .foregroundColor(.charcoal)
            Spacer()
            Button {
                withAnimation { hasSeenImmersiveBanner = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.hotRose)
            }
        }
        .padding(12)
        .background(Color.softBlush)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - States

    @ViewBuilder
    private var loadingView: some View {
        if appState.feedStyle == .immersive {
            VStack(spacing: 0) {
                ImmersiveSkeletonCard(cardHeight: screenHeight * Layout.immersiveCardHeightRatio)
                ImmersiveSkeletonCard(cardHeight: screenHeight * Layout.immersiveCardHeightRatio)
            }
        } else {
            VStack(spacing: Layout.cardSpacing) {
                YourMoveSkeletonCard()
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonCard()
                }
            }
            .padding(.horizontal, Layout.screenPadding)
        }
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Text("Something went wrong")
                .font(.feedHeadline)
                .foregroundColor(.textPrimaryOnCard)
            Text("We'll try again in a sec.")
                .font(.onboardingBody)
                .foregroundColor(.textSecondaryOnCard)
            Button {
                Task { await refresh() }
            } label: {
                Text("Try again")
                    .font(.feedHeadline)
                    .foregroundColor(.warmWhite)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.hotRose)
                    .cornerRadius(Layout.buttonCornerRadius)
            }
        }
        .padding(Layout.cardPadding)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
        .padding(.horizontal, Layout.screenPadding)
    }

    private var emptyView: some View {
        EmptyStateView(teamName: appState.selectedTeam?.shortName ?? "your team")
    }

    // MARK: - Navigation Helper

    private func navigateToDetail(item: ContentItem, scrollToTalkingPoints: Bool, isEveryoneContext: Bool) {
        // Deep link approach: set deepLinkContentId which GoalDiggerApp picks up
        // For now, set it and let the onChange handler in MainTabView navigate
        let dest = ContentDetailDestination(
            contentId: item.id,
            scrollToTalkingPoints: scrollToTalkingPoints,
            isEveryoneContext: isEveryoneContext
        )
        // Post notification with destination for MainTabView to handle
        NotificationCenter.default.post(
            name: .feedNavigateToDetail,
            object: dest
        )
    }

    // MARK: - Context Switching

    private func switchContext(to context: FeedContext) {
        // Save scroll position for current context
        // (handled automatically via @State — session only)

        UnreadTracker.shared.markViewed(appState.activeContext)
        appState.activeContext = context
        UnreadTracker.shared.markViewed(context)
        freshnessCardDismissed = false

        // Load data for new context if empty
        Task {
            switch context {
            case .team:
                if teamItems.isEmpty { await loadTeamFeed() }
            case .everyoneTalking:
                if everyoneItems.isEmpty { await loadEveryoneFeed() }
            }
        }
    }

    // MARK: - Data Loading

    private func loadInitial() async {
        // Set initial context from selected team
        if let team = appState.selectedTeam {
            appState.activeContext = .team(team)
        }

        // Show cached data immediately
        let cached = CacheService.shared.fetchCachedFeed(
            teamId: appState.selectedTeam?.rawValue ?? "",
            in: modelContext
        )
        if !cached.isEmpty {
            teamItems = cached
            isLoading = false
        }

        // Then fetch fresh data for both contexts
        await loadTeamFeed()

        // Also pre-fetch everyone feed in background
        Task { await loadEveryoneFeed() }

        // Purge old cache
        CacheService.shared.purgeOldItems(in: modelContext)

        // Auto-expand first item on initial launch after onboarding
        if !hasAutoExpanded, let firstItem = teamItems.first {
            hasAutoExpanded = true
            appState.deepLinkContentId = firstItem.id
        }
    }

    private func refresh() async {
        switch appState.activeContext {
        case .team: await loadTeamFeed()
        case .everyoneTalking: await loadEveryoneFeed()
        }
    }

    private func loadTeamFeed() async {
        guard let teamId = appState.selectedTeam?.rawValue else { return }
        do {
            let fetched = try await APIClient.shared.fetchFeed(teamId: teamId, limit: pageSize, offset: 0)
            teamItems = fetched
            teamOffset = fetched.count
            teamCanLoadMore = fetched.count == pageSize
            hasError = false
            CacheService.shared.upsertItems(fetched, in: modelContext)
        } catch {
            if teamItems.isEmpty {
                #if DEBUG
                let mockItems = MockData.feed.filter { $0.teamId == teamId }
                if !mockItems.isEmpty {
                    teamItems = mockItems
                } else {
                    hasError = true
                }
                #else
                hasError = true
                #endif
            }
        }
        isLoading = false
        freshnessCardDismissed = false

        // Fetch player cards for matchday card if needed
        if teamItems.contains(where: { $0.type == .matchday }),
           let teamId = appState.selectedTeam?.rawValue {
            matchdayPlayers = (try? await APIClient.shared.fetchPlayerCards(teamId: teamId)) ?? []
        }
    }

    private func loadEveryoneFeed() async {
        // Show cached everyone items immediately if we have no data yet
        if everyoneItems.isEmpty {
            let cached = CacheService.shared.fetchCachedEveryoneFeed(in: modelContext)
            if !cached.isEmpty {
                everyoneItems = cached
            }
        }

        do {
            let fetched = try await APIClient.shared.fetchEveryoneFeed(limit: pageSize, offset: 0)
            everyoneItems = fetched
            everyoneOffset = fetched.count
            everyoneCanLoadMore = fetched.count == pageSize
            // Cache everyone items alongside team items
            CacheService.shared.upsertItems(fetched, in: modelContext)
        } catch {
            #if DEBUG
            if everyoneItems.isEmpty {
                // Use mock items for everyone feed if available
                everyoneItems = MockData.feed.filter { $0.everyoneTalking }
            }
            #endif
        }
        if appState.activeContext == .everyoneTalking {
            isLoading = false
        }
    }

    private func loadMore() async {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        switch appState.activeContext {
        case .team:
            guard teamCanLoadMore, let teamId = appState.selectedTeam?.rawValue else { return }
            do {
                let fetched = try await APIClient.shared.fetchFeed(teamId: teamId, limit: pageSize, offset: teamOffset)
                teamItems.append(contentsOf: fetched)
                teamOffset += fetched.count
                teamCanLoadMore = fetched.count == pageSize
                CacheService.shared.upsertItems(fetched, in: modelContext)
            } catch {
                #if DEBUG
                print("⚠️ loadMore failed: \(error.localizedDescription)")
                #endif
            }

        case .everyoneTalking:
            guard everyoneCanLoadMore else { return }
            do {
                let fetched = try await APIClient.shared.fetchEveryoneFeed(limit: pageSize, offset: everyoneOffset)
                everyoneItems.append(contentsOf: fetched)
                everyoneOffset += fetched.count
                everyoneCanLoadMore = fetched.count == pageSize
                CacheService.shared.upsertItems(fetched, in: modelContext)
            } catch {
                #if DEBUG
                print("⚠️ loadMore failed: \(error.localizedDescription)")
                #endif
            }
        }
    }
}

// MARK: - Notification Name for Feed Navigation

extension Notification.Name {
    static let feedNavigateToDetail = Notification.Name("feedNavigateToDetail")
}

// MARK: - Freshness Card

struct FreshnessCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .padding(.bottom, 4)

            Text(title)
                .font(.feedHeadline)
                .foregroundColor(.textOnDark.opacity(0.7))

            Text(message)
                .font(.onboardingBody)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(Layout.cardPadding)
        .frame(maxWidth: .infinity)
        .background(Color.feedDivider)
        .cornerRadius(Layout.cardCornerRadius)
    }
}

// MARK: - Skeleton Loading

struct YourMoveSkeletonCard: View {
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: Layout.badgeCornerRadius)
                .fill(Color.warmWhite.opacity(0.15))
                .frame(width: 90, height: 22)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.warmWhite.opacity(0.15))
                .frame(height: 16)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.warmWhite.opacity(0.15))
                .frame(width: 200, height: 16)
        }
        .padding(Layout.cardPadding)
        .background(Color.hotRose)
        .cornerRadius(Layout.cardCornerRadius)
        .overlay(
            LinearGradient(
                colors: [.clear, Color.warmWhite.opacity(0.1), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: shimmerOffset)
        )
        .clipped()
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 400
            }
        }
    }
}

struct SkeletonCard: View {
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.hotRose.opacity(0.08))
                    .frame(width: 70, height: 20)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.hotRose.opacity(0.08))
                    .frame(width: 50, height: 14)
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.hotRose.opacity(0.08))
                .frame(height: 16)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.hotRose.opacity(0.08))
                .frame(width: 200, height: 16)
        }
        .padding(Layout.cardPadding)
        .background(Color.cardBackground)
        .cornerRadius(Layout.cardCornerRadius)
        .shadow(color: Color.cardShadowColor, radius: Layout.cardShadowRadius, y: Layout.cardShadowY)
        .overlay(
            LinearGradient(
                colors: [.clear, Color.hotRose.opacity(0.08), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: shimmerOffset)
        )
        .clipped()
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 400
            }
        }
    }
}
